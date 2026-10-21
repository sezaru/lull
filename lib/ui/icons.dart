import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Stroke icons drawn on a 24 grid, copied from the mockup's icon set.
enum LullGlyph {
  minus('<path d="M6 12h12"/>'),
  plus('<path d="M6 12h12M12 6v12"/>'),
  chevron('<path d="m9 6 6 6-6 6"/>'),
  close('<path d="M6 6l12 12M18 6 6 18"/>'),
  back('<path d="M19 12H5M11 6l-6 6 6 6"/>'),
  more(
    '<circle cx="12" cy="5.5" r="1.5" fill="currentColor" stroke="none"/><circle cx="12" cy="12" r="1.5" fill="currentColor" stroke="none"/><circle cx="12" cy="18.5" r="1.5" fill="currentColor" stroke="none"/>',
  ),
  share(
    '<circle cx="18" cy="5" r="2.5"/><circle cx="6" cy="12" r="2.5"/><circle cx="18" cy="19" r="2.5"/><path d="m8.2 10.8 7.6-4.4M8.2 13.2l7.6 4.4"/>',
  ),
  check('<path d="m5 12.5 4.5 4.5L19 7.5"/>'),
  home('<path d="M4 11 12 4l8 7v9h-5v-6H9v6H4z"/>'),
  history('<circle cx="12" cy="12" r="8.5"/><path d="M12 7.5V12l3 2"/>'),
  settings(
    '<circle cx="12" cy="12" r="3"/><path d="M12 3v2.2M12 18.8V21M3 12h2.2M18.8 12H21M5.6 5.6l1.6 1.6M16.8 16.8l1.6 1.6M5.6 18.4l1.6-1.6M16.8 7.2l1.6-1.6"/><circle cx="12" cy="12" r="6.6"/>',
  ),
  bluetoothOff(
    '<path d="m7 7 10 10-5 5V2l5 5L7 17"/><path d="M3.5 3.5l17 17"/>',
  ),
  nearby(
    '<circle cx="12" cy="12" r="2"/><path d="M7.8 7.8a6 6 0 0 0 0 8.4M16.2 7.8a6 6 0 0 1 0 8.4M5 5a10 10 0 0 0 0 14M19 5a10 10 0 0 1 0 14"/>',
  ),
  bell(
    '<path d="M6 16v-5a6 6 0 0 1 12 0v5l1.5 2h-15z"/><path d="M10 20.5a2 2 0 0 0 4 0"/>',
  ),
  device(
    '<path d="M5 6v4a7 7 0 0 0 14 0V6"/><rect x="3" y="3" width="4" height="4" rx="1.2"/><rect x="17" y="3" width="4" height="4" rx="1.2"/>',
  );

  const LullGlyph(this.body);
  final String body;
}

class LullIcon extends StatelessWidget {
  const LullIcon(
    this.glyph, {
    super.key,
    this.size = 24,
    this.color,
    this.strokeWidth = 1.8,
  });

  final LullGlyph glyph;
  final double size;
  final Color? color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    final c = color ?? IconTheme.of(context).color ?? Colors.black;
    final hex = (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    final body = glyph.body.replaceAll('currentColor', '#$hex');
    final svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" '
        'fill="none" stroke="#$hex" stroke-width="$strokeWidth" '
        'stroke-linecap="round" stroke-linejoin="round">$body</svg>';
    return Opacity(
      opacity: c.a,
      child: SvgPicture.string(svg, width: size, height: size),
    );
  }
}

/// The bolt shown before "Charging".
class BoltIcon extends StatelessWidget {
  const BoltIcon({super.key, required this.color, this.size = 14});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hex = (color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
      '<path fill="#$hex" d="M13 2 4 14h7l-1 8 9-12h-7z"/></svg>',
      width: size,
      height: size,
    );
  }
}

/// Signal bars for a found device: [bars] of 4 filled.
class SignalBars extends StatelessWidget {
  const SignalBars({
    super.key,
    required this.bars,
    required this.on,
    required this.off,
  });
  final int bars;
  final Color on;
  final Color off;

  @override
  Widget build(BuildContext context) {
    String hex(Color c) =>
        '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    const rects = [
      'M1 11h2V8H1z',
      'M5 11h2V6H5z',
      'M9 11h2V3H9z',
      'M13 11h1V1h-1z',
    ];
    final paths = [
      for (var i = 0; i < 4; i++)
        '<path fill="${hex(i < bars ? on : off)}" d="${rects[i]}"/>',
    ].join();
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 15 12">$paths</svg>',
      width: 15,
      height: 12,
    );
  }
}
