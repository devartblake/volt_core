import 'package:flutter/material.dart';

class AppTheme {
  static const _seedColor = Color(0xFF1565C0); // Adjust to Voltcore brand

  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.light,
      ),
    );

    return base.copyWith(
      visualDensity: VisualDensity.standard,
      appBarTheme: base.appBarTheme.copyWith(
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      navigationRailTheme: base.navigationRailTheme.copyWith(
        backgroundColor: base.colorScheme.surface,
        elevation: 0,
      ),
      cardTheme: base.cardTheme.copyWith(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
      ),
    );

    return base.copyWith(
      visualDensity: VisualDensity.standard,
      appBarTheme: base.appBarTheme.copyWith(
        centerTitle: false,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      navigationRailTheme: base.navigationRailTheme.copyWith(
        backgroundColor: base.colorScheme.surface,
        elevation: 0,
      ),
      cardTheme: base.cardTheme.copyWith(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}