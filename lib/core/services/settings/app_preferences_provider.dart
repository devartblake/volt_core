import 'package:flutter_riverpod/legacy.dart';

import '../notifications/notification_service.dart';
import '../sync/sync_service.dart';
import 'app_preferences_service.dart';

class AppPreferences {
  const AppPreferences({
    required this.notificationsEnabled,
    required this.autoSyncEnabled,
    required this.language,
    required this.dateFormat,
  });

  final bool notificationsEnabled;
  final bool autoSyncEnabled;
  final String language;
  final String dateFormat;

  AppPreferences copyWith({
    bool? notificationsEnabled,
    bool? autoSyncEnabled,
    String? language,
    String? dateFormat,
  }) {
    return AppPreferences(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      language: language ?? this.language,
      dateFormat: dateFormat ?? this.dateFormat,
    );
  }
}

class AppPreferencesController extends StateNotifier<AppPreferences> {
  AppPreferencesController(this._service)
      : super(
          AppPreferences(
            notificationsEnabled: _service.notificationsEnabled,
            autoSyncEnabled: _service.autoSyncEnabled,
            language: _service.language,
            dateFormat: _service.dateFormat,
          ),
        );

  final AppPreferencesService _service;

  Future<void> setNotificationsEnabled(bool value) async {
    state = state.copyWith(notificationsEnabled: value);
    await _service.setNotificationsEnabled(value);
    if (!value) {
      await NotificationService.instance.cancelAllTaskReminders();
    }
  }

  Future<void> setAutoSyncEnabled(bool value) async {
    state = state.copyWith(autoSyncEnabled: value);
    await _service.setAutoSyncEnabled(value);
    if (value) {
      await SyncService.instance.sync();
    }
  }

  Future<void> setLanguage(String value) async {
    state = state.copyWith(language: value);
    await _service.setLanguage(value);
  }

  Future<void> setDateFormat(String value) async {
    state = state.copyWith(dateFormat: value);
    await _service.setDateFormat(value);
  }
}

final appPreferencesProvider =
    StateNotifierProvider<AppPreferencesController, AppPreferences>((ref) {
  return AppPreferencesController(AppPreferencesService.instance);
});
