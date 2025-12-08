import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../domain/entities/admin_dashboard_stats_entity.dart';
import '../../domain/usecases/load_admin_dashboard_stats_usecase.dart';
import '../../infra/repositories/admin_repository.dart';
import '../../infra/repositories/admin_repository_impl.dart';
import '../../external/datasources/admin_remote_datasource.dart';

/// UI-facing state for the Admin Dashboard.
@immutable
class AdminDashboardState {
  final bool isLoading;
  final AdminDashboardStatsEntity? stats;
  final String? errorMessage;

  const AdminDashboardState({
    required this.isLoading,
    this.stats,
    this.errorMessage,
  });

  const AdminDashboardState.initial()
      : isLoading = false,
        stats = null,
        errorMessage = null;

  AdminDashboardState copyWith({
    bool? isLoading,
    AdminDashboardStatsEntity? stats,
    String? errorMessage,
  }) {
    return AdminDashboardState(
      isLoading: isLoading ?? this.isLoading,
      stats: stats ?? this.stats,
      errorMessage: errorMessage,
    );
  }
}

/// Controller that loads and exposes admin dashboard stats.
class AdminDashboardController extends StateNotifier<AdminDashboardState> {
  AdminDashboardController(this._loadStatsUsecase)
      : super(const AdminDashboardState.initial());

  final LoadAdminDashboardStatsUsecase _loadStatsUsecase;

  Future<void> loadDashboardStats() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final stats = await _loadStatsUsecase();
      state = state.copyWith(isLoading: false, stats: stats);
      debugPrint('[AdminDashboardController] Loaded stats: $stats');
    } catch (e, st) {
      debugPrint('[AdminDashboardController] Error: $e\n$st');
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load stats.',
      );
    }
  }
}

/// Provider wiring up repository → usecase → controller.
///
/// For now we construct the repository & datasource inline. Later you
/// can move these to app-level DI providers if you want.
final adminDashboardControllerProvider =
StateNotifierProvider<AdminDashboardController, AdminDashboardState>((ref) {
  final remote = AdminRemoteDatasource();
  final AdminRepository repo = AdminRepositoryImpl(remote);
  final usecase = LoadAdminDashboardStatsUsecase(repo);

  final controller = AdminDashboardController(usecase);
  // Kick off initial load:
  controller.loadDashboardStats();
  return controller;
});
