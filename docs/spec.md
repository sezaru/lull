# Pulsetto controller app (Flutter): spec

Status: draft, 2026-10-03. Working name: Lull.

## 1. Goal

An ad-free app to run stimulation sessions on a Pulsetto (Lite or Fit) over BLE,
replacing the official app for daily use. No account, no internet, no ads.

Primary target is Android on the user's GrapheneOS phone. The same codebase should
also build for Linux desktop, which comes almost for free with the BLE plugin chosen
in section 5. iOS is out of scope for v1.

### Non-goals

- Guided meditation, breathing exercises, affirmations, "CNS tap test", wearable
  sync: these are app-side content and have nothing to do with the device.
- Firmware updates or DFU of any kind.
- Any device command that isn't in the allowlist in section 3.3.

## 2. What the reference implementations tell us

Sources, both MIT (Juraj Bednar):
- `jooray/pulse-libre-desktop`: Python/Kivy app, plus `docs/PULSETTO_PROTOCOL.md`.
- `jooray/PulseLibre` (main @ `53cecd1`): React Native app. All logic is in one
  1627-line `App.js`.

### 2.1 How PulseLibre works

- **Scan:** looks for the first advertised device whose name starts with `Pulsetto`,
  then stops scanning and connects. It doesn't remember a device and has no picker.
- **Connect:** discovers services, subscribes to TX notifications, sends `v` and `i`
  once, sends `u` and `Q` once, then polls `u`/`Q` every 30 s while idle.
- **Start:** sends the full start sequence (section 3.4), then polls every 3 s.
- **Keepalive:** while a session runs, re-sends the current intensity every 10 s.
  The desktop app does the same. Nobody has documented whether the device actually
  needs this.
- **Timer:** decrements a counter once a second in JS. At zero it sends the stop
  sequence (section 3.5) and logs the session. The screen is kept on (KeepAwake)
  for the whole session. There is no foreground service, so the session only
  survives while the app is in the foreground.
- **Disconnect:** clears state, rescans after 1 s, and tries to resume the session
  with the full start sequence.
- **Persistence (v2.2.0):** saves strength, timer and daily goal. Keeps a session
  log (start, planned and actual seconds, strength, completed) with a Mon–Sun
  tracker; a day counts as complete at ≥ N sessions of ≥ 60 s each.
- **Fixed settings:** LED is always `E` (low) and side is always `D` (both).
- **Android permissions:** `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`,
  `ACCESS_FINE_LOCATION`. No `INTERNET`.

### 2.2 PR #4 (open, unmerged, kkonyshev, 2026-08-07)

- Adds a program picker with the 9 official programs, including the 3 paid ones
  (Head Pain, Inflammation, Gut Health). A program only sets the timer duration.
  The code comment repeats that "the device behaves identically regardless of
  program".
- Changing the timer by hand clears the selected program.
- Programs are tracked by name, so programs with the same duration (e.g. Anxiety
  and Burnout, both 6 min) don't both highlight.
- The program name is logged per session. The selected program is not persisted.
- Fixes the iOS permission constant for react-native-permissions v5
  (`BLUETOOTH_PERIPHERAL` → `BLUETOOTH`), adds `setup_permissions` to the Podfile,
  and documents the iOS toolchain.
- No protocol changes. LED stays `E` for every program, including Sleep.

### 2.3 PulseLibre bugs not to copy

React state captured in closures that later go stale makes several paths
unreliable (line numbers are `App.js` @ `53cecd1`):

- **Scan timeout never fires.** The timeout reads the `scanning` value captured
  before `setScanning(true)` (L454–455).
- **Idle polling is a no-op until the first session.** Polling started from
  `connectToDevice` captures `connectedDevice === null` (L348–349, L501). Passing
  `null` explicitly bypasses the default parameter in `sendCommand`, so nothing
  is sent.
- **Resume after reconnect probably never runs.** It reads `isRunning` and
  `remainingTime` from the closure of the scan that started the reconnect
  (L504). Meanwhile the keepalive effect does re-run, so the device likely gets
  bare intensity commands without a start sequence.
- **Slider floods the device.** The slider sends a command on every step while
  being dragged (L982 → L776).

Design response: one controller object owns connection and session state (section
5). The UI only renders state and calls methods on it.

## 3. Device protocol (the contract)

From `PULSETTO_PROTOCOL.md`; both reference apps agree with it.

### 3.1 Transport

