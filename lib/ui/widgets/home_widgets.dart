import 'package:flutter/material.dart';

import '../../protocol/pulsetto_protocol.dart';
import '../../session/programs.dart';
import '../../session/session_controller.dart';
import '../icons.dart';
import '../theme.dart';
import 'basics.dart';

class StatusStrip extends StatelessWidget {
  const StatusStrip({super.key, required this.c, required this.onTap});
  final SessionController c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final col = context.colors;
    final muted = TextStyle(
      fontSize: 14,
      color: col.muted,
      fontFeatures: tabular,
      height: 1.3,
    );
    final battery = c.info.battery;
    final Widget lead;
    final Widget state;
    switch (c.linkState) {
      case LinkState.connected:
        lead = const StatusDot(on: true);
        final charging = c.info.charging == true;
        final label = [
          charging ? 'Charging' : 'Connected',
          if (battery != null) '$battery%',
        ].join(' · ');
        state = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (charging) ...[
              BoltIcon(color: col.ok),
              const SizedBox(width: 4),
            ],
            Text(label, style: muted),
          ],
        );
      case LinkState.connecting:
        lead = Spinner(size: 12, color: col.fg);
        state = Text('Connecting…', style: muted);
      case LinkState.disconnected:
        lead = const StatusDot(on: false);
        state = Text('Not connected', style: muted);
    }
    return Material(
      color: col.fgSoft,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        overlayColor: WidgetStatePropertyAll(col.fgSoft),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 10, 8),
            child: Row(
              children: [
                SizedBox(width: 12, child: Center(child: lead)),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pulsetto',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                      ),
                      state,
                    ],
                  ),
                ),
                LullIcon(LullGlyph.chevron, size: 18, color: col.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum BannerTone { warn, danger, ok }

class MessageBanner extends StatelessWidget {
  const MessageBanner({
    super.key,
    required this.tone,
    required this.lead,
    required this.child,
    this.trailing,
  });
  final BannerTone tone;
  final Widget lead;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (border, bg) = switch (tone) {
      BannerTone.warn => (c.warn, c.warnBg),
      BannerTone.danger => (c.danger, c.dangerBg),
      BannerTone.ok => (c.okBorder, c.okBg),
    };
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: EdgeInsets.fromLTRB(16, 6, trailing == null ? 16 : 6, 6),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: border, width: 1.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          lead,
          const SizedBox(width: 12),
          Expanded(
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontSize: 15, height: 1.35),
              child: child,
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class NoticeBanner extends StatelessWidget {
  const NoticeBanner({super.key, required this.c});
  final SessionController c;

  @override
  Widget build(BuildContext context) {
    final col = context.colors;
    if (c.resuming) {
      return MessageBanner(
        tone: BannerTone.warn,
        lead: Spinner(color: col.warn),
        trailing: Padding(
          padding: const EdgeInsets.only(right: 10),
          child: Text(
            formatClock(c.resumeLeft),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: col.warn,
              fontFeatures: tabular,
            ),
          ),
        ),
        child: const Text('Connection lost. Resuming…'),
      );
    }
    return switch (c.notice) {
      InterruptedNotice() => MessageBanner(
        tone: BannerTone.danger,
        lead: RoundBadge.alert(color: col.danger),
        trailing: CircleIconButton(
          glyph: LullGlyph.close,
          size: 44,
          filled: false,
          tooltip: 'Dismiss',
          onTap: c.dismissNotice,
        ),
        child: const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Session interrupted.\n',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(text: 'The device didn’t reconnect in time.'),
            ],
          ),
        ),
      ),
      StartFailedNotice() => MessageBanner(
        tone: BannerTone.danger,
        lead: RoundBadge.alert(color: col.danger),
        trailing: CircleIconButton(
          glyph: LullGlyph.close,
          size: 44,
          filled: false,
          tooltip: 'Dismiss',
          onTap: c.dismissNotice,
        ),
        child: const Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Couldn’t start.\n',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              TextSpan(text: 'The device didn’t respond. Try again.'),
            ],
          ),
        ),
      ),
      DoneNotice(:final label, :final minutes) => MessageBanner(
        tone: BannerTone.ok,
        lead: RoundBadge.check(color: col.ok),
        child: Text('Done · $label · $minutes min'),
      ),
      null => const SizedBox.shrink(),
    };
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 14,
        height: 18 / 14,
        fontWeight: FontWeight.w500,
        color: context.colors.muted,
      ),
    ),
  );
}

