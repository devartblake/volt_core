// Central place for Voltcore theme configuration.
// Uses AppColors + AppTypography + WidgetsTheme so everything stays consistent.

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import '../constants/app_typography.dart';
import 'widgets_theme.dart';

class AppTheme {
  static ThemeData get lightTheme {
    final colorScheme = AppColors.colorScheme(Brightness.light);

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

      // Chips
      chipTheme: base.chipTheme.copyWith(
        labelStyle: AppTypography.chipLabel,
      ),

      // Form fields & buttons & cards
      inputDecorationTheme: WidgetsTheme.inputDecoration(colorScheme),
      elevatedButtonTheme: WidgetsTheme.elevatedButton(colorScheme),
      outlinedButtonTheme: WidgetsTheme.outlinedButton(colorScheme),
      cardTheme: WidgetsTheme.card(colorScheme),
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

      chipTheme: base.chipTheme.copyWith(
        labelStyle: AppTypography.chipLabel,
      ),

      inputDecorationTheme: WidgetsTheme.inputDecoration(colorScheme),
      elevatedButtonTheme: WidgetsTheme.elevatedButton(colorScheme),
      outlinedButtonTheme: WidgetsTheme.outlinedButton(colorScheme),
      cardTheme: WidgetsTheme.card(colorScheme),
    );
  }
}