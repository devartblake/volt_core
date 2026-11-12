// Shared theming for form fields, buttons, and cards.
// Used by AppTheme to keep widget styles consistent.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_tokens.dart';
import '../constants/app_typography.dart';

class WidgetsTheme {
  static InputDecorationTheme inputDecoration(ColorScheme colors) {
    return InputDecorationTheme(
      filled: true,
      fillColor: colors.surfaceContainerHighest.withValues(alpha: 0.4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colors.primary, width: 1.4),
      ),
      contentPadding:
      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      labelStyle: TextStyle(color: colors.onSurfaceVariant),
      hintStyle: TextStyle(color: colors.onSurfaceVariant.withValues(alpha: 0.9)),
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
      surfaceTintColor: Colors.transparent,
    );
  }

  /// Navy bar with white content in light mode; the navy container with its
  /// pale-navy content in dark mode.
  static AppBarTheme appBar(ColorScheme colors) {
    final light = colors.brightness == Brightness.light;
    final bg = light ? colors.primary : colors.primaryContainer;
    final fg = light ? colors.onPrimary : colors.onPrimaryContainer;
    return AppBarTheme(
      backgroundColor: bg,
      foregroundColor: fg,
      surfaceTintColor: Colors.transparent,
      iconTheme: IconThemeData(color: fg),
      actionsIconTheme: IconThemeData(color: fg),
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    );
  }

  static NavigationRailThemeData navigationRail(ColorScheme colors) {
    return NavigationRailThemeData(
      backgroundColor: colors.surface,
      indicatorColor: colors.primaryContainer,
      selectedIconTheme: IconThemeData(
        color: colors.brightness == Brightness.light
            ? colors.primary
            : colors.onPrimaryContainer,
      ),
      selectedLabelTextStyle: TextStyle(
        fontFamily: AppTypography.primaryFontFamily,
        fontWeight: FontWeight.w600,
        color: colors.primary,
      ),
      unselectedIconTheme: IconThemeData(color: colors.onSurfaceVariant),
      unselectedLabelTextStyle: TextStyle(
        fontFamily: AppTypography.primaryFontFamily,
        color: colors.onSurfaceVariant,
      ),
    );
  }

  static NavigationBarThemeData navigationBar(ColorScheme colors) {
    return NavigationBarThemeData(
      backgroundColor: colors.surface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: colors.primaryContainer,
      iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colors.onPrimaryContainer
                : colors.onSurfaceVariant,
          )),
      labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontFamily: AppTypography.primaryFontFamily,
            fontSize: AppFontSize.caption,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
            color: states.contains(WidgetState.selected)
                ? colors.primary
                : colors.onSurfaceVariant,
          )),
    );
  }

  static TabBarThemeData tabBar(ColorScheme colors) {
    return TabBarThemeData(
      labelColor: colors.primary,
      unselectedLabelColor: colors.onSurfaceVariant,
      indicatorColor: colors.primary,
      dividerColor: colors.outlineVariant,
    );
  }

  static SnackBarThemeData snackBar(ColorScheme colors) {
    return SnackBarThemeData(
      backgroundColor: colors.inverseSurface,
      contentTextStyle: TextStyle(color: colors.onInverseSurface),
      actionTextColor: colors.inversePrimary,
    );
  }

  static DialogThemeData dialog(ColorScheme colors) {
    return DialogThemeData(
      backgroundColor: colors.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
    );
  }

  static FilledButtonThemeData filledButton(ColorScheme colors) {
    return FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colors.primary,
        foregroundColor: colors.onPrimary,
      ),
    );
  }
}
