import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/admin_dashboard_stats_entity.dart';
import '../../infra/models/technician_model.dart';

/// Remote datasource for admin features using Supabase.
///
/// Existing responsibilities:
///  - Fetch technicians
///  - Update technician roles
///  - Insert role assignment audit rows
///
/// New responsibilities (added):
///  - Fetch typed TechnicianModel list
///  - Fetch aggregate dashboard stats
class AdminRemoteDatasource {
  static const String techniciansTable = 'technicians';
  static const String roleAssignmentsTable = 'role_assignments';

  // You can adjust these to your actual table names:
  static const String inspectionsTable = 'inspections';
  static const String maintenanceJobsTable = 'maintenance_jobs';

  final SupabaseClient _client;

  AdminRemoteDatasource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// ORIGINAL: Raw technician rows as Map<String, dynamic>.
  ///
  /// Kept for backward compatibility with any existing code that
  /// expects a raw list of maps.
  Future<List<Map<String, dynamic>>> fetchTechnicians() async {
    final response = await _client
        .from(techniciansTable)
        .select()
        .order('name', ascending: true);

    // Supabase dart returns dynamic; cast to List<Map<String,dynamic>>
    return (response as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  }

  /// NEW: Strongly-typed technicians as [TechnicianModel].
  ///
  /// Preferred for new code (repositories/usecases) so the mapping
  /// logic stays in one place.
  Future<List<TechnicianModel>> fetchTechnicianModels() async {
    final response = await _client
        .from(techniciansTable)
        .select()
        .order('name', ascending: true);

    final list = (response as List).cast<Map<String, dynamic>>();

    // Uses TechnicianModel.fromJson (we'll add it as an alias to fromMap)
    return list
        .map<TechnicianModel>((json) => TechnicianModel.fromJson(json))
        .toList();
  }

  Future<Map<String, dynamic>> updateTechnicianRole({
    required String technicianId,
    required String role,
  }) async {
    final response = await _client
        .from(techniciansTable)
        .update({'role': role})
        .eq('id', technicianId)
        .select()
        .single();

    return response as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> insertRoleAssignment({
    required String technicianId,
    required String previousRole,
    required String newRole,
    required String assignedByUserId,
    String? reason,
  }) async {
    final payload = <String, dynamic>{
      'technician_id': technicianId,
      'previous_role': previousRole,
      'new_role': newRole,
      'assigned_by_user_id': assignedByUserId,
      'reason': reason,
    };

    final response = await _client
        .from(roleAssignmentsTable)
        .insert(payload)
        .select()
        .single();

    return response as Map<String, dynamic>;
  }

  /// NEW: Fetch aggregate stats used by the AdminDashboardPage.
  ///
  /// This keeps the Supabase specifics here and returns a clean
  /// domain entity up through the repository/usecase/controller.
  Future<AdminDashboardStatsEntity> fetchDashboardStats() async {
    // Total inspections
    final inspectionsData =
    await _client.from(inspectionsTable).select('id');
    final totalInspections = inspectionsData.length;

    // Open maintenance jobs (status == 'open')
    //
    // NOTE: call `.select()` first so the builder type becomes
    // PostgrestFilterBuilder/PostgrestTransformBuilder, which *has* `eq`.
    final maintenanceOpenData = await _client
        .from(maintenanceJobsTable)
        .select('id')
        .eq('status', 'open');
    final openMaintenanceJobs = maintenanceOpenData.length;

    // Active technicians (is_active == true)
    final activeTechsData = await _client
        .from(techniciansTable)
        .select('id')
        .eq('is_active', true);
    final activeTechnicians = activeTechsData.length;

    return AdminDashboardStatsEntity(
      totalInspections: totalInspections,
      openMaintenanceJobs: openMaintenanceJobs,
      activeTechnicians: activeTechnicians,
    );
  }
}
