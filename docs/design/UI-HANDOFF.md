# Lull: UI handoff

Lull is an ad-free remote for a Pulsetto, a neck-worn vagus nerve stimulator.
You put the device on, pick a program, set the intensity and press Start. The
app talks to it over Bluetooth and stops it when the timer runs out. There is
no account, no internet and no content. It is a remote control, not a
wellness app.

The behaviour behind every screen is in `docs/spec.md`. Where this file and
the spec disagree, the spec wins.

## Canvas and context

- Android phone, 412×915 (Pixel class, GrapheneOS). Portrait only.
- It's used half-asleep at bedtime (Sleep program) and in the middle of a
  stressful day. One hand, glanceable, big targets. Dark mode matters as much
  as light.
- A session runs 4–20 minutes, and most of that time the screen is off or the
  phone is face down. The ongoing notification is part of the UI.

## Navigation

Bottom bar with three tabs: `Home`, `History`, `Settings`. **Device** and
**Protocol log** are pushed screens. Device opens from the status strip on
Home or from Settings. Protocol log opens from Settings.

## 1. Home

From top to bottom:

1. **Status strip.** Device name (`Pulsetto`), connection state, battery % with
   a charging mark when charging. Tapping it opens Device.
2. **Programs.** Nine choices, each with its name and duration: `Stress 4 min`,
   `Anxiety 6 min`, `Sleep 10 min`, `Burnout 6 min`, `Pain 20 min`,
   `Head Pain 6 min`, `Inflammation 4 min`, `Gut Health 5 min`,
   `Personal 8 min`. All are free and none is locked. One or none is selected.
3. **Timer.** Minutes, 1–60, with `−` and `+`. Changing it by hand deselects
   the program.
4. **Intensity.** Level 1–9, with `−`, `+` and a slider. The number is large,
   since it's the thing people adjust most.
5. **Side.** Segmented: `Both`, `Left`, `Right`. Defaults to `Both`.
6. **Start button.** One large primary button.

### Home states (one frame each)

| # | State | What changes |
|---|---|---|
| 1 | **Idle, ready** | Strip: `Connected · 82%`. `Sleep` selected, timer 10, intensity 4, side Both. Button `Start`. |
| 2 | **Running** | The timer area becomes remaining time (`7:42`) with a progress bar and the program name. Intensity stays live (−/+/slider work). Programs, timer and side are locked (dimmed, not hidden). Button `Stop`. |
| 3 | **Starting** | About 3 s while the start sequence is sent. Button `Starting…` and disabled. Everything else is locked. |
| 4 | **Stopping** | Under 1 s. Button `Stopping…` and disabled. |
| 5 | **Connection lost, resuming** | Mid-session link drop. Banner: `Connection lost. Resuming…` with a 30 s countdown (`0:24`). Remaining time is frozen and greyed. `Stop` stays available. |
| 6 | **Interrupted** | After 30 s without reconnecting. Banner: `Session interrupted. The device didn't reconnect in time.` Back to the idle layout with `Start` disabled until connected. |
| 7 | **Session complete** | Timer reached zero. Short confirmation: `Done · Sleep · 10 min`. Then idle again. |
| 8 | **Disconnected** | Strip: `Not connected`. Controls are visible but `Start` is disabled. Secondary action `Connect`. |
| 9 | **Connecting** | Strip: `Connecting…`, with a spinner. |
| 10 | **Charging** | Idle with the strip showing `Charging · 64%`. |

Intensity: while the slider is dragged the number follows the finger. The
device only gets the final value on release. No intermediate feedback is
needed.

## 2. Device

- **First connect / no device remembered:** `Looking for your Pulsetto…` for up
  to 10 s, with `Make sure it's switched on and nearby.` When one is found it
  connects straight away. When several are found, show a list (`Pulsetto`,
  `Pulsetto` with signal strength and the last 4 characters of the address,
  e.g. `…3F:A1`) and the user taps one. When none are found:
  `No Pulsetto found` with `Try again`.
- **Remembered device:** name, address `C4:7F:51:0E:3F:A1`, connection state,
  battery, charging, firmware `1.1.22`, identity `Pulsetto_ST_02`, and two
  diagnostic values shown small: `mode 0`, `BR 100`.
