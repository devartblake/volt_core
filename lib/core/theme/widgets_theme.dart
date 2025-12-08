// Shared theming for form fields, buttons, and cards.
// Used by AppTheme to keep widget styles consistent.

import 'package:flutter/material.dart';

class WidgetsTheme {
  static InputDecorationTheme inputDecoration(ColorScheme colors) {
    return InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceVariant.withOpacity(0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.primary, width: 1.4),
      ),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      labelStyle: TextStyle(color: colors.onSurfaceVariant),
      hintStyle: TextStyle(color: colors.onSurfaceVariant.withOpacity(0.7)),
    );
  }

  static ElevatedButtonThemeData elevatedButton(ColorScheme colors) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  static OutlinedButtonThemeData outlinedButton(ColorScheme colors) {
    return OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: BorderSide(color: colors.outline),
      ),
    );
  }

  static CardThemeData card(ColorScheme colors) {
    return CardThemeData(
      elevation: 1,
      margin: const EdgeInsets.all(8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: colors.surface,
    );
  }
}
