// Typography helpers + text theme customization.
// You can use these directly in widgets OR plug them into AppTheme.

import 'package:flutter/material.dart';

class AppTypography {
  static const String primaryFontFamily = 'Roboto'; // change if needed
  static const String? secondaryFontFamily = null;

  /// Build a customized TextTheme from a base theme.
  static TextTheme textTheme(TextTheme base) {
    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontFamily: primaryFontFamily,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontFamily: primaryFontFamily,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontFamily: primaryFontFamily,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontFamily: primaryFontFamily,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontFamily: primaryFontFamily,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontFamily: primaryFontFamily,
        letterSpacing: 0.1,
      ),
    );
  }

  // Some commonly reused styles (for quick imports)
  static const TextStyle dashboardTitle = TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle sectionHeader = TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  );

  static const TextStyle chipLabel = TextStyle(
    fontFamily: primaryFontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
  );
}
