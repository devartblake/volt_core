import 'package:flutter_riverpod/legacy.dart';
import '../../infra/models/maintenance_record.dart';
import 'maintenance_providers.dart';
import '../../infra/repositories/maintenance_entity.dart' as legacy;

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
    this.tab = MaintenanceListTab.active,
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
