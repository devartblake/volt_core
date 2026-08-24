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

  Box<dynamic>? get _boxIfOpen =>
      Hive.isBoxOpen(_boxName) ? Hive.box<dynamic>(_boxName) : null;

  Future<Box<dynamic>> _ensureBox() async {
    final open = _boxIfOpen;
    if (open != null) return open;
    return Hive.openBox<dynamic>(_boxName);
  }

  bool get notificationsEnabled =>
      _boxIfOpen?.get(_notificationsKey, defaultValue: true) as bool? ?? true;

  bool get autoSyncEnabled =>
      _boxIfOpen?.get(_autoSyncKey, defaultValue: true) as bool? ?? true;

  String get language =>
      _boxIfOpen?.get(_languageKey, defaultValue: 'English') as String? ??
      'English';

  String get dateFormat =>
      _boxIfOpen?.get(_dateFormatKey, defaultValue: 'MM/DD/YYYY') as String? ??
      'MM/DD/YYYY';

  String get themeMode =>
      _boxIfOpen?.get(_themeModeKey, defaultValue: 'system') as String? ??
      'system';

  Future<void> setNotificationsEnabled(bool value) async {
    final box = await _ensureBox();
    await box.put(_notificationsKey, value);
  }

  Future<void> setAutoSyncEnabled(bool value) async {
    final box = await _ensureBox();
    await box.put(_autoSyncKey, value);
  }

  Future<void> setLanguage(String value) async {
    final box = await _ensureBox();
    await box.put(_languageKey, value);
  }

  Future<void> setDateFormat(String value) async {
    final box = await _ensureBox();
    await box.put(_dateFormatKey, value);
  }

  Future<void> setThemeMode(String value) async {
    final box = await _ensureBox();
    await box.put(_themeModeKey, value);
  }
}
