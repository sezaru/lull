import 'package:flutter/material.dart';

import '../session/session_controller.dart';
import 'app.dart';
import 'device_screen.dart';
import 'dialogs.dart';
import 'icons.dart';
import 'protocol_log_screen.dart';
import 'theme.dart';
import 'widgets/basics.dart';

const appVersion = '1.0.0';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context).controller;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final s = c.settings;
        final deviceState = !c.hasDevice
            ? 'Not set up'
            : switch (c.linkState) {
                LinkState.connected => 'Pulsetto · Connected',
                LinkState.connecting => 'Pulsetto · Connecting…',
                LinkState.disconnected => 'Pulsetto · Not connected',
              };
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
          children: [
            const SizedBox(
              height: 56,
              child: Padding(
                padding: EdgeInsets.only(left: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.24,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            _Group(
              children: [
                _Row(
                  title: 'Device',
                  sub: deviceState,
                  onTap: () => Navigator.of(context).push(DeviceScreen.route()),
                ),
                _Row(
                  title: 'LED brightness',
                  sub: s.ledMode.label,
                  onTap: () async {
                    final m = await pickLedMode(context, s.ledMode);
                    if (m != null) c.setLedMode(m);
                  },
                ),
                _Row(
                  title: 'Alert when a session ends',
                  sub: 'Sound and vibration, even on silent.',
                  onTap: () => c.setAlertOnEnd(!s.alertOnEnd),
                  trailing: _Switch(on: s.alertOnEnd),
                ),
                _Row(
                  title: 'Keep screen on during sessions',
                  sub: 'Sessions keep running with the screen off.',
                  onTap: () => c.setKeepScreenOn(!s.keepScreenOn),
                  trailing: _Switch(on: s.keepScreenOn),
                ),
                _Row(
                  title: 'Daily goal',
                  sub: 'Sessions a day',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleIconButton(
                        glyph: LullGlyph.minus,
                        size: 40,
                        tooltip: 'Fewer',
                        onTap: s.dailyGoal > 1
                            ? () => c.setDailyGoal(s.dailyGoal - 1)
                            : null,
                      ),
                      SizedBox(
                        width: 32,
                        child: Text(
                          '${s.dailyGoal}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            fontFeatures: tabular,
                          ),
                        ),
                      ),
                      CircleIconButton(
                        glyph: LullGlyph.plus,
                        size: 40,
                        tooltip: 'More',
                        onTap: s.dailyGoal < 10
                            ? () => c.setDailyGoal(s.dailyGoal + 1)
                            : null,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _Group(
              children: [
                _Row(
                  title: 'Protocol log',
                  onTap: () =>
                      Navigator.of(context).push(ProtocolLogScreen.route()),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
              child: Text(
                'About',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.muted,
                ),
              ),
            ),
            _Group(
              children: [
                _Row(
                  title: 'Version',
                  trailing: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      appVersion,
                      style: TextStyle(
                        fontSize: 15,
                        color: context.colors.muted,
                        fontFeatures: tabular,
                      ),
                    ),
                  ),
                ),
                const _Row(
                  plain: 'Protocol work by Juraj Bednar (PulseLibre, MIT)',
                ),
                _Row(
                  title: 'Open source licenses',
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: 'Lull',
                    applicationVersion: appVersion,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.border),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          for (final (i, child) in children.indexed)
            i == 0
                ? child
                : DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: c.border)),
                    ),
                    child: child,
                  ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({this.title, this.sub, this.plain, this.onTap, this.trailing});
  final String? title;
  final String? sub;
  final String? plain;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final body = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null)
                    Text(
                      title!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  if (sub != null)
                    Text(
                      sub!,
                      style: TextStyle(
                        fontSize: 14,
                        color: c.muted,
                        height: 1.35,
                      ),
                    ),
                  if (plain != null)
                    Text(
                      plain!,
                      style: const TextStyle(fontSize: 15, height: 1.35),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              LullIcon(LullGlyph.chevron, size: 18, color: c.muted),
          ],
        ),
      ),
    );
    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        overlayColor: WidgetStatePropertyAll(c.fgSoft),
        onTap: onTap,
        child: body,
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = context.reduceMotion
        ? Duration.zero
        : const Duration(milliseconds: 150);
    return Semantics(
      toggled: on,
      child: AnimatedContainer(
        duration: d,
        width: 52,
        height: 32,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: on ? c.fg : c.fgSoft2,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: on ? c.fg : c.muted, width: 2),
        ),
        child: AnimatedAlign(
          duration: d,
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: AnimatedContainer(
            duration: d,
            width: on ? 24 : 16,
            height: on ? 24 : 16,
            margin: EdgeInsets.symmetric(horizontal: on ? 2 : 6),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? c.bg : c.muted,
            ),
          ),
        ),
      ),
    );
  }
}
