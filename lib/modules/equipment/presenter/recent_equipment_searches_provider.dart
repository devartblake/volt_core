import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/settings/app_preferences_service.dart';
import '../domain/recent_equipment_searches.dart';

/// Where recent equipment searches are kept. Overridden with an in-memory fake
/// in tests.
abstract class RecentEquipmentSearchStorage {
  List<String> read();
  Future<void> write(List<String> value);
}

class PreferencesRecentEquipmentSearchStorage
    implements RecentEquipmentSearchStorage {
  const PreferencesRecentEquipmentSearchStorage();

  @override
  List<String> read() => AppPreferencesService.instance.recentEquipmentSearches;

  @override
  Future<void> write(List<String> value) =>
      AppPreferencesService.instance.setRecentEquipmentSearches(value);
}

final recentEquipmentSearchStorageProvider =
    Provider<RecentEquipmentSearchStorage>(
  (ref) => const PreferencesRecentEquipmentSearchStorage(),
);

class RecentEquipmentSearchesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => ref.read(recentEquipmentSearchStorageProvider).read();

  void add(String query) {
    final next = addRecentEquipmentSearch(state, query);
    state = next;
    _save(next);
  }

  void clear() {
    state = const [];
    _save(const []);
  }

  void _save(List<String> value) {
    // Best-effort: a failed write only loses the history.
    ref
        .read(recentEquipmentSearchStorageProvider)
        .write(value)
        .catchError((_) {});
  }
}

final recentEquipmentSearchesProvider =
    NotifierProvider<RecentEquipmentSearchesNotifier, List<String>>(
  RecentEquipmentSearchesNotifier.new,
);
