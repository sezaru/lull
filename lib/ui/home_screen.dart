import 'dart:io';

import 'package:flutter/material.dart';

import '../session/session_controller.dart';
import 'app.dart';
import 'blocking.dart';
import 'device_screen.dart';
import 'dialogs.dart';
import 'widgets/home_widgets.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context).controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) =>
          c.gate == Gate.ready ? _Home(c: c) : BlockingView(c: c),
    );
  }
}

class _Home extends StatelessWidget {
  const _Home({required this.c});
  final SessionController c;

  void _openDevice(BuildContext context) =>
      Navigator.of(context).push(DeviceScreen.route());

  void _connect(BuildContext context) {
    if (c.hasDevice) {
      c.connect();
    } else {
      _openDevice(context);
    }
  }

  Future<void> _start(BuildContext context) async {
    final s = c.settings;
    if (Platform.isAndroid &&
        !s.notificationsAsked &&
        !await c.permissions.notificationsGranted()) {
      if (!context.mounted) return;
      final allow = await askNotifications(context);
      s.notificationsAsked = true;
      if (allow) await c.permissions.requestNotifications();
    }
    await c.start();
  }

  @override
  Widget build(BuildContext context) {
    final session = c.phase != SessionPhase.idle;
    final busy =
        c.phase == SessionPhase.starting ||
        c.phase == SessionPhase.stopping ||
        c.resuming;
    final hasBanner = c.resuming || c.notice != null;
    // The main button stays docked; only the controls above it scroll on
    // short screens.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StatusStrip(c: c, onTap: () => _openDevice(context)),
                if (hasBanner) ...[
                  const SizedBox(height: 10),
                  NoticeBanner(c: c),
                ],
                const SizedBox(height: 14),
                Lockable(
                  locked: session,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionLabel('Program'),
                      ProgramGrid(selected: c.program, onPick: c.selectProgram),
                      const SizedBox(height: 14),
                      StepperRow(
                        label: 'Timer',
                        value: '${c.minutes} min',
                        onMinus: c.minutes > 1
                            ? () => c.setMinutes(c.minutes - 1)
                            : null,
                        onPlus: c.minutes < 60
                            ? () => c.setMinutes(c.minutes + 1)
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Lockable(
                  locked: busy,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionLabel('Intensity'),
                      IntensityControl(
                        value: c.intensity,
                        onChanged: c.setIntensity,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Lockable(
                  locked: session,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 56),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text('Side', style: TextStyle(fontSize: 16)),
                        ),
                        SideSelector(value: c.side, onPick: c.setSide),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: MainDock(
            c: c,
            onStart: () => _start(context),
            onConnect: () => _connect(context),
          ),
        ),
      ],
    );
  }
}
