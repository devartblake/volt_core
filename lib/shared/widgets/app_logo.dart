import 'package:flutter/material.dart';

import '../../core/theme/brand_palette.dart';

/// The Volt Core "Core Ring" logo, drawn in code (no image asset needed, so it
/// is crisp at any size from 24 to 512 px).
///
/// Uses the light variant (navy disc) on light themes and the dark variant
/// (pale disc) on dark themes, following `Theme.of(context).brightness` unless
/// [brightness] is given. Put it on a navy surface with [AppLogo.onBrand].
///
/// Geometry (512 box): disc r=224, ring r=188 stroke 12, core r=160, bolt
/// polygon scaled 0.62 about the centre. Matches assets/brand/*.svg.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 40,
    this.brightness,
    this.decorative = false,
  });

  /// The pale-disc variant, for placing on a navy / dark brand surface.
  const AppLogo.onBrand({
    super.key,
    this.size = 40,
    this.decorative = false,
  }) : brightness = Brightness.dark;

  final double size;

  /// Light = navy variant, dark = pale variant. Null follows the theme.
  final Brightness? brightness;

  /// True when the logo is purely ornamental (hidden from screen readers).
  final bool decorative;

  @override
  Widget build(BuildContext context) {
    final b = brightness ?? Theme.of(context).brightness;
    final paint = SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: AppLogoPainter(brightness: b)),
    );
    if (decorative) return ExcludeSemantics(child: paint);
    return Semantics(label: 'Volt Core logo', image: true, child: paint);
  }
}

/// Colours of one logo variant.
class AppLogoColors {
  const AppLogoColors({
    required this.disc,
    required this.ring,
    required this.core,
    required this.bolt,
  });

  final Color disc;
  final Color ring;
  final Color core;
  final Color bolt;

  static const AppLogoColors light = AppLogoColors(
    disc: BrandPalette.brandNavy,
    ring: BrandPalette.grey300,
    core: BrandPalette.white,
    bolt: BrandPalette.brandNavy,
  );

  static const AppLogoColors dark = AppLogoColors(
    disc: BrandPalette.paleNavy,
    ring: BrandPalette.grey500,
    core: BrandPalette.deepNavy,
    bolt: BrandPalette.white,
  );

  static AppLogoColors of(Brightness b) =>
      b == Brightness.dark ? dark : light;
}

class AppLogoPainter extends CustomPainter {
  const AppLogoPainter({required this.brightness});

  final Brightness brightness;

  AppLogoColors get colors => AppLogoColors.of(brightness);

  static const _bolt = <Offset>[
    Offset(292, 60),
    Offset(150, 282),
    Offset(238, 282),
    Offset(206, 452),
    Offset(364, 226),
    Offset(274, 226),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.shortestSide / 512;
    final c = Offset(size.width / 2, size.height / 2);
    final fill = Paint()..isAntiAlias = true;

    canvas.drawCircle(c, 224 * k, fill..color = colors.disc);
    canvas.drawCircle(
      c,
      188 * k,
      Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12 * k
        ..color = colors.ring,
    );
    canvas.drawCircle(c, 160 * k, fill..color = colors.core);

    final path = Path();
    for (var i = 0; i < _bolt.length; i++) {
      final p = _bolt[i];
      final x = (256 + (p.dx - 256) * 0.62) * k + (c.dx - 256 * k);
      final y = (256 + (p.dy - 256) * 0.62) * k + (c.dy - 256 * k);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, fill..color = colors.bolt);
  }

  @override
  bool shouldRepaint(AppLogoPainter old) => old.brightness != brightness;
}
