import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../services/settings/app_preferences_service.dart';

class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController(this._preferences)
      : super(_decode(_preferences.themeMode));

  final AppPreferencesService _preferences;

  static ThemeMode _decode(String value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setDarkMode(bool enabled) async {
    state = enabled ? ThemeMode.dark : ThemeMode.light;
    await _preferences.setThemeMode(enabled ? 'dark' : 'light');
  }

  Future<void> useSystemTheme() async {
    state = ThemeMode.system;
    await _preferences.setThemeMode('system');
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(AppPreferencesService.instance),
);
