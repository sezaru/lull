import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lull/ble/pulsetto_link.dart';
import 'package:lull/platform/permissions.dart';
import 'package:lull/protocol/protocol_log.dart';
import 'package:lull/protocol/pulsetto_protocol.dart';
import 'package:lull/session/programs.dart';
import 'package:lull/session/session_controller.dart';
import 'package:lull/storage/history_store.dart';
import 'package:lull/storage/settings_store.dart';
import 'package:lull/ui/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

class _OffLink extends FakeLink {
  @override
  Future<Availability> currentAvailability() async => Availability.off;
}

class _NoPermission extends GrantedPermissions {
  @override
  Future<PermissionState> bluetooth() async => PermissionState.needed;
}

void main() {
  late SettingsStore settings;
  late HistoryStore history;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'deviceId': 'c4:7f:51:0e:3f:a1',
      'program': 'sleep',
      'minutes': 10,
      'intensity': 4,
    });
    final prefs = await SharedPreferences.getInstance();
    settings = SettingsStore(prefs);
    history = HistoryStore(prefs);
  });

  Future<(SessionController, FakeLink)> pumpApp(
    WidgetTester tester, {
    FakeLink? link,
    Permissions? permissions,
  }) async {
    tester.view.physicalSize = const Size(412, 915) * 2.625;
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final l = link ?? FakeLink();
    final c = SessionController(
      link: l,
      settings: settings,
      history: history,
      log: ProtocolLog(),
      host: FakeHost(),
      permissions: permissions ?? FakePermissions(),
    );
    await c.init();
    await tester.pumpWidget(
      LullApp(controller: c, history: history, log: ProtocolLog()),
    );
    await tester.pump();
    return (c, l);
  }

  /// Unmount first: the tree still listens to the controller.
  Future<void> end(WidgetTester tester, SessionController c) async {
    await tester.pumpWidget(const SizedBox());
    c.dispose();
  }

  testWidgets('idle and connected: Start is enabled', (tester) async {
    final (c, link) = await pumpApp(tester);
    link.reply('Batt:3.83\n');
    await tester.pump();
    expect(find.text('Connected · 83%'), findsOneWidget);
    expect(find.text('Start'), findsOneWidget);
    expect(find.text('Connect'), findsNothing);
    expect(find.text('Sleep'), findsOneWidget);
    expect(find.text('10 min'), findsWidgets);
    await end(tester, c);
  });

  testWidgets('Start runs the session; Stop shows the time left', (
    tester,
  ) async {
    final (c, _) = await pumpApp(tester);
    await tester.tap(find.text('Start'));
    await tester.pump();
    expect(find.text('Starting…'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(c.phase, SessionPhase.running);
    expect(find.text('Stop'), findsOneWidget);
    expect(find.text('Sleep · 10 min'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining(RegExp(r'^9:5\d$')), findsOneWidget);
    await tester.tap(find.text('Stop'));
    await tester.pump(const Duration(seconds: 2));
    expect(c.phase, SessionPhase.idle);
    expect(history.records.single.outcome, Outcome.stopped);
    await end(tester, c);
  });

  testWidgets('disconnected: Connect is offered, Start disabled', (
    tester,
  ) async {
    final link = FakeLink()..connectSucceeds = false;
    final (c, _) = await pumpApp(tester, link: link);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Not connected'), findsOneWidget);
    expect(find.text('Connect'), findsOneWidget);
    await end(tester, c);
  });

  testWidgets('picking a program sets the timer', (tester) async {
    final (c, _) = await pumpApp(tester);
    await tester.tap(find.text('Pain'));
    await tester.pump();
    expect(c.program, Program.pain);
    expect(find.text('20 min'), findsWidgets);
    await tester.tap(find.bySemanticsLabel('More').first);
    await tester.pump();
    expect(c.program, isNull);
    expect(c.minutes, 21);
    await end(tester, c);
  });

  testWidgets('Bluetooth off replaces Home', (tester) async {
    final (c, _) = await pumpApp(tester, link: _OffLink());
    expect(find.text('Bluetooth is off'), findsOneWidget);
    expect(find.text('Turn on Bluetooth'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    await end(tester, c);
  });

  testWidgets('missing permission asks for Nearby devices, never location', (
    tester,
  ) async {
    final (c, _) = await pumpApp(tester, permissions: _NoPermission());
    expect(find.textContaining('Nearby devices permission'), findsOneWidget);
    expect(find.text('Allow'), findsOneWidget);
    expect(find.textContaining('ocation'), findsNothing);
    await end(tester, c);
  });

  testWidgets('History lists sessions with their outcomes', (tester) async {
    final now = DateTime.now();
    history
      ..add(
        SessionRecord(
          startedAt: now.subtract(const Duration(minutes: 30)),
          plannedSeconds: 600,
          actualSeconds: 600,
          strength: 4,
          program: Program.sleep,
          side: Side.both,
          outcome: Outcome.completed,
        ),
      )
      ..add(
        SessionRecord(
          startedAt: now.subtract(const Duration(days: 1)),
          plannedSeconds: 600,
          actualSeconds: 372,
          strength: 3,
          program: null,
          side: Side.left,
          outcome: Outcome.stopped,
        ),
      );
    final (c, _) = await pumpApp(tester);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Yesterday'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Stopped at 6:12'), findsOneWidget);
    expect(find.text('6 of 10 min · Intensity 3 · Left side'), findsOneWidget);
    expect(find.text('Custom'), findsOneWidget);
    await end(tester, c);
  });

  testWidgets('History is empty at first', (tester) async {
    final (c, _) = await pumpApp(tester);
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('No sessions yet.'), findsOneWidget);
    expect(find.text('0 of 7 days this week'), findsOneWidget);
    await end(tester, c);
  });

  testWidgets('Settings shows defaults', (tester) async {
    final (c, _) = await pumpApp(tester);
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Pulsetto · Connected'), findsOneWidget);
    expect(find.text('Auto (per program)'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(
      find.text('Protocol work by Juraj Bednar (PulseLibre, MIT)'),
      findsOneWidget,
    );
    await end(tester, c);
  });
}