- **Service:** Nordic UART, `6e400001-b5a3-f393-e0a9-e50e24dcca9e`.
- **RX (app → device, write):** `6e400002-b5a3-f393-e0a9-e50e24dcca9e`.
- **TX (device → app, notify):** `6e400003-b5a3-f393-e0a9-e50e24dcca9e`.
- **Advertised name:** starts with `Pulsetto` (`PulsUp` means it's in DFU mode;
  never connect to that).
- **Command format:** ASCII, one character plus `\n`.
- **Write modes:** `+` and `-` use write-with-response; everything else uses
  write-without-response.

### 3.2 Notifications (device → app)

| Payload | Meaning | Handling |
|---|---|---|
| `Batt:3.97` | battery voltage | `pct = clamp(round((v-3.5)/0.4*100), 0, 100)` |
| `u\x011` / `u\x010` | charging / not charging | Also accept the text forms `Charging` / `Not Charging`, which the desktop app handles for some firmware. |
| `fw:1.1.22` | firmware version | show in the device info screen |
| `Pulsetto_ST_02` | identity | show in the device info screen |
| `mode:0`, `BR:100` | unknown | log only |

Seen on firmware 1.1.22 (2026-10-21): replies are separated by spaces, not
newlines (`u\x010 mode:0 BR:100 Batt:3.80` answers `u` + `Q`), and a token can be cut
across two notifications (`BR:` + `100`). Split the stream on whitespace, keep a
trailing fragment until the next packet or a 200 ms pause, and log unknown tokens.
The device drops a command written right behind another one, so writes go out at
least 150 ms apart, and it now and then skips a reply altogether.

### 3.3 Command allowlist

The transport layer only accepts a closed enum. It must be impossible to send
anything else, so there is no raw-string API anywhere in the app.

| Enum | Bytes | Write mode |
|---|---|---|
| `rampUp` | `+\n` | with response |
| `rampDown` | `-\n` | with response |
| `level(0..9)` | `0\n` … `9\n` | without response |
| `side(both/left/right)` | `D\n` / `A\n` / `C\n` | without response |
| `led(low/med/high)` | `E\n` / `F\n` / `G\n` | without response |
| `queryBattery` | `Q\n` | without response |
| `queryCharging` | `u\n` | without response |
| `queryFirmware` | `v\n` | without response |
| `queryIdentity` | `i\n` | without response |

**Explicitly excluded:** `U` (reboot to DFU) and anything undocumented. CISA
ICSMA-26-223-02 / CVE-2026-18844 reports hidden commands that can disable the
device's safety mechanisms.

### 3.4 Start sequence (identical for every program)

```
rampUp, rampDown, wait 250ms,
level(0), wait 450ms, level(5), wait 450ms, level(0), wait 450ms,
level(target), wait 250ms,
side(s), led(l)
```

### 3.5 Stop sequence

```
rampUp, rampDown, rampDown
```

### 3.6 During a session

- **Change intensity:** send `level(n)` directly.
- **Pause:** send `level(0)`.
- **Poll:** `queryCharging` and `queryBattery` every 3 s.
- **Keepalive:** re-send `level(current)` every 10 s, matching both reference apps.
  Whether it's needed is open question Q2.
- **Idle:** poll every 30 s.

## 4. Programs

These only choose a default duration and LED level. The device gets the same start
sequence for all of them (verified at the BLE level by the reference project; see
Q6 for verifying it yourself).

| Program | Minutes | LED |
|---|---|---|
| Stress | 4 | med (`F`) |
| Anxiety | 6 | med |
| Sleep | 10 | low (`E`) |
| Burnout | 6 | med |
| Pain | 20 | med |
| Head Pain | 6 | med |
| Inflammation | 4 | med |
| Gut Health | 5 | med |
| Personal | 8 | med |

The LED column mirrors the official app: Sleep starts with `E`, the others with `F`.
A setting can override it (section 6.3).

## 5. Architecture

Plain Flutter with no state-management framework: `ChangeNotifier` controllers and
`ListenableBuilder`.

```
lib/
  protocol/   pulsetto_protocol.dart   # Command enum → bytes + write mode; parseNotification → events. Pure Dart.
  ble/        pulsetto_link.dart       # Scan/connect/notify/write over universal_ble; serialized write queue
  session/    session_controller.dart  # The state machine (5.2); owns timers, keepalive, polling
  storage/    prefs.dart, history.dart # shared_preferences (settings + JSON session log)
  platform/   foreground.dart          # Android foreground service wrapper
  ui/         home, history, settings, device_info, protocol_log
```

