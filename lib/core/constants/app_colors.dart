// Brand color palette + a helper to build ColorScheme.
// AppTheme can reference these, but this file itself does not
// override ThemeData.

import 'package:flutter/material.dart';

class AppColors {
  // Brand / primary palette
  static const Color brandPrimary = Color(0xFF1565C0); // Voltcore blue-ish
  static const Color brandSecondary = Color(0xFFFFA726); // Accent (amber)
  static const Color brandTertiary = Color(0xFF26C6DA); // Teal/cyan accent

  // Neutrals
  static const Color neutralBlack = Color(0xFF121212);
  static const Color neutralDark = Color(0xFF1E1E1E);
  static const Color neutralGrey = Color(0xFF9E9E9E);
  static const Color neutralLight = Color(0xFFF5F5F5);
  static const Color neutralWhite = Color(0xFFFFFFFF);

  // Status / semantics
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF9A825);
  static const Color error = Color(0xFFD32F2F);
  static const Color info = Color(0xFF0288D1);

  /// Convenience: build a Material 3 ColorScheme based on brandPrimary.
  static ColorScheme colorScheme(Brightness brightness) {
    return ColorScheme.fromSeed(
      seedColor: brandPrimary,
      brightness: brightness,
    );
  }
}