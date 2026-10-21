import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ble/pulsetto_link.dart';
import 'ble/simulated_link.dart';
import 'ble/universal_ble_link.dart';
import 'platform/permissions.dart';
import 'platform/session_host.dart';
import 'protocol/protocol_log.dart';
import 'session/session_controller.dart';
import 'storage/history_store.dart';
import 'storage/settings_store.dart';
import 'ui/app.dart';
import 'ui/theme.dart';

const _simulate = bool.fromEnvironment('LULL_SIMULATE');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final settings = await SettingsStore.open();
  final history = await HistoryStore.open();
  final log = ProtocolLog();
  final PulsettoLink link = _simulate ? SimulatedLink() : UniversalBleLink();
  final controller = SessionController(
    link: link,
    settings: settings,
    history: history,
    log: log,
    host: AndroidSessionHost.forPlatform(accent: LullColors.light.accentFill),
    permissions: _simulate
        ? SimulatedPermissions(Permissions.forPlatform())
        : Permissions.forPlatform(),
  );
  await controller.init();

  runApp(LullApp(controller: controller, history: history, log: log));
}