/// Locked sections fade to 38 %. Nothing moves, so the layout under the
/// thumb never shifts.
class Lockable extends StatelessWidget {
  const Lockable({super.key, required this.locked, required this.child});
  final bool locked;
  final Widget child;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    ignoring: locked,
    child: AnimatedOpacity(
      opacity: locked ? 0.38 : 1,
      duration: context.reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 200),
      child: child,
    ),
  );
}

class ProgramGrid extends StatelessWidget {
  const ProgramGrid({super.key, required this.selected, required this.onPick});
  final Program? selected;
  final ValueChanged<Program> onPick;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rows = [
      for (var i = 0; i < Program.values.length; i += 3)
        Program.values.sublist(i, i + 3),
    ];
    return Column(
      children: [
        for (final (r, row) in rows.indexed) ...[
          if (r > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (final (i, p) in row.indexed) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _chip(c, p)),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _chip(LullColors c, Program p) {
    final on = p == selected;
    return Semantics(
      selected: on,
      button: true,
      child: Material(
        color: on ? c.surface : c.fgSoft,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: on ? c.fg : Colors.transparent, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          overlayColor: WidgetStatePropertyAll(c.fgSoft),
          onTap: () => onPick(p),
          child: SizedBox(
            height: 50,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    p.label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    softWrap: false,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    '${p.minutes} min',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.2,
                      color: on ? c.fg : c.muted,
                      fontFeatures: tabular,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class StepperRow extends StatelessWidget {
  const StepperRow({
    super.key,
    required this.label,
    required this.value,
    required this.onMinus,
    required this.onPlus,
  });
  final String label;
  final String value;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16))),
          CircleIconButton(
            glyph: LullGlyph.minus,
            size: 44,
            onTap: onMinus,
            tooltip: 'Less',
          ),
          SizedBox(
            width: 86,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                fontFeatures: tabular,
              ),
            ),
          ),
          CircleIconButton(
            glyph: LullGlyph.plus,
            size: 44,
            onTap: onPlus,
            tooltip: 'More',
          ),
        ],
      ),
    );
  }
}

/// The big number, −/+ and a slider. The slider only reports its value
/// when the drag ends; the number follows the finger meanwhile.
class IntensityControl extends StatefulWidget {
  const IntensityControl({
    super.key,
    required this.value,
    required this.onChanged,
  });
  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<IntensityControl> createState() => _IntensityControlState();
}