### 5.1 Packages

- **`universal_ble`** (BSD-3, 2.3.0 as of 2026-09) supports Android, iOS, macOS,
  Linux and Windows. **Not `flutter_blue_plus` 2.x:** it's no longer BSD-licensed
  and its Android plugin posts package metadata to a remote endpoint at build time.
- **`flutter_foreground_task`:** Android foreground service (type `connectedDevice`)
  with a partial wakelock and a persistent notification that has a Stop action.
- **`shared_preferences`**
- **`permission_handler`:** only if `universal_ble`'s own permission request turns
  out to be insufficient.

### 5.2 Session state machine (`SessionController`)

```
disconnected ──scan/auto-connect──▶ connecting ──ok──▶ idle
idle ──start()──▶ starting ──sequence done──▶ running
running ──stop() | endsAt reached──▶ stopping ──sequence done──▶ idle
running ──link lost──▶ reconnecting
reconnecting ──reconnected within 30s──▶ starting (full start sequence, same level/side/LED)
reconnecting ──30s elapsed──▶ disconnected (session logged as interrupted; no auto-resume)
any ──link lost──▶ disconnected   (if not in a session)
```

Rules:
- Session time is wall-clock: `endsAt = startedAt + duration` and
  `remaining = endsAt - now`. Never decrement a counter, so drift and
  backgrounding don't matter.
- All writes go through one serialized queue in `PulsettoLink`. Polls and
  keepalives are suspended during `starting` and `stopping`, so nothing gets
  interleaved into the start or stop sequences.
- Intensity changes are coalesced: send only the final value of a slider drag
  (on drag end), and at most one `level` command per 200 ms from the +/- buttons.
- The app never starts stimulation without a user action. The only automatic
  start is the reconnect resume, and only inside the 30 s window.
- `stop()` is idempotent and reachable from: the main button, the notification
  action, the timer reaching zero, and app termination (best effort).

### 5.3 Android background behavior

- **Starting the service:** the foreground service starts on `starting` and stops
  on `idle` or `disconnected`. It keeps the process, Dart timers, keepalive and
  auto-stop alive with the screen off.
- **Notification:** shows the program, remaining time and intensity, with a Stop
  action.
- **Keep screen on:** a setting, off by default, since the foreground service
  makes it unnecessary.

## 6. Features

### 6.1 Home (v1)

