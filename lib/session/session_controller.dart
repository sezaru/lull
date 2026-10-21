import 'dart:async';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart';

import '../ble/pulsetto_link.dart';
import '../platform/permissions.dart';
import '../platform/session_host.dart';
import '../protocol/protocol_log.dart';
import '../protocol/pulsetto_protocol.dart';
import '../storage/history_store.dart';
import '../storage/settings_store.dart';
import 'programs.dart';

enum Gate { ready, bluetoothOff, permissionNeeded, permissionDenied }

enum LinkState { disconnected, connecting, connected }

enum ScanState { idle, scanning, several, none }

enum SessionPhase { idle, starting, running, stopping, reconnecting }

sealed class Notice {
  const Notice();
}

class InterruptedNotice extends Notice {
  const InterruptedNotice();
}

class StartFailedNotice extends Notice {
  const StartFailedNotice();
}

class DoneNotice extends Notice {
  const DoneNotice(this.label, this.minutes);
  final String label;
  final int minutes;
}

class DeviceInfo {
  int? battery;
  bool? charging;
  String? firmware;
  String? identity;
  String? mode;
  String? br;

  /// Last level the device echoed back, and whether it said it's running.
  int? level;
  bool? running;
}

/// Owns the link and the session state machine (spec 5.2). The UI only
/// renders this and calls its methods.
class SessionController extends ChangeNotifier {
  SessionController({
    required this.link,
    required this.settings,
    required this.history,
    required this.log,
    required this.host,
    required this.permissions,
  }) : program = settings.program,
       minutes = settings.minutes,
       intensity = settings.intensity,
       side = settings.side;

  static const scanWindow = Duration(seconds: 10);
  static const scanSettle = Duration(seconds: 2);
  static const connectTimeout = Duration(seconds: 10);
  static const resumeWindow = Duration(seconds: 30);
  static const keepaliveEvery = Duration(seconds: 10);
  static const sessionPollEvery = Duration(seconds: 3);
  static const idlePollEvery = Duration(seconds: 30);
  static const levelThrottle = Duration(milliseconds: 200);
  static const doneNoticeFor = Duration(minutes: 1);
  static const rxFlushAfter = Duration(milliseconds: 200);

  /// How long the busy bar on the main button takes to fill.
  static const startingTakes = Duration(milliseconds: 2400);
  static const stoppingTakes = Duration(milliseconds: 800);

  final PulsettoLink link;
  final SettingsStore settings;
  final HistoryStore history;
  final ProtocolLog log;
  final SessionHost host;
  final Permissions permissions;

  Gate gate = Gate.ready;
  LinkState linkState = LinkState.disconnected;
  ScanState scanState = ScanState.idle;
  final List<FoundDevice> found = [];
  SessionPhase phase = SessionPhase.idle;
  Notice? notice;
  DeviceInfo info = DeviceInfo();

  Program? program;
  int minutes;
  int intensity;
  Side side;

  String? get deviceId => settings.deviceId;
  bool get hasDevice => deviceId != null;

  final List<StreamSubscription<dynamic>> _subs = [];
  bool _permissionMissing = false;
  String? _connectingId;
  int _epoch = 0;

  Program? _sessionProgram;
  int _sessionMinutes = 0;
  Side _sessionSide = Side.both;
  Led _sessionLed = Led.medium;
  DateTime? _startedAt;
  DateTime? _runStartedAt;
  Duration _elapsedBefore = Duration.zero;
  DateTime? _resumeDeadline;
  DateTime _lastLevelSentAt = DateTime.fromMillisecondsSinceEpoch(0);
  Outcome _pendingOutcome = Outcome.stopped;

  Timer? _scanTimer;
  Timer? _settleTimer;
  Timer? _pollTimer;
  Timer? _keepaliveTimer;
  Timer? _tickTimer;
  Timer? _endTimer;
  Timer? _deadlineTimer;
  Timer? _levelTimer;
  Timer? _noticeTimer;
  Timer? _rxFlushTimer;
  final _rx = ReplyAssembler();

  Future<void> init() async {
    _subs
      ..add(link.received.listen(_onReceived))
      ..add(link.lost.listen((_) => _onLost()))
      ..add(link.found.listen(_onFound))
      ..add(link.availability.listen(_applyAvailability))
      ..add(host.stopRequests.listen((_) => stop()));
    await refreshGate();
  }

  // ---- gate: permission and adapter --------------------------------------

