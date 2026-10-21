# Lull

An ad-free remote for the Pulsetto vagus nerve stimulator. Pick a program,
set the intensity, press Start. No account, no internet, no content.

Android first (minSdk 31); the code also builds for Linux. The design is in
`docs/spec.md` and `docs/design/UI-HANDOFF.md`.

## Develop

Builds need x86_64 (charmander or ditto), not squirtle.

```sh
flutter test
flutter build apk --release --target-platform android-arm64
```

Run without a Pulsetto: `--dart-define=LULL_SIMULATE=true` swaps the BLE link
for a pretend device that answers like the real one.

Release builds are signed with `android/key.properties` when it exists (see
`android/app/build.gradle.kts`), else with the debug key.

## Credit

The Pulsetto BLE protocol was reverse-engineered by Juraj Bednar in
[PulseLibre](https://github.com/jooray/PulseLibre) and
[pulse-libre-desktop](https://github.com/jooray/pulse-libre-desktop) (MIT).