- **Status strip:** connection, battery %, charging.
- **Program chips:** section 4. Selecting one sets the duration and LED; editing
  the timer by hand deselects it (as in PR #4). The last program is persisted.
- **Timer:** 1–60 min, with − / +.
- **Intensity:** 1–9, with − / + and a slider. It stays live while running.
- **Side:** both / left / right. Defaults to both. Locked while running, for
  simplicity.
- **Start/Stop:** one big button. While running it shows the remaining time and a
  progress bar.

### 6.2 Device

- **First connect:** scan for 10 s. With one device found, connect. With several,
  show a picker.
- **Remembered device:** stored by id (MAC on Android). Later launches
  auto-connect to that device only.
- **Device info:** firmware, identity, last `mode`/`BR` values, and a Forget
  device action.

### 6.3 Settings

- **LED:** auto (program default) / low / medium / high.
- **Keep screen on during sessions:** a toggle.
- **Daily goal:** sessions per day (once history exists, v1.1).

### 6.4 Protocol log (v1, debug screen)

- **Contents:** ring buffer (about 2000 entries) of timestamped TX and RX lines,
  with write mode noted.
- **Share as text:** gives the same view as an Android HCI snoop capture, so a
  session from this app can be diffed against one from the official app.

### 6.5 History (v1.1)

- **Port of PulseLibre v2.2.0:** session log plus a Mon–Sun tracker with a daily
  goal. A day is complete at ≥ goal sessions of ≥ 60 s each.
- **Session record:** `startedAt`, `plannedSeconds`, `actualSeconds`, `strength`,
  `program?`, `side`, `outcome` (completed / stopped / interrupted).
- **Editing:** long-press to delete a session; Clear all.

## 7. Platform notes

### Android

- `minSdk 31` (Android 12) so we can declare `BLUETOOTH_SCAN` with
  `android:usesPermissionFlags="neverForLocation"` and drop location permission
  entirely, unlike PulseLibre, which requests it. Also needed: `BLUETOOTH_CONNECT`,
  `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_CONNECTED_DEVICE`, `POST_NOTIFICATIONS`,
  `WAKE_LOCK`.
- No `INTERNET` permission in the main manifest. Flutter only injects it into the
  debug/profile manifests. Release builds must be checked with
  `aapt dump permissions`.
- Use one release signing key from the first install. On a GrapheneOS phone with
  multiple user profiles, an APK signed with a different key fails with "App not
  installed" in every profile.
- Distribute by `adb install` or GitHub releases + Obtainium.

### Linux (v1.1, optional)

`universal_ble` talks to BlueZ over D-Bus. There's no foreground service; the
session runs while the window is open. This replaces pulse-libre-desktop on the
laptops.

### iOS

Out of scope. Keeping the code portable is enough. Background BLE would need
`bluetooth-central` and wouldn't keep Dart timers running reliably.

## 8. Safety requirements

1. Command allowlist (section 3.3) enforced by type. No `U`, no raw sends.
2. Intensity clamped to 0–9 in the protocol layer.
3. Every session ends with the stop sequence, by timer, button, notification, or
   app exit.
4. No auto-start except the bounded reconnect resume (section 5.2).
5. Never connect to a device advertising as `PulsUp` (DFU mode).

## 9. Testing

- **Protocol unit tests:** exact bytes and write mode for every enum value;
  notification parsing, including multi-line packets, both charging formats,
  battery clamping and unknown lines.
- **SessionController tests:** a fake `PulsettoLink` plus `fake_async`. Assert:
  - the exact start and stop sequences, including the delays;
  - keepalive every 10 s and polling every 3 s / 30 s;
  - no writes interleaved into the start or stop sequences;
  - auto-stop at `endsAt`;
  - resume when reconnected within 30 s, and interruption after 30 s;
  - slider coalescing;
  - an idempotent `stop()`.
- **Manual hardware checklist (real device):**
  - connect;
  - battery and charging shown;
  - start at level 3, change to 4, stop;
  - with the screen off for a full 4-min session, it auto-stops;
  - toggling airplane mode mid-session resumes within 30 s and interrupts after
    30 s;
  - the notification Stop action works;
  - Forget device, then rediscover.
- **Parity check:** HCI snoop captures of an official-app session and a Lull
  session at the same level/program show the same command stream, apart from the
  keepalive and the LED choice.

## 10. Open questions (answer on real hardware before or during M2)

- **Q1:** If the BLE link drops mid-session, does the device stop on its own? After
  how long? This decides whether the 30 s resume window is safe or should be
  shorter.
- **Q2:** Is the 10 s keepalive needed? Does stimulation stop after N seconds
  without writes?
- **Q3:** Does the device enforce its own maximum session length?
- **Q4:** ~~Are notifications always `\n`-terminated?~~ No: space-separated, see
  section 3.2.
- **Q5:** What do `mode:` and `BR:` mean? (Curiosity; nothing depends on them.)
- **Q6 (optional):** Do the program waves really match? Diff BLE captures of the
  official app across programs, including the paid ones during the 1-month
  Premium trial, and/or scope the output across a 500 Ω load.

Q1–Q4 can be answered in about 30 minutes with pulse-libre-desktop or nRF
Connect plus the protocol log.

## 11. Dev environment

- **Repo:** `~/projects/lull`. Flake-based devenv (Flutter + Android SDK +
  Open Design) copied from `hexhound/caremate`.
- **Build machines:** build and run on charmander or ditto (x86_64). Android and
  Flutter builds don't work on squirtle (aarch64).
- **Target:** build for `--target-platform android-arm64`.
- **Credit:** README credits jooray's protocol work (MIT).

## 12. Milestones

- **M1, core:** `protocol/` + `session/` with full unit tests against fakes. No
  UI.
- **M2, Android v1:** BLE link, foreground service, home + device info + settings
  + protocol log. Hardware checklist passes; Q1–Q4 answered and folded back into
  the spec.
- **M3, v1.1:** history and weekly tracker; Linux desktop build.

## References

- https://github.com/jooray/PulseLibre (and PR #4)
- https://github.com/jooray/pulse-libre-desktop/blob/main/docs/PULSETTO_PROTOCOL.md
- https://www.cisa.gov/news-events/ics-medical-advisories/icsma-26-223-02
- https://pub.dev/packages/universal_ble