  Future<void> refreshGate() async {
    final perm = await permissions.bluetooth();
    _permissionMissing = perm != PermissionState.granted;
    if (_permissionMissing) {
      gate = perm == PermissionState.permanentlyDenied
          ? Gate.permissionDenied
          : Gate.permissionNeeded;
      notifyListeners();
      return;
    }
    Availability availability;
    try {
      availability = await link.currentAvailability();
    } catch (_) {
      availability = Availability.unknown;
    }
    _applyAvailability(availability);
    await _verifyLink();
  }

  void _applyAvailability(Availability a) {
    if (_permissionMissing) return;
    gate = a == Availability.off ? Gate.bluetoothOff : Gate.ready;
    if (gate == Gate.bluetoothOff) _onLost();
    if (gate == Gate.ready) _autoConnect();
    notifyListeners();
  }

  /// Our idea of the link can be stale (frozen in the background, Bluetooth
  /// toggled); check with the OS and treat a dead link as lost.
  Future<void> _verifyLink() async {
    if (linkState != LinkState.connected) return;
    if (await link.isConnected()) return;
    _onLost();
    _autoConnect();
  }

  void _autoConnect() {
    if (linkState == LinkState.disconnected &&
        hasDevice &&
        phase == SessionPhase.idle) {
      connect();
    }
  }

  Future<void> requestPermission() async {
    await permissions.requestBluetooth();
    await refreshGate();
  }

  Future<void> openSettings() => permissions.openSettings();

  Future<void> enableBluetooth() async {
    try {
      await link.enableBluetooth();
    } catch (_) {}
    await refreshGate();
  }

  // ---- finding and connecting --------------------------------------------

  Future<void> connect() async {
    if (gate != Gate.ready || linkState != LinkState.disconnected) return;
    final id = deviceId;
    if (id == null) return startScan();
    await _connectTo(id);
  }

  Future<bool> _connectTo(
    String id, {
    bool remember = false,
    Duration timeout = connectTimeout,
  }) async {
    _connectingId = id;
    linkState = LinkState.connecting;
    notifyListeners();
    try {
      await link.connect(id, timeout: timeout);
    } catch (_) {
      if (_connectingId == id) {
        _connectingId = null;
        linkState = LinkState.disconnected;
        notifyListeners();
      }
      return false;
    }
    if (_connectingId != id) {
      unawaited(link.disconnect().catchError((_) {}));
      return false;
    }
    _connectingId = null;
    _rx.reset();
    if (remember) settings.deviceId = id;
    linkState = LinkState.connected;
    _onConnected();
    return true;
  }

  void _onConnected() {
    switch (phase) {
      case SessionPhase.reconnecting:
        _deadlineTimer?.cancel();
        _runStart();
      case SessionPhase.stopping:
        _deadlineTimer?.cancel();
        _endSession(_pendingOutcome);
      default:
        for (final c in [
          Command.queryFirmware,
          Command.queryIdentity,
          Command.queryCharging,
          Command.queryBattery,
        ]) {
          _send(c);
        }
        _schedulePolls();
    }
    notifyListeners();
  }

  Future<void> startScan() async {
    if (gate != Gate.ready || scanState == ScanState.scanning) return;
    found.clear();
    scanState = ScanState.scanning;
    notifyListeners();
    _scanTimer = Timer(scanWindow, _finishScan);
    try {
      await link.startScan();
    } catch (_) {
      _finishScan();
    }
  }

  void _onFound(FoundDevice d) {
    if (scanState != ScanState.scanning) return;
    final i = found.indexWhere((f) => f.id == d.id);
    if (i >= 0) {
      found[i] = d;
    } else {
      found.add(d);
    }
    _settleTimer ??= Timer(scanSettle, _finishScan);
    notifyListeners();
  }

  void _finishScan() {
    if (scanState != ScanState.scanning) return;
    _scanTimer?.cancel();
    _settleTimer?.cancel();
    _settleTimer = null;
    unawaited(link.stopScan().catchError((_) {}));
    if (found.isEmpty) {
      scanState = ScanState.none;
    } else if (found.length == 1) {
      scanState = ScanState.idle;
      _connectTo(found.first.id, remember: true);
    } else {
      scanState = ScanState.several;
    }
    notifyListeners();
  }

  void pick(FoundDevice d) {
    scanState = ScanState.idle;
    _connectTo(d.id, remember: true);
  }

  Future<void> forget() async {
    if (phase != SessionPhase.idle) return;
    settings.deviceId = null;
    _connectingId = null;
    info = DeviceInfo();
    linkState = LinkState.disconnected;
    scanState = ScanState.idle;
    _pollTimer?.cancel();
    notifyListeners();
    try {
      await link.disconnect();
    } catch (_) {}
  }

