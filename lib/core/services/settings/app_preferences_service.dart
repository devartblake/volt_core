import 'package:hive/hive.dart';

/// Durable user-facing application preferences stored in the existing
/// `app_settings` Hive box.
///
/// These preferences are intentionally local device preferences. They do not
/// grant permissions and do not replace tenant/server policy.
class AppPreferencesService {
  AppPreferencesService._();

  static final AppPreferencesService instance = AppPreferencesService._();

  static const _boxName = 'app_settings';
  static const _notificationsKey = 'notifications_enabled';
  static const _autoSyncKey = 'auto_sync_enabled';
  static const _languageKey = 'language';
  static const _dateFormatKey = 'date_format';
  static const _themeModeKey = 'theme_mode';

  Box<dynamic> get _box => Hive.box<dynamic>(_boxName);

  bool get notificationsEnabled =>
      _box.get(_notificationsKey, defaultValue: true) as bool;

  bool get autoSyncEnabled =>
      _box.get(_autoSyncKey, defaultValue: true) as bool;

  String get language =>
      _box.get(_languageKey, defaultValue: 'English') as String;

  String get dateFormat =>
      _box.get(_dateFormatKey, defaultValue: 'MM/DD/YYYY') as String;

  String get themeMode =>
      _box.get(_themeModeKey, defaultValue: 'system') as String;

  Future<void> setNotificationsEnabled(bool value) =>
      _box.put(_notificationsKey, value);

  Future<void> setAutoSyncEnabled(bool value) =>
      _box.put(_autoSyncKey, value);

  Future<void> setLanguage(String value) => _box.put(_languageKey, value);

  Future<void> setDateFormat(String value) => _box.put(_dateFormatKey, value);

  Future<void> setThemeMode(String value) => _box.put(_themeModeKey, value);
}
