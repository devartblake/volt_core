import '../entities/dashboard_stats_entity.dart';
import '../../infra/repositories/dashboard_repository.dart';

/// Usecase that loads dashboard stats for a given technician/user.
class LoadDashboardStatsUsecase {
  final DashboardRepository _repository;

  LoadDashboardStatsUsecase(this._repository);

  /// You can pass either a real backend userId or a local derived one.
  Future<DashboardStatsEntity> call({required String technicianId}) {
    return _repository.loadStatsForTechnician(technicianId: technicianId);
  }
}