  // ---- device traffic ----------------------------------------------------

  Future<bool> _send(Command c) async {
    try {
      await link.send(c);
      log.sent(c);
      return true;
    } catch (e) {
      log.failed(c, e);
      unawaited(_verifyLink());
      return false;
    }
  }

  void _onReceived(String payload) {
    _rxFlushTimer?.cancel();
    _handleLines(_rx.add(payload));
    if (_rx.hasPartial) {
      _rxFlushTimer = Timer(rxFlushAfter, () => _handleLines(_rx.flush()));
    }
  }

  void _handleLines(List<String> lines) {
    final hadBattery = info.battery != null;
    for (final line in lines) {
      log.received(line);
      switch (parseLine(line)) {
        case BatteryEvent e:
          info.battery = e.percent;
        case ChargingEvent e:
          info.charging = e.charging;
        case FirmwareEvent e:
          info.firmware = e.version;
        case IdentityEvent e:
          info.identity = e.identity;
        case ModeEvent e:
          info.mode = e.value;
        case BrEvent e:
          info.br = e.value;
        case EchoEvent e:
          info.level = e.level ?? info.level;
        case RampEvent e:
          info.running = e.running;
        case UnknownLine():
          break;
      }
    }
    if (!hadBattery && info.battery != null) _schedulePolls();
    notifyListeners();
  }

  void _schedulePolls() {
    _pollTimer?.cancel();
    if (linkState != LinkState.connected) return;
    // The device now and then skips a reply, so keep asking quickly until
    // the battery is known.
    final every = phase == SessionPhase.idle && info.battery != null
        ? idlePollEvery
        : sessionPollEvery;
    _pollTimer = Timer.periodic(every, (_) {
      if (phase == SessionPhase.starting || phase == SessionPhase.stopping) {
        return;
      }
      _send(Command.queryCharging);
      _send(Command.queryBattery);
    });
  }

  void _onLost() {
    if (linkState == LinkState.disconnected) return;
    linkState = LinkState.disconnected;
    _pollTimer?.cancel();
    switch (phase) {
      case SessionPhase.idle:
        break;
      case SessionPhase.starting:
      case SessionPhase.running:
        _epoch++;
        _freeze();
        phase = SessionPhase.reconnecting;
        _openResumeWindow();
      case SessionPhase.stopping:
        // The stop sequence may not have arrived: reconnect to send it.
        _epoch++;
        _openResumeWindow();
      case SessionPhase.reconnecting:
        break;
    }
    _updateHost();
    notifyListeners();
  }

  void _openResumeWindow() {
    _resumeDeadline = clock.now().add(resumeWindow);
    _deadlineTimer?.cancel();
    _deadlineTimer = Timer(resumeWindow, _resumeWindowClosed);
    _tickTimer ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _reconnectLoop();
  }

  bool get _awaitingLink =>
      (phase == SessionPhase.reconnecting || phase == SessionPhase.stopping) &&
      linkState != LinkState.connected;

  Future<void> _reconnectLoop() async {
    final id = deviceId;
    final deadline = _resumeDeadline;
    if (id == null || deadline == null) return;
    while (_awaitingLink && _resumeDeadline == deadline) {
      final left = deadline.difference(clock.now());
      if (left <= Duration.zero) return;
      if (gate == Gate.ready && linkState == LinkState.disconnected) {
        final ok = await _connectTo(
          id,
          timeout: left < connectTimeout ? left : connectTimeout,
        );
        if (ok) return;
      }
      await Future<void>.delayed(const Duration(seconds: 1));
    }
  }

  void _resumeWindowClosed() {
    if (!_awaitingLink) return;
    _connectingId = null;
    linkState = LinkState.disconnected;
    unawaited(link.disconnect().catchError((_) {}));
    if (phase == SessionPhase.reconnecting) {
      _finishSession(Outcome.interrupted);
      notice = const InterruptedNotice();
    } else {
      _finishSession(_pendingOutcome);
    }
    notifyListeners();
  }

  // ---- program, timer, intensity, side -----------------------------------

  bool get _editable => phase == SessionPhase.idle;

  void selectProgram(Program p) {
    if (!_editable) return;
    program = p;
    minutes = p.minutes;
    settings
      ..program = p
      ..minutes = p.minutes;
    notifyListeners();
  }

  void setMinutes(int m) {
    if (!_editable) return;
    m = m.clamp(1, 60);
    if (m == minutes) return;
    minutes = m;
    program = null;
    settings
      ..minutes = m
      ..program = null;
    notifyListeners();
  }

