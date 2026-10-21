import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lull/ble/pulsetto_link.dart';
import 'package:lull/protocol/protocol_log.dart';
import 'package:lull/protocol/pulsetto_protocol.dart';
import 'package:lull/session/programs.dart';
import 'package:lull/session/session_controller.dart';
import 'package:lull/storage/history_store.dart';
import 'package:lull/storage/settings_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

const startCodes = ['+', '-', '0', '5', '0', '3', 'D', 'F'];

void main() {
  late SettingsStore settings;
  late HistoryStore history;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'deviceId': 'c4:7f:51:0e:3f:a1',
      'program': 'stress',
      'minutes': 4,
      'intensity': 3,
    });
    final prefs = await SharedPreferences.getInstance();
    settings = SettingsStore(prefs);
    history = HistoryStore(prefs);
  });

  ({SessionController c, FakeLink link, FakeHost host}) build(FakeAsync async) {
    final link = FakeLink();
    final host = FakeHost();
    final c = SessionController(
      link: link,
      settings: settings,
      history: history,
      log: ProtocolLog(),
      host: host,
      permissions: FakePermissions(),
    );
    c.init();
    async.flushMicrotasks();
    return (c: c, link: link, host: host);
  }

  /// Starts a session and runs it past the start sequence.
  int startRunning(FakeAsync async, SessionController c, FakeLink link) {
    final t = link.writes.length;
    c.start();
    async.elapse(const Duration(seconds: 2));
    expect(c.phase, SessionPhase.running);
    return t;
  }

  test('connects to the remembered device and asks who it is', () {
    fakeAsync((async) {
      final (:c, :link, host: _) = build(async);
      expect(c.linkState, LinkState.connected);
      expect(link.codesFrom(0), ['v', 'i', 'u', 'Q']);
      c.dispose();
    });
  });

  test('replies update device info', () {
    fakeAsync((async) {
      final (:c, :link, host: _) = build(async);
      link.reply('Batt:3.83\nu\x011\nfw:1.1.22\n');
      expect(c.info.battery, 83);
      expect(c.info.charging, true);
      expect(c.info.firmware, '1.1.22');
      c.dispose();
    });
  });

  test('split and unterminated replies still update device info', () {
    fakeAsync((async) {
      final (:c, :link, host: _) = build(async);
      link
        ..reply('mode:0 BR:')
        ..reply('100 ')
        ..reply('u\x011');
      expect(c.info.br, '100');
      expect(c.info.charging, isNull);
      async.elapse(SessionController.rxFlushAfter);
      expect(c.info.charging, true);
      c.dispose();
    });
  });

  test('device echoes record the confirmed level and run state', () {
    fakeAsync((async) {
      final (:c, :link, host: _) = build(async);
      link.reply('+1 0 50 9D 9u\x011 ');
      expect(c.info.level, 9);
      expect(c.info.running, true);
      expect(c.info.charging, true);
      link.reply('+0 ');
      expect(c.info.running, false);
      c.dispose();
    });
  });

  test('start sends the exact sequence with its delays', () {
    fakeAsync((async) {
      final (:c, :link, host: _) = build(async);
      final mark = link.writes.length;
      final t0 = clock.now();
      c.start();
      async.elapse(const Duration(seconds: 5));
      final seq = link.writes.skip(mark).take(8).toList();
      expect(seq.map((w) => w.code), startCodes);
      expect(seq.map((w) => w.at.difference(t0).inMilliseconds), [
        0,
        0,
        250,
        700,
        1150,
        1600,
        1850,
        1850,
      ]);
      c.dispose();
    });
  });

  test('Sleep starts with the LED dim, others medium, setting overrides', () {
    fakeAsync((async) {
      final (:c, :link, host: _) = build(async);
      c.selectProgram(Program.sleep);
      var t = startRunning(async, c, link);
      expect(link.codesFrom(t)[7], 'E');
      c.stop();
      async.elapse(const Duration(seconds: 1));
      c.setLedMode(LedMode.high);
      t = startRunning(async, c, link);
      expect(link.codesFrom(t)[7], 'G');
      c.stop();
      async.elapse(const Duration(seconds: 1));
      c.dispose();
    });
  });

  test('nothing is interleaved into the start or stop sequence', () {
    fakeAsync((async) {
      final (:c, :link, host: _) = build(async);
      // Land the idle 30 s poll inside the start sequence.
      async.elapse(const Duration(seconds: 29));
      final t0 = link.writes.length;
      c.start();
      async.elapse(const Duration(seconds: 2));
      expect(link.codesFrom(t0).take(8), startCodes);
      final t1 = link.writes.length;
      c.stop();
      async.elapse(const Duration(seconds: 2));
      expect(link.codesFrom(t1).take(3), ['+', '-', '-']);
      c.dispose();
    });
  });

  test('keepalive every 10 s and polls every 3 s while running', () {
    fakeAsync((async) {
      final (:c, :link, host: _) = build(async);
      startRunning(async, c, link);
      final t = link.writes.length;
      async.elapse(const Duration(seconds: 10));
      final writes = link.writes.skip(t).toList();
      final keepalives = writes.where((w) => w.code == '3').toList();
      expect(keepalives.length, 1);
      final polls = writes.where((w) => w.code == 'Q').length;
      expect(polls, 3);
      c.dispose();
    });
  });

  test('polls every 3 s until the battery is known, then every 30 s', () {
    fakeAsync((async) {
      final (:c, :link, host: _) = build(async);
      async.elapse(const Duration(seconds: 7));
      expect(link.codesFrom(4), ['u', 'Q', 'u', 'Q']);
      link.reply('Batt:3.80 ');
      final t = link.writes.length;
      async.elapse(const Duration(seconds: 61));
      expect(link.codesFrom(t), ['u', 'Q', 'u', 'Q']);
      c.dispose();
    });
  });

  test('stops by itself when the time is up and logs a completed session', () {
    fakeAsync((async) {
      final (:c, :link, :host) = build(async);
      c.setMinutes(1);
      startRunning(async, c, link);
      expect(host.shown, true);
      async.elapse(const Duration(seconds: 59));
      expect(c.phase, SessionPhase.running);
      final t = link.writes.length;
      async.elapse(const Duration(seconds: 1));
      expect(link.codesFrom(t).take(3), ['+', '-', '-']);
      expect(c.phase, SessionPhase.idle);
      expect(host.shown, false);
      final r = history.records.single;
      expect(r.outcome, Outcome.completed);
      expect(r.actualSeconds, 60);
      expect(r.program, isNull);
      expect(c.notice, isA<DoneNotice>());
      expect(host.alerts, ['Session complete: Custom · 1 min']);
      c.dispose();
    });
  });

  test('stop is idempotent', () {
    fakeAsync((async) {
      final (:c, :link, :host) = build(async);
      startRunning(async, c, link);
      async.elapse(const Duration(seconds: 30));
      final t = link.writes.length;
      c.stop();
      c.stop();
      async.elapse(const Duration(seconds: 1));
      c.stop();
      async.elapse(const Duration(seconds: 1));
      expect(link.codesFrom(t).where((s) => s == '+').length, 1);
      expect(history.records.single.outcome, Outcome.stopped);
      expect(history.records.single.actualSeconds, 30);
      expect(host.alerts, isEmpty);
      c.dispose();
    });
  });

  test('the notification Stop action stops the session', () {
    fakeAsync((async) {
      final (:c, :link, :host) = build(async);
      startRunning(async, c, link);
      host.stops.add(null);
      async.elapse(const Duration(seconds: 1));
      expect(c.phase, SessionPhase.idle);
      c.dispose();
    });
  });

  test('intensity changes are coalesced to one per 200 ms', () {
    fakeAsync((async) {
      final (:c, :link, host: _) = build(async);
      startRunning(async, c, link);
      async.elapse(const Duration(seconds: 1));
      final t = link.writes.length;
      c.setIntensity(4);
      c.setIntensity(5);
      c.setIntensity(6);
      async.elapse(const Duration(milliseconds: 199));
      expect(link.codesFrom(t), ['4']);
      async.elapse(const Duration(milliseconds: 1));
      expect(link.codesFrom(t), ['4', '6']);
      c.dispose();
    });
  });

  test('a lost link resumes with the full start sequence within 30 s', () {
    fakeAsync((async) {
      final (:c, :link, :host) = build(async);
      startRunning(async, c, link);
      async.elapse(const Duration(seconds: 20));
      link.connectSucceeds = false;
      link.drop();
      expect(c.phase, SessionPhase.reconnecting);
      expect(host.text, 'Connection lost. Resuming…');
      final frozen = c.remaining;
      async.elapse(const Duration(seconds: 10));
      expect(c.remaining, frozen);
      link.connectSucceeds = true;
      final t = link.writes.length;
      async.elapse(const Duration(seconds: 3));
      expect(c.phase, SessionPhase.running);
      expect(link.codesFrom(t).take(8), startCodes);
      expect(c.remaining.inSeconds, closeTo(frozen.inSeconds - 1, 1));
      c.dispose();
    });
  });

  test('no reconnect within 30 s interrupts the session', () {
    fakeAsync((async) {
      final (:c, :link, :host) = build(async);
      startRunning(async, c, link);
      async.elapse(const Duration(seconds: 42));
      link.connectSucceeds = false;
      link.drop();
      async.elapse(const Duration(seconds: 29));
      expect(c.phase, SessionPhase.reconnecting);
      async.elapse(const Duration(seconds: 2));
      expect(c.phase, SessionPhase.idle);
      expect(c.linkState, LinkState.disconnected);
      expect(c.notice, isA<InterruptedNotice>());
      expect(host.shown, false);
      expect(host.alerts.single, startsWith('Session interrupted'));
      final r = history.records.single;
      expect(r.outcome, Outcome.interrupted);
      expect(r.actualSeconds, 42);
      // No auto-resume after the window.
      link.connectSucceeds = true;
      async.elapse(const Duration(seconds: 60));
      expect(c.phase, SessionPhase.idle);
      c.dispose();
    });
  });

  test('stop while resuming still sends the stop sequence on reconnect', () {
    fakeAsync((async) {
      final (:c, :link, host: _) = build(async);
      startRunning(async, c, link);
      link.connectSucceeds = false;
      link.drop();
      c.stop();
      expect(c.phase, SessionPhase.stopping);
      link.connectSucceeds = true;
      final t = link.writes.length;
      async.elapse(const Duration(seconds: 3));
      expect(link.codesFrom(t).take(3), ['+', '-', '-']);
      expect(c.phase, SessionPhase.idle);
      expect(history.records.single.outcome, Outcome.stopped);
      c.dispose();
    });
  });

  test('no end alert when it is switched off', () {
    fakeAsync((async) {
      final (:c, :link, :host) = build(async);
      c.setAlertOnEnd(false);
      c.setMinutes(1);
      startRunning(async, c, link);
      async.elapse(const Duration(seconds: 61));
      expect(c.phase, SessionPhase.idle);
      expect(host.alerts, isEmpty);
      c.dispose();
    });
  });

  test('a start command that fails goes back to idle and says so', () {
    fakeAsync((async) {
      final (:c, :link, :host) = build(async);
      link.writesFail = true;
      c.start();
      async.elapse(const Duration(seconds: 5));
      expect(c.phase, SessionPhase.idle);
      expect(c.notice, isA<StartFailedNotice>());
      expect(host.shown, false);
      expect(history.records, isEmpty);
      c.dispose();
    });
  });

  test('Bluetooth switched off drops the link', () {
    fakeAsync((async) {
      final (:c, :link, host: _) = build(async);
      link.connected = false;
      link.setAvailability(Availability.off);
      expect(c.gate, Gate.bluetoothOff);
      expect(c.linkState, LinkState.disconnected);
      c.dispose();
    });
  });

  test('a link that died unnoticed is caught and reconnected', () {
    fakeAsync((async) {
      final (:c, :link, host: _) = build(async);
      link.connected = false;
      final attempts = link.connectAttempts;
      c.refreshGate();
      async.flushMicrotasks();
      expect(link.connectAttempts, attempts + 1);
      expect(c.linkState, LinkState.connected);
      c.dispose();
    });
  });

  test('never starts without a connected device', () {
    fakeAsync((async) {
      final (:c, :link, host: _) = build(async);
      link.connectSucceeds = false;
      link.drop();
      final t = link.writes.length;
      c.start();
      async.elapse(const Duration(seconds: 5));
      expect(c.phase, SessionPhase.idle);
      expect(link.codesFrom(t), isEmpty);
      c.dispose();
    });
  });

  test('timer, programs and side are locked during a session', () {
    fakeAsync((async) {
      final (:c, :link, host: _) = build(async);
      startRunning(async, c, link);
      c.setMinutes(30);
      c.selectProgram(Program.pain);
      c.setSide(Side.left);
      expect(c.minutes, 4);
      expect(c.program, Program.stress);
      expect(c.side, Side.both);
      c.dispose();
    });
  });

  test('scan: one Pulsetto connects and is remembered; several ask', () {
    fakeAsync((async) {
      settings.deviceId = null;
      final (:c, :link, host: _) = build(async);
      expect(c.linkState, LinkState.disconnected);
      c.startScan();
      link.advertise(const FoundDevice(id: 'aa', name: 'Pulsetto'));
      async.elapse(const Duration(seconds: 3));
      expect(c.linkState, LinkState.connected);
      expect(settings.deviceId, 'aa');

      c.forget();
      async.flushMicrotasks();
      c.startScan();
      link
        ..advertise(const FoundDevice(id: 'aa', name: 'Pulsetto'))
        ..advertise(const FoundDevice(id: 'bb', name: 'Pulsetto'));
      async.elapse(const Duration(seconds: 3));
      expect(c.scanState, ScanState.several);
      expect(c.found.length, 2);
      c.pick(c.found[1]);
      async.flushMicrotasks();
      expect(settings.deviceId, 'bb');
      c.dispose();
    });
  });

  test('scan with nothing around ends as none after 10 s', () {
    fakeAsync((async) {
      settings.deviceId = null;
      final (:c, link: _, host: _) = build(async);
      c.startScan();
      async.elapse(const Duration(seconds: 9));
      expect(c.scanState, ScanState.scanning);
      async.elapse(const Duration(seconds: 1));
      expect(c.scanState, ScanState.none);
      c.dispose();
    });
  });

  test('week tracker counts days with enough sessions of 60 s or more', () {
    final monday = DateTime(2026, 10, 19, 9);
    SessionRecord rec(DateTime at, int secs) => SessionRecord(
      startedAt: at,
      plannedSeconds: 600,
      actualSeconds: secs,
      strength: 4,
      program: Program.sleep,
      side: Side.both,
      outcome: Outcome.completed,
    );
    history
      ..add(rec(monday, 600))
      ..add(rec(monday.add(const Duration(hours: 5)), 60))
      ..add(rec(monday.add(const Duration(days: 1)), 600))
      ..add(rec(monday.add(const Duration(days: 1, hours: 1)), 59));
    expect(history.week(DateTime(2026, 10, 20, 22), 2), [
      true,
      false,
      false,
      false,
      false,
      false,
      false,
    ]);
  });
}
