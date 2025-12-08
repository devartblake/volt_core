import '../../domain/entities/dashboard_stats_entity.dart';

/// Abstraction for dashboard stats.
///
/// You might later add caching, local fallbacks, etc.
abstract class DashboardRepository {
  Future<DashboardStatsEntity> loadStatsForTechnician({
    required String technicianId,
  });
}