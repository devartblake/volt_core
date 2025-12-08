import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/dashboard_stats_entity.dart';
import '../../external/datasources/dashboard_remote_datasource.dart';
import 'dashboard_repository.dart';

/// Concrete implementation backed by Supabase.
class DashboardRepositoryImpl implements DashboardRepository {
  final DashboardRemoteDatasource _remote;

  DashboardRepositoryImpl(this._remote);

  @override
  Future<DashboardStatsEntity> loadStatsForTechnician({
    required String technicianId,
  }) async {
    final model =
    await _remote.fetchStatsForTechnician(technicianId: technicianId);
    return model.toEntity();
  }
}

/// Riverpod provider to expose the repository.
final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  final remote = DashboardRemoteDatasource();
  return DashboardRepositoryImpl(remote);
});
