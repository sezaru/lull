import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../icons.dart';
import '../theme.dart';

/// Answers a press before the device does: scale 0.985 for 80 ms.
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, required this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap != null && v != _down) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? 0.985 : 1,
        duration: context.reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 80),
        child: _PressedScope(pressed: _down, child: widget.child),
      ),
    );
  }
}

class _PressedScope extends InheritedWidget {
  const _PressedScope({required this.pressed, required super.child});
  final bool pressed;
  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_PressedScope>()?.pressed ??
      false;
  @override
  bool updateShouldNotify(_PressedScope old) => old.pressed != pressed;
}

/// The one blue button on a screen.
class AccentButton extends StatelessWidget {
  const AccentButton({
    super.key,
    required this.label,
    required this.onTap,
    this.height = 64,
  });
  final String label;
  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      child: Builder(
        builder: (context) {
          final pressed = _PressedScope.of(context);
          final enabled = onTap != null;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: !enabled
                  ? c.fgSoft2
                  : pressed
                  ? c.accentPressed
                  : c.accentFill,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: enabled ? c.onAccent : c.muted,
              ),
            ),
          );
        },
      ),
    );
  }
}

class OutlineButton extends StatelessWidget {
  const OutlineButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 64,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: c.fg, width: 1.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Destructive actions are red text or outlines, never a filled red button.
class DangerButton extends StatelessWidget {
  const DangerButton({super.key, required this.label, required this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Opacity(
      opacity: onTap == null ? 0.4 : 1,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: c.dangerBorder, width: 1.5),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          overlayColor: WidgetStatePropertyAll(
            c.danger.withValues(alpha: 0.09),
          ),
          onTap: onTap,
          child: SizedBox(
            height: 56,
            width: double.infinity,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: c.danger,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class TextAction extends StatelessWidget {
  const TextAction({
    super.key,
    required this.label,
    required this.onTap,
    this.color,
    this.icon,
  });
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final LullGlyph? icon;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? context.colors.fg;
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: fg,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            LullIcon(icon!, size: 18, color: fg),
            const SizedBox(width: 8),
          ],
          Text(label),
        ],
      ),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.glyph,
    required this.onTap,
    this.size = 48,
    this.tooltip,
    this.filled = true,
  });
  final LullGlyph glyph;
  final VoidCallback? onTap;
  final double size;
  final String? tooltip;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final button = Opacity(
      opacity: onTap == null ? 0.35 : 1,
      child: Material(
        color: filled ? c.fgSoft : Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          overlayColor: WidgetStatePropertyAll(c.fgSoft),
          onTap: onTap,
          child: SizedBox.square(
            dimension: size,
            child: Center(child: LullIcon(glyph, color: c.fg)),
          ),
        ),
      ),
    );
    return tooltip == null
        ? button
        : Semantics(label: tooltip, button: true, child: button);
  }
}

/// A ring with a quarter missing, turning every 0.9 s.
class Spinner extends StatefulWidget {
  const Spinner({super.key, this.size = 18, this.color});
  final double size;
  final Color? color;

  @override
  State<Spinner> createState() => _SpinnerState();
}

class _SpinnerState extends State<Spinner> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _c
      ..duration = Duration(milliseconds: context.reduceMotion ? 2400 : 900)
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? DefaultTextStyle.of(context).style.color!;
    return RotationTransition(
      turns: _c,
      child: CustomPaint(
        size: Size.square(widget.size),
        painter: _ArcPainter(color, widget.size < 14 ? 1.6 : 2),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.color, this.width);
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(width / 2);
    canvas.drawArc(
      rect,
      -math.pi / 4,
      math.pi * 1.5,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = width,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.color != color || old.width != width;
}

class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? c.ok : Colors.transparent,
        border: on ? null : Border.all(color: c.muted, width: 2),
      ),
    );
  }
}

/// A round mark inside banners: `!` or a check.
class RoundBadge extends StatelessWidget {
  const RoundBadge.alert({super.key, required this.color}) : check = false;
  const RoundBadge.check({super.key, required this.color}) : check = true;
  final Color color;
  final bool check;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      alignment: Alignment.center,
      child: check
          ? LullIcon(LullGlyph.check, size: 16, color: color, strokeWidth: 2)
          : Text(
              '!',
              style: TextStyle(
                fontSize: 14,
                height: 1,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
    );
  }
}

/// A grey disc holding an icon, above a centred message.
class Glyph extends StatelessWidget {
  const Glyph(this.glyph, {super.key, this.size = 88, this.pulse = false});
  final LullGlyph glyph;
  final double size;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final disc = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c.fgSoft),
      alignment: Alignment.center,
      child: LullIcon(
        glyph,
        size: size >= 88 ? 40 : 24,
        color: c.fg,
        strokeWidth: size >= 88 ? 1.6 : 1.8,
      ),
    );
    if (!pulse || context.reduceMotion) return disc;
    return _PulseRing(size: size, color: c.fg, child: disc);
  }
}

class _PulseRing extends StatefulWidget {
  const _PulseRing({
    required this.size,
    required this.color,
    required this.child,
  });
  final double size;
  final Color color;
  final Widget child;

  @override
  State<_PulseRing> createState() => _PulseRingState();
}

class _PulseRingState extends State<_PulseRing>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          widget.child,
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = Curves.easeOut.transform(_c.value);
              return Transform.scale(
                scale: 1 + 0.6 * t,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: widget.color.withValues(alpha: 0.35 * (1 - t)),
                      width: 2,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// A bar that fills over [duration], once.
class FillBar extends StatelessWidget {
  const FillBar({
    super.key,
    required this.duration,
    required this.color,
    required this.track,
    this.height = 4,
  });
  final Duration duration;
  final Color color;
  final Color track;
  final double height;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration,
      builder: (context, v, _) => ClipRRect(
        borderRadius: BorderRadius.circular(height / 2),
        child: Stack(
          children: [
            Container(height: height, color: track),
            FractionallySizedBox(
              widthFactor: v,
              child: Container(height: height, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Centred icon, title and line of text, with an optional action at the
/// bottom. Used by Device and the blocking states.
class CenteredState extends StatelessWidget {
  const CenteredState({
    super.key,
    required this.glyph,
    this.title,
    this.say,
    this.body,
    this.pulse = false,
    this.extra,
    this.action,
  });
  final LullGlyph glyph;
  final String? title;
  final String? say;
  final String? body;
  final bool pulse;
  final Widget? extra;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Glyph(glyph, pulse: pulse),
                  const SizedBox(height: 28),
                  if (title != null)
                    Text(
                      title!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.24,
                      ),
                    ),
                  if (say != null)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Text(
                        say!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  if (body != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Text(
                          body!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.5,
                            color: c.muted,
                          ),
                        ),
                      ),
                    ),
                  ?extra,
                ],
              ),
            ),
          ),
          if (action != null)
            Padding(padding: const EdgeInsets.only(top: 16), child: action),
        ],
      ),
    );
  }
}
