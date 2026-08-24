import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Runtime theme selection for Voltcore.
///
/// The application still defaults to the host system theme. Settings may then
/// explicitly select light or dark mode for the current app session.
class ThemeModeController extends StateNotifier<ThemeMode> {
  ThemeModeController() : super(ThemeMode.system);

  void setDarkMode(bool enabled) {
    state = enabled ? ThemeMode.dark : ThemeMode.light;
  }

  void useSystemTheme() {
    state = ThemeMode.system;
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>(
  (ref) => ThemeModeController(),
);