class _IntensityControlState extends State<IntensityControl> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shown = _drag?.round() ?? widget.value;
    return Column(
      children: [
        SizedBox(
          height: 76,
          child: Row(
            children: [
              CircleIconButton(
                glyph: LullGlyph.minus,
                size: 64,
                tooltip: 'Lower intensity',
                onTap: shown > 1 ? () => widget.onChanged(shown - 1) : null,
              ),
              Expanded(
                child: Text(
                  '$shown',
                  textAlign: TextAlign.center,
                  semanticsLabel: 'Intensity $shown',
                  style: const TextStyle(
                    fontSize: 76,
                    height: 1,
                    fontWeight: FontWeight.w400,
                    letterSpacing: -1.5,
                    fontFeatures: tabular,
                  ),
                ),
              ),
              CircleIconButton(
                glyph: LullGlyph.plus,
                size: 64,
                tooltip: 'Raise intensity',
                onTap: shown < 9 ? () => widget.onChanged(shown + 1) : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 6,
            activeTrackColor: c.fg,
            inactiveTrackColor: c.fgSoft2,
            thumbShape: _RingThumb(fill: c.surface, ring: c.fg),
            overlayShape: SliderComponentShape.noOverlay,
            trackShape: const RoundedRectSliderTrackShape(),
            tickMarkShape: SliderTickMarkShape.noTickMark,
            showValueIndicator: ShowValueIndicator.never,
            padding: const EdgeInsets.symmetric(horizontal: 14),
          ),
          child: SizedBox(
            height: 40,
            child: Slider(
              min: 1,
              max: 9,
              divisions: 8,
              value: (_drag ?? widget.value.toDouble()),
              onChanged: (v) => setState(() => _drag = v),
              onChangeEnd: (v) {
                setState(() => _drag = null);
                widget.onChanged(v.round());
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9),
          child: Row(
            children: [
              _end('1', c),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(
                      7,
                      (_) => Container(
                        width: 3,
                        height: 3,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.border,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              _end('9', c),
            ],
          ),
        ),
      ],
    );
  }

  Widget _end(String s, LullColors c) => Text(
    s,
    style: TextStyle(
      fontSize: 13,
      height: 16 / 13,
      color: c.muted,
      fontFeatures: tabular,
    ),
  );
}

class _RingThumb extends SliderComponentShape {
  const _RingThumb({required this.fill, required this.ring});
  final Color fill;
  final Color ring;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.square(28);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(
      center.translate(0, 1),
      14,
      Paint()
        ..color = const Color(0x40000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.drawCircle(center, 14, Paint()..color = fill);
    canvas.drawCircle(
      center,
      13,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }
}

class SideSelector extends StatelessWidget {
  const SideSelector({super.key, required this.value, required this.onPick});
  final Side value;
  final ValueChanged<Side> onPick;

  static const _labels = {
    Side.both: 'Both',
    Side.left: 'Left',
    Side.right: 'Right',
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 252,
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: c.fgSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final s in Side.values)
            Expanded(
              child: Semantics(
                selected: s == value,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onPick(s),
                  child: AnimatedContainer(
                    duration: context.reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 150),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: s == value ? c.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: s == value
                          ? const [
                              BoxShadow(
                                color: Color(0x2E000000),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      _labels[s]!,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: s == value
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Start, Connect, Starting…/Stopping…, and the running Stop button.
class MainDock extends StatelessWidget {
  const MainDock({
    super.key,
    required this.c,
    required this.onStart,
    required this.onConnect,
  });
  final SessionController c;
  final VoidCallback onStart;
  final VoidCallback onConnect;

  @override
  Widget build(BuildContext context) {
    switch (c.phase) {
      case SessionPhase.starting when !c.resuming:
        return _BusyButton(
          label: 'Starting…',
          duration: SessionController.startingTakes,
        );
      case SessionPhase.stopping when !c.resuming:
        return _BusyButton(
          label: 'Stopping…',
          duration: SessionController.stoppingTakes,
        );
      case SessionPhase.idle:
        if (c.linkState == LinkState.disconnected) {
          return Row(
            children: [
              Expanded(
                flex: 4,
                child: OutlineButton(label: 'Connect', onTap: onConnect),
              ),
              const SizedBox(width: 10),
              const Expanded(
                flex: 6,
                child: AccentButton(label: 'Start', onTap: null),
              ),
            ],
          );
        }
        return AccentButton(label: 'Start', onTap: c.canStart ? onStart : null);
      default:
        return _SessionButton(c: c);
    }
  }
}

class _BusyButton extends StatelessWidget {
  const _BusyButton({required this.label, required this.duration});
  final String label;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 64,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.fgSoft2,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Stack(
        children: [
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Spinner(color: c.muted),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: c.muted,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: FillBar(
              duration: duration,
              color: c.muted,
              track: Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionButton extends StatelessWidget {
  const _SessionButton({required this.c});
  final SessionController c;

  @override
  Widget build(BuildContext context) {
    final col = context.colors;
    final frozen = c.resuming;
    return Semantics(
      button: true,
      label: 'Stop, ${formatClock(c.remaining)} left',
      excludeSemantics: true,
      child: Pressable(
        onTap: c.phase == SessionPhase.stopping ? null : c.stop,
        child: Builder(
          builder: (context) {
            return Container(
              height: 80,
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 10),
              decoration: BoxDecoration(
                color: col.session,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              c.phase == SessionPhase.stopping
                                  ? 'Stopping…'
                                  : 'Stop',
                              style: TextStyle(
                                fontSize: 22,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                color: col.onAccent,
                              ),
                            ),
                            Text(
                              '${c.sessionLabel} · ${c.sessionMinutes} min',
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.2,
                                fontWeight: FontWeight.w500,
                                color: col.sessionSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Opacity(
                        opacity: frozen ? 0.42 : 1,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              formatClock(c.remaining),
                              style: TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w500,
                                letterSpacing: -0.3,
                                color: col.onAccent,
                                fontFeatures: tabular,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'left',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: col.sessionSub,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 2,
                    child: Opacity(
                      opacity: frozen ? 0.42 : 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: c.progress,
                          minHeight: 4,
                          color: col.onAccent,
                          backgroundColor: col.sessionTrack,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