- **Action:** `Forget device` (destructive, with confirmation). After that the
  next launch scans again.

### Device frames
1. Scanning. 2. Several found (list of 2). 3. None found. 4. Connected device
info. 5. Forget confirmation.

## 3. Blocking states (full-screen or Home overlay)

- **Bluetooth off:** `Bluetooth is off` and `Turn on Bluetooth`.
- **Permission needed:** `Lull needs Nearby devices permission to find your
  Pulsetto.` and `Allow`. It never asks for location.
- **Permission denied permanently:** same text plus `Open settings`.
- **Notifications** (Android 13+, asked before the first session):
  `Allow notifications so you can see and stop sessions with the screen off.`
  with `Allow` and `Not now`.

## 4. Ongoing notification

Shown during a session, including with the screen off.
- Title: `Sleep · 7:42 left`
- Text: `Intensity 4 · Both sides`
- One action: `Stop`
- While resuming: `Connection lost. Resuming…`

Draw it as it appears in the Android notification shade and on the lock
screen.

## 5. History

- **Week tracker:** Mon–Sun row. Each day is marked complete when it has at
  least the daily goal of sessions (each ≥ 60 s). Today is highlighted. Text:
  `2 of 7 days this week` (sample data below: goal 2, it's Tuesday).
- **Daily goal:** `Goal: 2 sessions a day` (set in Settings).
- **Session list,** newest first, grouped by day (`Today`, `Yesterday`,
  `Mon 12 Oct`). Each row: time `22:41`, program or `Custom`, `10 of 10 min`,
  intensity `4`, side when not Both, and outcome: completed, `Stopped at 6:12`,
  or `Interrupted`.
- Long-press a row to `Delete session`. A `Clear all` in the overflow menu,
  with confirmation.
- **Empty:** `No sessions yet. Your sessions will show up here.`

Sample data: today 22:41 Sleep 10 of 10 min, level 4. Today 13:05 Stress 4 of
4 min, level 5. Yesterday 23:02 Sleep, stopped at 6:12, level 3. Yesterday
08:30 Custom 15 of 15 min, level 6, Left. Mon 12 Oct 18:20 Pain, interrupted
at 11:40, level 5.

## 6. Settings

- `Device`: opens Device, showing `Pulsetto · Connected`.
- `LED brightness`: `Auto (per program)`, `Low`, `Medium`, `High`. The device
  has a small LED; Auto means dim for Sleep, medium otherwise.
- `Keep screen on during sessions`: toggle, off by default.
- `Daily goal`: `1`–`10` sessions a day.
- `Protocol log`: opens the log.
- `About`: version `1.0.0`, `Protocol work by Juraj Bednar (PulseLibre, MIT)`,
  `Open source licenses`.

## 7. Protocol log (debug)

A monospace list of what the app sent and received, newest at the bottom:

```
22:41:03.120  →  +      (with response)
22:41:03.180  →  -      (with response)
22:41:03.430  →  0
22:41:03.880  →  5
22:41:05.240  ←  Batt:3.97
22:41:05.241  ←  u\x011
22:41:08.300  ←  fw:1.1.22
```

Sent and received lines are visually distinct. One action: `Share as text`.

## Do not add

- Ads, upsells, `Premium`/`Pro` badges, lock icons on programs.
- Accounts, sign-in, cloud sync, social, sharing of progress.
- Guided breathing, meditations, sounds, affirmations, articles, tips.
- Heart rate, HRV, stress scores, charts, the official app's "CNS tap test".
- Streaks, badges, confetti, points. The week tracker is the only progress UI.
- Firmware update, any "advanced commands" screen.
- A Pause button. The device supports it, but v1 doesn't have one.
- Changing side or timer while running.
- Onboarding carousels. First launch goes straight to permissions and scanning.
- Location permission wording anywhere.
- More than one device connected at a time.

## Suggested design rounds

The user's usual flow (the `designing-ui-in-rounds` skill): Home wireframe
(frames 1–10) → Device + blocking states → History + Settings + Protocol log
→ notification → look foundation → look per area. Feed one area at a time,
not this whole file at once.
