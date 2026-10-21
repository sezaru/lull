import 'package:flutter/material.dart';

import '../session/session_controller.dart';
import 'icons.dart';
import 'widgets/basics.dart';

/// Bluetooth off or the Nearby devices permission missing. Replaces Home;
/// History and Settings stay reachable.
class BlockingView extends StatelessWidget {
  const BlockingView({super.key, required this.c});
  final SessionController c;

  static const _nearby =
      'Lull needs Nearby devices permission to find your Pulsetto.';

  @override
  Widget build(BuildContext context) {
    return switch (c.gate) {
      Gate.bluetoothOff => CenteredState(
        glyph: LullGlyph.bluetoothOff,
        say: 'Bluetooth is off',
        action: AccentButton(
          label: 'Turn on Bluetooth',
          onTap: c.enableBluetooth,
        ),
      ),
      Gate.permissionNeeded => CenteredState(
        glyph: LullGlyph.nearby,
        say: _nearby,
        action: AccentButton(label: 'Allow', onTap: c.requestPermission),
      ),
      Gate.permissionDenied => CenteredState(
        glyph: LullGlyph.nearby,
        say: _nearby,
        action: AccentButton(label: 'Open settings', onTap: c.openSettings),
      ),
      Gate.ready => const SizedBox.shrink(),
    };
  }
}