  void setSide(Side s) {
    if (!_editable) return;
    side = s;
    settings.side = s;
    notifyListeners();
  }

  /// Sends at most one level command per [levelThrottle]; the latest value
  /// wins. The slider calls this only on drag end.
  void setIntensity(int n) {
    n = n.clamp(1, 9);
    if (n == intensity) return;
    intensity = n;
    settings.intensity = n;
    notifyListeners();
    if (phase != SessionPhase.running) return;
    final since = clock.now().difference(_lastLevelSentAt);
    if (since >= levelThrottle) {
      _sendLevel();
    } else {
      _levelTimer ??= Timer(levelThrottle - since, () {
        _levelTimer = null;
        if (phase == SessionPhase.running) _sendLevel();
      });
    }
  }

  void _sendLevel() {
    _lastLevelSentAt = clock.now();
    _send(Command.level(intensity));
    _updateHost();
  }

  // ---- the session -------------------------------------------------------

  bool get canStart =>
      gate == Gate.ready &&
      linkState == LinkState.connected &&
      phase == SessionPhase.idle;

  Duration get _elapsed {
    final run = _runStartedAt;
    return run == null
        ? _elapsedBefore
        : _elapsedBefore + clock.now().difference(run);
  }

  Duration get planned => Duration(minutes: _sessionMinutes);

