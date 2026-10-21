import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Colours from the Open Design "Modern minimal" look, converted from its
/// oklch tokens and `color-mix(in oklch, …)` roles.
@immutable
class LullColors extends ThemeExtension<LullColors> {
  const LullColors({
    required this.bg,
    required this.surface,
    required this.raised,
    required this.fg,
    required this.muted,
    required this.border,
    required this.accentFill,
    required this.accentInk,
    required this.accentPressed,
    required this.onAccent,
    required this.session,
    required this.sessionSub,
    required this.sessionTrack,
    required this.ok,
    required this.warn,
    required this.danger,
    required this.okBg,
    required this.okBorder,
    required this.warnBg,
    required this.dangerBg,
    required this.dangerBorder,
    required this.chrome,
  });

  final Color bg;
  final Color surface;
  final Color raised;
  final Color fg;
  final Color muted;
  final Color border;

  /// Blue means "press this", on one button per screen.
  final Color accentFill;
  final Color accentInk;
  final Color accentPressed;
  final Color onAccent;

  /// Stop is a deeper blue than Start, so a running session reads at a glance.
  final Color session;
  final Color sessionSub;
  final Color sessionTrack;

  /// Status colours describe the link and session outcomes, never decoration.
  final Color ok;
  final Color warn;
  final Color danger;
  final Color okBg;
  final Color okBorder;
  final Color warnBg;
  final Color dangerBg;
  final Color dangerBorder;
  final Color chrome;

  Color get fgSoft => fg.withValues(alpha: 0.06);
  Color get fgSoft2 => fg.withValues(alpha: 0.11);

  static const light = LullColors(
    bg: Color(0xFFFBFCFD),
    surface: Color(0xFFFFFFFF),
    raised: Color(0xFFFFFFFF),
    fg: Color(0xFF0E1217),
    muted: Color(0xFF6A6F76),
    border: Color(0xFFE2E5E8),
    accentFill: Color(0xFF1669C1),
    accentInk: Color(0xFF1563B4),
    accentPressed: Color(0xFF15508C),
    onAccent: Color(0xFFFBFCFD),
    session: Color(0xFF155BA3),
    sessionSub: Color(0xFFCBE0F2),
    sessionTrack: Color(0xFF5895D3),
    ok: Color(0xFF007E46),
    warn: Color(0xFFA0600B),
    danger: Color(0xFFC52B30),
    okBg: Color(0xFFE8F1F6),
    okBorder: Color(0xFF95C0CC),
    warnBg: Color(0xFFE6F1F5),
    dangerBg: Color(0xFFEAF2FB),
    dangerBorder: Color(0xFFC38AC7),
    chrome: Color(0xFFF1F2F4),
  );

  /// Built for bedtime: same hues, low light, nothing pure white.
  static const dark = LullColors(
    bg: Color(0xFF090B0E),
    surface: Color(0xFF101418),
    raised: Color(0xFF191D22),
    fg: Color(0xFFE5E8EC),
    muted: Color(0xFF9CA2A9),
    border: Color(0xFF272C31),
    accentFill: Color(0xFF5E9AE7),
    accentInk: Color(0xFF5E9AE7),
    accentPressed: Color(0xFF83B1E9),
    onAccent: Color(0xFF080E16),
    session: Color(0xFF73A8E8),
    sessionSub: Color(0xFF172639),
    sessionTrack: Color(0xFF436FA5),
    ok: Color(0xFF5EC386),
    warn: Color(0xFFEBB25F),
    danger: Color(0xFFF17871),
    okBg: Color(0xFF0E161D),
    okBorder: Color(0xFF2F5C68),
    warnBg: Color(0xFF10191F),
    dangerBg: Color(0xFF0F141C),
    dangerBorder: Color(0xFF825786),
    chrome: Color(0xFF0E1114),
  );

  @override
  LullColors copyWith() => this;

  @override
  LullColors lerp(LullColors? other, double t) => t < 0.5 ? this : other!;
}

extension LullTheme on BuildContext {
  LullColors get colors => Theme.of(this).extension<LullColors>()!;
  bool get reduceMotion => MediaQuery.disableAnimationsOf(this);
}

const tabular = [FontFeature.tabularFigures()];

TextStyle monoStyle(double size, Color color) => TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: const ['RobotoMono', 'DejaVu Sans Mono'],
  fontSize: size,
  height: 1.45,
  color: color,
);

ThemeData buildTheme(Brightness brightness) {
  final c = brightness == Brightness.dark ? LullColors.dark : LullColors.light;
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.accentFill,
    onPrimary: c.onAccent,
    secondary: c.fg,
    onSecondary: c.bg,
    error: c.danger,
    onError: c.bg,
    surface: c.bg,
    onSurface: c.fg,
    onSurfaceVariant: c.muted,
    outline: c.border,
    outlineVariant: c.border,
    surfaceContainerHigh: c.raised,
    surfaceContainer: c.raised,
  );
  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    splashFactory: NoSplash.splashFactory,
    extensions: [c],
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: c.fg, displayColor: c.fg),
    dialogTheme: DialogThemeData(
      backgroundColor: c.raised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: c.raised,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.border),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.raised,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: c.bg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: c.fg,
      elevation: 0,
      systemOverlayStyle: overlayStyle(brightness, c),
    ),
  );
}

SystemUiOverlayStyle overlayStyle(Brightness b, LullColors c) =>
    (b == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark)
        .copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarContrastEnforced: false,
        );
