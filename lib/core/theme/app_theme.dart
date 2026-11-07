// Central place for Voltcore theme configuration.
// Uses AppColors + AppTypography + WidgetsTheme so everything stays consistent.

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import 'app_transitions.dart';
import 'status_colors.dart';
import 'widgets_theme.dart';

class AppTheme {
  static ThemeData get lightTheme {
    // Seed error (BA1A1A) is 4.1:1 on tinted chip fills; darkened to pass AA.
    final colorScheme = AppColors.colorScheme(Brightness.light)
        .copyWith(error: const Color(0xFFA51417));

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.light,
    );

    return base.copyWith(
      // Typography
      textTheme: AppTypography.textTheme(base.textTheme),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),

      // NavigationRail
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        selectedLabelTextStyle: TextStyle(
          fontFamily: AppTypography.primaryFontFamily,
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
        unselectedIconTheme:
        IconThemeData(color: colorScheme.onSurfaceVariant),
        unselectedLabelTextStyle: TextStyle(
          fontFamily: AppTypography.primaryFontFamily,
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      // Drawer
      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surface,
      ),

      // FAB
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),

      pageTransitionsTheme: AppTransitions.theme(),

      // Chips
      chipTheme: base.chipTheme.copyWith(
        labelStyle: _chipLabelStyle(colorScheme),
      ),

      // Form fields & buttons & cards
      inputDecorationTheme: WidgetsTheme.inputDecoration(colorScheme),
      elevatedButtonTheme: WidgetsTheme.elevatedButton(colorScheme),
      outlinedButtonTheme: WidgetsTheme.outlinedButton(colorScheme),
      cardTheme: WidgetsTheme.card(colorScheme),

      // Semantic status colours (success/warning/info) that ColorScheme lacks.
      extensions: const [StatusColors.light],
    );
  }

  static ThemeData get darkTheme {
    final colorScheme = AppColors.colorScheme(Brightness.dark);

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,
    );

    return base.copyWith(
      textTheme: AppTypography.textTheme(base.textTheme),

      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),

      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surface,
        selectedIconTheme: IconThemeData(color: colorScheme.primary),
        selectedLabelTextStyle: TextStyle(
          fontFamily: AppTypography.primaryFontFamily,
          fontWeight: FontWeight.w600,
          color: colorScheme.primary,
        ),
        unselectedIconTheme:
        IconThemeData(color: colorScheme.onSurfaceVariant),
        unselectedLabelTextStyle: TextStyle(
          fontFamily: AppTypography.primaryFontFamily,
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      drawerTheme: DrawerThemeData(
        backgroundColor: colorScheme.surface,
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
      ),

      pageTransitionsTheme: AppTransitions.theme(),

      chipTheme: base.chipTheme.copyWith(
        labelStyle: _chipLabelStyle(colorScheme),
      ),

      inputDecorationTheme: WidgetsTheme.inputDecoration(colorScheme),
      elevatedButtonTheme: WidgetsTheme.elevatedButton(colorScheme),
      outlinedButtonTheme: WidgetsTheme.outlinedButton(colorScheme),
      cardTheme: WidgetsTheme.card(colorScheme),

      extensions: const [StatusColors.dark],
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