  Duration get remaining {
    final left = planned - _elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  double get progress => _sessionMinutes == 0
      ? 0
      : math.min(1, _elapsed.inMilliseconds / planned.inMilliseconds);

  Duration get resumeLeft {
    final d = _resumeDeadline;
    if (d == null) return Duration.zero;
    final left = d.difference(clock.now());
    return left.isNegative ? Duration.zero : left;
  }

  String get sessionLabel => programLabel(_sessionProgram);
  int get sessionMinutes => _sessionMinutes;

  /// The link dropped mid-session and we're inside the resume window.
  bool get resuming => _awaitingLink;

  Future<void> start() async {
    if (!canStart) return;
    notice = null;
    _noticeTimer?.cancel();
    _sessionProgram = program;
    _sessionMinutes = minutes;
    _sessionSide = side;
    _sessionLed = settings.ledMode.resolve(program);
    _startedAt = clock.now();
    _elapsedBefore = Duration.zero;
    _runStartedAt = null;
    unawaited(host.keepAwake(settings.keepScreenOn));
    await _runStart();
  }

  Future<void> _runStart() async {
    phase = SessionPhase.starting;
    _pollTimer?.cancel();
    notifyListeners();
    _updateHost();
    final e = ++_epoch;
    const ms250 = Duration(milliseconds: 250);
    const ms450 = Duration(milliseconds: 450);
    final ok = await _sequence(e, [
      Command.rampUp,
      Command.rampDown,
      ms250,
      Command.level(0),
      ms450,
      Command.level(5),
      ms450,
      Command.level(0),
      ms450,
      Command.level(intensity),
      ms250,
      Command.side(_sessionSide),
      Command.led(_sessionLed),
    ]);
    if (e != _epoch) return;
    if (!ok) return _abortStart();
    phase = SessionPhase.running;
    _resumeDeadline = null;
    _runStartedAt = clock.now();
    _lastLevelSentAt = clock.now();
    _endTimer?.cancel();
    _endTimer = Timer(remaining, () {
      if (phase == SessionPhase.running) _endSession(Outcome.completed);
    });
    _keepaliveTimer?.cancel();
    _keepaliveTimer = Timer.periodic(keepaliveEvery, (_) {
      if (phase == SessionPhase.running) _sendLevel();
    });
    _tickTimer ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _schedulePolls();
    _updateHost();
    notifyListeners();
  }

  /// A start command failed without the link being reported lost. Some ramp
  /// commands may have arrived, so try to stop the device before giving up.
  Future<void> _abortStart() async {
    final e = ++_epoch;
    await _sequence(e, [Command.rampUp, Command.rampDown, Command.rampDown]);
    if (e != _epoch) return;
    if (_elapsedBefore > Duration.zero) {
      _finishSession(Outcome.interrupted);
    } else {
      phase = SessionPhase.idle;
      _tickTimer?.cancel();
      _tickTimer = null;
      unawaited(host.hide());
      unawaited(host.keepAwake(false));
      _schedulePolls();
    }
    notice = const StartFailedNotice();
    notifyListeners();
  }

  Future<bool> _sequence(int epoch, List<Object> steps) async {
    for (final step in steps) {
      if (step is Duration) {
        await Future<void>.delayed(step);
      } else if (!await _send(step as Command)) {
        return false;
      }
      if (epoch != _epoch) return false;
    }
    return true;
  }

  void _tick() {
    _updateHost();
    notifyListeners();
  }

  void _freeze() {
    final run = _runStartedAt;
    if (run != null) _elapsedBefore += clock.now().difference(run);
    _runStartedAt = null;
    _endTimer?.cancel();
    _keepaliveTimer?.cancel();
    _levelTimer?.cancel();
    _levelTimer = null;
  }

  /// Safe to call any number of times, from any phase.
  Future<void> stop() async {
    switch (phase) {
      case SessionPhase.idle:
      case SessionPhase.stopping:
        return;
      case SessionPhase.reconnecting:
        // Keep trying to reach the device until the window closes, so the
        // stop sequence still gets sent if it comes back.
        _pendingOutcome = Outcome.stopped;
        phase = SessionPhase.stopping;
        _updateHost();
        notifyListeners();
      case SessionPhase.starting:
      case SessionPhase.running:
        await _endSession(Outcome.stopped);
    }
  }

  Future<void> _endSession(Outcome outcome) async {
    _freeze();
    _pendingOutcome = outcome;
    phase = SessionPhase.stopping;
    _pollTimer?.cancel();
    notifyListeners();
    final e = ++_epoch;
    final ok = await _sequence(e, [
      Command.rampUp,
      Command.rampDown,
      Command.rampDown,
    ]);
    if (!ok || e != _epoch) return;
    _finishSession(outcome);
  }

  void _finishSession(Outcome outcome) {
    final plannedSeconds = _sessionMinutes * 60;
    final actual = outcome == Outcome.completed
        ? plannedSeconds
        : math.min(plannedSeconds, _elapsed.inSeconds);
    history.add(
      SessionRecord(
        startedAt: _startedAt ?? clock.now(),
        plannedSeconds: plannedSeconds,
        actualSeconds: actual,
        strength: intensity,
        program: _sessionProgram,
        side: _sessionSide,
        outcome: outcome,
      ),
    );
    if (settings.alertOnEnd && outcome != Outcome.stopped) {
      unawaited(
        outcome == Outcome.completed
            ? host.alertEnded(
                'Session complete',
                '$sessionLabel · $_sessionMinutes min',
              )
            : host.alertEnded(
                'Session interrupted',
                'The device didn’t reconnect in time.',
              ),
      );
    }
    if (outcome == Outcome.completed) {
      notice = DoneNotice(sessionLabel, _sessionMinutes);
      _noticeTimer?.cancel();
      _noticeTimer = Timer(doneNoticeFor, () {
        if (notice is DoneNotice) dismissNotice();
      });
    }
    phase = SessionPhase.idle;
    _runStartedAt = null;
    _resumeDeadline = null;
    _deadlineTimer?.cancel();
    _tickTimer?.cancel();
    _tickTimer = null;
    _endTimer?.cancel();
    _keepaliveTimer?.cancel();
    unawaited(host.hide());
    unawaited(host.keepAwake(false));
    _schedulePolls();
    notifyListeners();
  }

  void dismissNotice() {
    notice = null;
    notifyListeners();
  }

  void _updateHost() {
    if (phase == SessionPhase.idle) return;
    final title = '$sessionLabel · ${formatClock(remaining)} left';
    final text = resuming
        ? 'Connection lost. Resuming…'
        : 'Intensity $intensity · ${sideLabel(_sessionSide)}';
    unawaited(host.show(title, text));
  }

  void setAlertOnEnd(bool on) {
    settings.alertOnEnd = on;
    notifyListeners();
  }

  void setKeepScreenOn(bool on) {
    settings.keepScreenOn = on;
    if (phase != SessionPhase.idle) unawaited(host.keepAwake(on));
    notifyListeners();
  }

  void setLedMode(LedMode m) {
    settings.ledMode = m;
    notifyListeners();
  }

  void setDailyGoal(int goal) {
    settings.dailyGoal = goal.clamp(1, 10);
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    for (final t in [
      _scanTimer,
      _settleTimer,
      _pollTimer,
      _keepaliveTimer,
      _tickTimer,
      _endTimer,
      _deadlineTimer,
      _levelTimer,
      _noticeTimer,
      _rxFlushTimer,
    ]) {
      t?.cancel();
    }
    super.dispose();
  }
}

String formatClock(Duration d) {
  final s = (d.inMilliseconds / 1000).ceil();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

String sideLabel(Side s) => switch (s) {
  Side.both => 'Both sides',
  Side.left => 'Left side',
  Side.right => 'Right side',
};
