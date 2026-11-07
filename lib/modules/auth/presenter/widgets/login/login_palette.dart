import 'package:flutter/material.dart';

/// Fixed dark brand palette for the login screen. It does not follow the app
/// theme on purpose (documented in docs/ui_ux_revamp_plan.md).
class LoginPalette {
  const LoginPalette._();

  static const Color bgTop = Color(0xFF1a1a2e);
  static const Color bgBottom = Color(0xFF16213e);

  static const LinearGradient background = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bgTop, bgBottom],
  );

  static Color white(double alpha) => Colors.white.withValues(alpha: alpha);

  static Color get error => Colors.red[300]!;
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
