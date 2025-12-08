import '../entities/admin_dashboard_stats_entity.dart';
import '../../infra/repositories/admin_repository.dart';

/// Simple use case to load admin dashboard stats.
class LoadAdminDashboardStatsUsecase {
  final AdminRepository _repository;

  const LoadAdminDashboardStatsUsecase(this._repository);

  Future<AdminDashboardStatsEntity> call() {
    return _repository.getDashboardStats();
  }
}
