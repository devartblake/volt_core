import 'package:supabase_flutter/supabase_flutter.dart';
import '../../infra/models/dashboard_stats_model.dart';

/// Remote datasource for technician dashboard stats.
///
/// This keeps all Supabase-specific logic here, away from domain/UI.
class DashboardRemoteDatasource {
  final SupabaseClient _client;

  DashboardRemoteDatasource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Fetch per-technician stats.
  ///
  /// This assumes a Supabase function like:
  ///   rpc('get_tech_dashboard_stats', params: {'technician_id': '...'})
  ///
  /// You can adjust the function name and mapping as needed.
  Future<DashboardStatsModel> fetchStatsForTechnician({
    required String technicianId,
  }) async {
    final response = await _client.rpc(
      'get_tech_dashboard_stats',
      params: {'technician_id': technicianId},
    );

    // Expecting a single row object.
    if (response is Map<String, dynamic>) {
      return DashboardStatsModel.fromMap(response);
    }

    // If your RPC returns a list, uncomment and adjust:
    //
    // final list = (response as List).cast<Map<String, dynamic>>();
    // final first = list.isNotEmpty ? list.first : <String, dynamic>{};
    // return DashboardStatsModel.fromMap(first);

    // Fallback to zeros if unknown shape
    return const DashboardStatsModel(
      myOpenInspections: 0,
      myCompletedInspections: 0,
      myOpenMaintenanceJobs: 0,
      myCompletedMaintenanceJobs: 0,
      upcomingTasks: 0,
    );
  }
}
