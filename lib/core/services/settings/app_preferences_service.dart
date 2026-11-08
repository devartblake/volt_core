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
  static const _navStyleKey = 'nav_style';
  static const _recentSearchesKey = 'recent_searches';
  static const _recentEquipmentSearchesKey = 'recent_equipment_searches';
  static const _advancedLoggingKey = 'advanced_logging_enabled';
  static const _lastSyncedAtKey = 'last_synced_at';
  static const _inspectionFilterPresetsKey = 'inspection_filter_presets';
  static const _inspectionDensityKey = 'inspection_list_density';
  static const _readinessDueSoonKey = 'readiness_due_soon_days';
  static const _readinessCriticalKey = 'readiness_critical_overdue_days';

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

  bool get advancedLoggingEnabled =>
      _boxIfOpen?.get(_advancedLoggingKey, defaultValue: false) as bool? ?? false;

  String get language =>
      _boxIfOpen?.get(_languageKey, defaultValue: 'English') as String? ??
      'English';

  String get dateFormat =>
      _boxIfOpen?.get(_dateFormatKey, defaultValue: 'MM/DD/YYYY') as String? ??
      'MM/DD/YYYY';

  String get themeMode =>
      _boxIfOpen?.get(_themeModeKey, defaultValue: 'system') as String? ??
      'system';

  /// `rail` (default) or `bottom`: where tablet navigation sits.
  String get navStyle =>
      _boxIfOpen?.get(_navStyleKey, defaultValue: 'rail') as String? ?? 'rail';

  /// Recent global-search queries, newest first.
  List<String> get recentSearches {
    final raw = _boxIfOpen?.get(_recentSearchesKey);
    return raw is List ? raw.whereType<String>().toList() : const [];
  }

  Future<void> setRecentSearches(List<String> value) async {
    final box = await _ensureBox();
    await box.put(_recentSearchesKey, value);
  }

  /// Recent equipment-search queries, newest first. Separate from
  /// [recentSearches] so the two lists don't mix.
  List<String> get recentEquipmentSearches {
    final raw = _boxIfOpen?.get(_recentEquipmentSearchesKey);
    return raw is List ? raw.whereType<String>().toList() : const [];
  }

  Future<void> setRecentEquipmentSearches(List<String> value) async {
    final box = await _ensureBox();
    await box.put(_recentEquipmentSearchesKey, value);
  }

  /// Saved inspection-list filter presets, as a JSON list string (see
  /// InspectionFilterPresetCodec).
  String get inspectionFilterPresetsJson {
    final raw = _boxIfOpen?.get(_inspectionFilterPresetsKey);
    return raw is String ? raw : '';
  }

  Future<void> setInspectionFilterPresetsJson(String value) async {
    final box = await _ensureBox();
    await box.put(_inspectionFilterPresetsKey, value);
  }

  /// `comfortable` (default) or `compact` rows on the inspections list.
  String get inspectionListDensity =>
      _boxIfOpen?.get(_inspectionDensityKey, defaultValue: 'comfortable')
          as String? ??
      'comfortable';

  Future<void> setInspectionListDensity(String value) async {
    final box = await _ensureBox();
    await box.put(_inspectionDensityKey, value);
  }

  /// Fleet readiness: a generator due within this many days is "due soon".
  /// Default 30. Only an admin should change it (the screen enforces that).
  int get readinessDueSoonDays {
    final raw = _boxIfOpen?.get(_readinessDueSoonKey);
    return raw is int && raw >= 0 ? raw : 30;
  }

  Future<void> setReadinessDueSoonDays(int value) async {
    final box = await _ensureBox();
    await box.put(_readinessDueSoonKey, value);
  }

  /// Fleet readiness: overdue by more than this many days is "not ready"
  /// (up to it is "needs attention"). Default 30.
  int get readinessCriticalOverdueDays {
    final raw = _boxIfOpen?.get(_readinessCriticalKey);
    return raw is int && raw >= 0 ? raw : 30;
  }

  Future<void> setReadinessCriticalOverdueDays(int value) async {
    final box = await _ensureBox();
    await box.put(_readinessCriticalKey, value);
  }

  /// Time of the last sync run that finished with no failures.
  DateTime? get lastSyncedAt {
    final raw = _boxIfOpen?.get(_lastSyncedAtKey);
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  Future<void> setLastSyncedAt(DateTime value) async {
    final box = await _ensureBox();
    await box.put(_lastSyncedAtKey, value.toUtc().toIso8601String());
  }

  Future<void> setNavStyle(String value) async {
    final box = await _ensureBox();
    await box.put(_navStyleKey, value);
  }

  Future<void> setNotificationsEnabled(bool value) async {
    final box = await _ensureBox();
    await box.put(_notificationsKey, value);
  }

  Future<void> setAutoSyncEnabled(bool value) async {
    final box = await _ensureBox();
    await box.put(_autoSyncKey, value);
  }

  Future<void> setAdvancedLoggingEnabled(bool value) async {
    final box = await _ensureBox();
    await box.put(_advancedLoggingKey, value);
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
