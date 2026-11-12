import 'package:flutter/material.dart';

import '../../../../../core/theme/brand_palette.dart';

/// Fixed dark brand palette for the login screen. It does not follow the app
/// theme on purpose (documented in docs/ui_ux_revamp_plan.md).
class LoginPalette {
  const LoginPalette._();

  static const Color bgTop = BrandPalette.deepNavy;
  static const Color bgBottom = BrandPalette.brandNavy;

  static const LinearGradient background = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bgTop, bgBottom],
  );

  /// Brand panel beside the form: the same two navies, reversed.
  static const LinearGradient brandPanel = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bgBottom, bgTop],
  );

  static Color white(double alpha) => Colors.white.withValues(alpha: alpha);

  static Color get error => BrandPalette.darkError;
}

/// Text style on the dark background, sized from the theme's text roles so
/// system text scaling applies.
TextStyle loginText(
  BuildContext context,
  TextStyle? base, {
  double alpha = 1,
  FontWeight? weight,
  double? letterSpacing,
  double? height,
}) =>
    (base ?? const TextStyle()).copyWith(
      color: LoginPalette.white(alpha),
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
    );
