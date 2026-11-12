import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/settings/app_preferences_service.dart';
import '../domain/recent_searches.dart';

/// Where recent searches are kept. Overridden with an in-memory fake in tests.
abstract class RecentSearchStorage {
  List<String> read();
  Future<void> write(List<String> value);
}

class PreferencesRecentSearchStorage implements RecentSearchStorage {
  const PreferencesRecentSearchStorage();

  @override
  List<String> read() => AppPreferencesService.instance.recentSearches;

  @override
  Future<void> write(List<String> value) =>
      AppPreferencesService.instance.setRecentSearches(value);
}

final recentSearchStorageProvider = Provider<RecentSearchStorage>(
  (ref) => const PreferencesRecentSearchStorage(),
);

class RecentSearchesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => ref.read(recentSearchStorageProvider).read();

  void add(String query) {
    final next = addRecentSearch(state, query);
    state = next;
    _save(next);
  }

  void clear() {
    state = const [];
    _save(const []);
  }

  void _save(List<String> value) {
    // Best-effort: a failed write only loses the history.
    ref.read(recentSearchStorageProvider).write(value).catchError((_) {});
  }
}

final recentSearchesProvider =
    NotifierProvider<RecentSearchesNotifier, List<String>>(
  RecentSearchesNotifier.new,
);
