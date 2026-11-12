import 'package:flutter_riverpod/legacy.dart';
import '../../domain/maintenance_list_filter.dart';
import '../../infra/models/maintenance_record.dart';
import 'maintenance_providers.dart';
import '../../infra/repositories/maintenance_hive_repository.dart' as legacy;

enum MaintenanceListTab {
  active,
  archived,
  all,
}

class MaintenanceListState {
  final List<MaintenanceRecord> records;
  final bool isLoading;
  final Object? error;
  final MaintenanceListTab tab;

  const MaintenanceListState({
    this.records = const [],
    this.isLoading = false,
    this.error,
    // Everything by default. It used to be "active" with nothing able to
    // change it, which hid every completed record from the list.
    this.tab = MaintenanceListTab.all,
  });

  MaintenanceListState copyWith({
    List<MaintenanceRecord>? records,
    bool? isLoading,
    Object? error,
    MaintenanceListTab? tab,
  }) {
    return MaintenanceListState(
      records: records ?? this.records,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      tab: tab ?? this.tab,
    );
  }
}

class MaintenanceListController
    extends StateNotifier<MaintenanceListState> {
  final legacy.MaintenanceRepo _repo;

  MaintenanceListController(this._repo)
      : super(const MaintenanceListState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final all = _repo.getAll();
      state = state.copyWith(
        records: _applyFilter(all, state.tab),
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  /// Removes [record] from the list straight away (a swiped card must leave
  /// the tree in the same frame), then deletes it from storage.
  Future<void> delete(MaintenanceRecord record) async {
    state = state.copyWith(
      records: [
        for (final r in state.records)
          if (r.id != record.id) r,
      ],
    );
    try {
      await _repo.delete(record.id);
    } catch (e) {
      await load();
      rethrow;
    }
  }

  /// Undo for [delete]: puts the record back and reloads.
  Future<void> restore(MaintenanceRecord record) async {
    await _repo.restore(record);
    await load();
  }

  Future<void> refresh() {
    return load();
  }

  void changeTab(MaintenanceListTab tab) {
    final all = _repo.getAll();
    state = state.copyWith(
      tab: tab,
      records: _applyFilter(all, tab),
    );
  }

  List<MaintenanceRecord> _applyFilter(
      List<MaintenanceRecord> all,
      MaintenanceListTab tab,
      ) {
    switch (tab) {
      case MaintenanceListTab.all:
        return all;
      case MaintenanceListTab.active:
        return all.where((r) => !r.completed).toList();
      case MaintenanceListTab.archived:
        return all.where((r) => r.completed).toList();
    }
  }
}

final maintenanceListControllerProvider =
StateNotifierProvider<MaintenanceListController, MaintenanceListState>(
      (ref) {
    final repo = ref.watch(maintenanceRepoProvider);
    return MaintenanceListController(repo);
  },
);

/// Which status the maintenance list is showing.
final maintenanceStatusFilterProvider =
    StateProvider.autoDispose<MaintenanceStatusFilter>(
  (ref) => MaintenanceStatusFilter.all,
);
