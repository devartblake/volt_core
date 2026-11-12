// Central place for Voltcore theme configuration.
// Uses AppColors + AppTypography + WidgetsTheme so everything stays consistent.

import 'package:flutter/material.dart';

import '../constants/app_typography.dart';
import 'app_transitions.dart';
import 'brand_palette.dart';
import 'status_colors.dart';
import 'widgets_theme.dart';

class AppTheme {
  static ThemeData get lightTheme =>
      _build(BrandPalette.lightScheme, Brightness.light, StatusColors.light);

  static ThemeData get darkTheme =>
      _build(BrandPalette.darkScheme, Brightness.dark, StatusColors.dark);

  static ThemeData _build(
    ColorScheme colorScheme,
    Brightness brightness,
    StatusColors status,
  ) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
    );

    return base.copyWith(
      scaffoldBackgroundColor: brightness == Brightness.light
          ? BrandPalette.lightBackground
          : BrandPalette.darkBackground,
      canvasColor: colorScheme.surface,
      textTheme: AppTypography.textTheme(base.textTheme),

      appBarTheme: WidgetsTheme.appBar(colorScheme),
      navigationRailTheme: WidgetsTheme.navigationRail(colorScheme),
      navigationBarTheme: WidgetsTheme.navigationBar(colorScheme),
      tabBarTheme: WidgetsTheme.tabBar(colorScheme),
      snackBarTheme: WidgetsTheme.snackBar(colorScheme),
      dialogTheme: WidgetsTheme.dialog(colorScheme),
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),

      pageTransitionsTheme: AppTransitions.theme(),

      chipTheme: base.chipTheme.copyWith(
        labelStyle: _chipLabelStyle(colorScheme),
        selectedColor: colorScheme.secondaryContainer,
        checkmarkColor: colorScheme.onSecondaryContainer,
        side: BorderSide(color: colorScheme.outlineVariant),
      ),

      inputDecorationTheme: WidgetsTheme.inputDecoration(colorScheme),
      elevatedButtonTheme: WidgetsTheme.elevatedButton(colorScheme),
      filledButtonTheme: WidgetsTheme.filledButton(colorScheme),
      outlinedButtonTheme: WidgetsTheme.outlinedButton(colorScheme),
      cardTheme: WidgetsTheme.card(colorScheme),

      // Semantic status colours (success/warning/info) that ColorScheme lacks.
      extensions: [status],
    );
  }

  /// Chip label with an explicit colour per state. The bare
  /// [AppTypography.chipLabel] carried no colour, which left filter and
  /// action chips with near-invisible text (and washed out the selected one).
  static TextStyle _chipLabelStyle(ColorScheme colors) {
    // The state-dependent part must be the *colour* (a WidgetStateColor): chips
    // read the colour out of the style, so a state-dependent style whose own
    // colour is null is ignored and the label ends up unreadable.
    return AppTypography.chipLabel.copyWith(
      color: WidgetStateColor.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colors.onSurface.withValues(alpha: 0.38);
        }
        if (states.contains(WidgetState.selected)) {
          return colors.onSecondaryContainer;
        }
        return colors.onSurface;
      }),
    );
  }
}
