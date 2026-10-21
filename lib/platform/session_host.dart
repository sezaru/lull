import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// What a running session needs from the OS: a foreground service with an
/// ongoing notification (so timers survive with the screen off), its Stop
/// action, and an optional screen wake lock.
abstract class SessionHost {
  Stream<void> get stopRequests;
  Future<void> show(String title, String text);
  Future<void> hide();
  Future<void> keepAwake(bool on);

  /// A separate, sounding notification: the session finished or was cut off
  /// while the user may not be looking.
  Future<void> alertEnded(String title, String text);
}

class NoSessionHost implements SessionHost {
  @override
  Stream<void> get stopRequests => const Stream.empty();
  @override
  Future<void> show(String title, String text) async {}
  @override
  Future<void> hide() async {}
  @override
  Future<void> keepAwake(bool on) async {}
  @override
  Future<void> alertEnded(String title, String text) async {}
}

const _stopButtonId = 'stop';
const _stopMessage = 'stop';

@pragma('vm:entry-point')
void foregroundTaskStart() {
  FlutterForegroundTask.setTaskHandler(_LullTaskHandler());
}

class _LullTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id == _stopButtonId) FlutterForegroundTask.sendDataToMain(_stopMessage);
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();
}

class AndroidSessionHost implements SessionHost {
  AndroidSessionHost({required this.accent}) {
    FlutterForegroundTask.initCommunicationPort();
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'session',
        channelName: 'Session',
        channelDescription: 'Shows a running session and lets you stop it.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        allowAutoRestart: false,
      ),
    );
    FlutterForegroundTask.addTaskDataCallback((data) {
      if (data == _stopMessage) _stops.add(null);
    });
  }

  static SessionHost forPlatform({required Color accent}) =>
      Platform.isAndroid ? AndroidSessionHost(accent: accent) : NoSessionHost();

  final Color accent;
  final _stops = StreamController<void>.broadcast();
  bool _running = false;
  Future<void> _tail = Future.value();

  @override
  Stream<void> get stopRequests => _stops.stream;

  Future<void> _serial(Future<void> Function() f) =>
      _tail = _tail.then((_) => f()).catchError((_) {});

  @override
  Future<void> show(String title, String text) => _serial(() async {
    if (_running) {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
      return;
    }
    final result = await FlutterForegroundTask.startService(
      serviceTypes: [ForegroundServiceTypes.connectedDevice],
      notificationTitle: title,
      notificationText: text,
      notificationIcon: NotificationIcon(
        metaDataName: 'com.sezdocs.lull.NOTIFICATION_ICON',
        backgroundColor: accent,
      ),
      notificationButtons: [
        NotificationButton(id: _stopButtonId, text: 'Stop', textColor: accent),
      ],
      callback: foregroundTaskStart,
    );
    _running = result is ServiceRequestSuccess;
  });

  @override
  Future<void> hide() => _serial(() async {
    if (!_running) return;
    _running = false;
    await FlutterForegroundTask.stopService();
  });

  @override
  Future<void> keepAwake(bool on) => WakelockPlus.toggle(enable: on);

  static const _alerts = MethodChannel('lull/alerts');

  @override
  Future<void> alertEnded(String title, String text) =>
      _alerts.invokeMethod('sessionEnded', {'title': title, 'text': text});
}
