import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/sync/sync_context.dart';
import '../../../auth/domain/user_role.dart';
import '../../domain/entities/admin_dashboard_stats_entity.dart';
import '../../domain/entities/tenant_member_entity.dart';
import '../../infra/models/technician_model.dart';

class AdminRemoteDatasource {
  static const String techniciansTable = 'technicians';
  static const String roleAssignmentsTable = 'role_assignments';
  static const String tenantMembersTable = 'tenant_members';
  static const String tenantRoleAssignmentsTable = 'tenant_role_assignments';
  static const String userProfilesTable = 'user_profiles';
  static const String inspectionsTable = 'inspections';
  static const String maintenanceJobsTable = 'maintenance_jobs';

  final SupabaseClient _client;

  AdminRemoteDatasource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<List<TenantMemberEntity>> fetchTenantMembers() async {
    final tenantId = SyncContext.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('No active tenant is configured.');
    }

    final memberRows = (await _client
            .from(tenantMembersTable)
            .select('tenant_id,user_id,role,is_active')
            .eq('tenant_id', tenantId))
        .cast<Map<String, dynamic>>();

    final userIds = memberRows
        .map((row) => row['user_id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();

    final profilesByUserId = <String, Map<String, dynamic>>{};
    if (userIds.isNotEmpty) {
      final profiles = (await _client
              .from(userProfilesTable)
              .select('user_id,display_name,email,phone,is_active')
              .inFilter('user_id', userIds))
          .cast<Map<String, dynamic>>();
      for (final profile in profiles) {
        final userId = profile['user_id']?.toString();
        if (userId != null) profilesByUserId[userId] = profile;
      }
    }

    final members = <TenantMemberEntity>[];
    for (final row in memberRows) {
      final userId = row['user_id']?.toString() ?? '';
      if (userId.isEmpty) continue;
      final profile = profilesByUserId[userId];
      final role = UserRoleX.fromString(row['role']?.toString());
      if (role == null) continue;
      final email = profile?['email']?.toString() ?? '';
      final displayName = profile?['display_name']?.toString().trim();
      members.add(
        TenantMemberEntity(
          tenantId: row['tenant_id']?.toString() ?? tenantId,
          userId: userId,
          displayName: displayName == null || displayName.isEmpty
              ? (email.isEmpty ? 'Tenant member' : email.split('@').first)
              : displayName,
          email: email,
          phone: profile?['phone']?.toString(),
          role: role,
          isActive: row['is_active'] == true,
        ),
      );
    }

    members.sort(
      (a, b) => a.displayName.toLowerCase().compareTo(
            b.displayName.toLowerCase(),
          ),
    );
    return members;
  }

  Future<void> updateTenantMemberRole({
    required String tenantId,
    required String userId,
    required UserRole previousRole,
    required UserRole newRole,
    required String assignedByUserId,
    String? reason,
  }) async {
    if (previousRole == newRole) return;

    await _client
        .from(tenantMembersTable)
        .update({
          'role': newRole.name,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('tenant_id', tenantId)
        .eq('user_id', userId);

    try {
      await _client.from(tenantRoleAssignmentsTable).insert({
        'tenant_id': tenantId,
        'user_id': userId,
        'previous_role': previousRole.name,
        'new_role': newRole.name,
        'assigned_by_user_id': assignedByUserId,
        'reason': reason,
      });
    } catch (error) {
      // Do not leave the authoritative membership changed without an audit row.
      await _client
          .from(tenantMembersTable)
          .update({
            'role': previousRole.name,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('tenant_id', tenantId)
          .eq('user_id', userId);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchTechnicians() async {
    final response = await _client
        .from(techniciansTable)
        .select()
        .order('name', ascending: true);
    return (response as List).map((e) => e as Map<String, dynamic>).toList();
  }

  Future<List<TechnicianModel>> fetchTechnicianModels() async {
    final response = await _client
        .from(techniciansTable)
        .select()
        .order('name', ascending: true);
    final list = (response as List).cast<Map<String, dynamic>>();
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
    return response;
  }

  Future<Map<String, dynamic>> insertRoleAssignment({
    required String technicianId,
    required String previousRole,
    required String newRole,
    required String assignedByUserId,
    String? reason,
  }) async {
    final response = await _client.from(roleAssignmentsTable).insert({
      'technician_id': technicianId,
      'previous_role': previousRole,
      'new_role': newRole,
      'assigned_by_user_id': assignedByUserId,
      'reason': reason,
    }).select().single();
    return response;
  }

  Future<AdminDashboardStatsEntity> fetchDashboardStats() async {
    final inspectionsData = await _client.from(inspectionsTable).select('id');
    final totalInspections = inspectionsData.length;

    final maintenanceOpenData = await _client
        .from(maintenanceJobsTable)
        .select('id, status');
    const openStatuses = {'draft', 'scheduled', 'in_progress'};
    final openMaintenanceJobs = maintenanceOpenData
        .where((row) => openStatuses.contains(row['status']))
        .length;

    // Prefer the same membership source that authentication uses. If tenant
    // context is unavailable, preserve the legacy dashboard fallback.
    var activeTechnicians = 0;
    try {
      final members = await fetchTenantMembers();
      activeTechnicians = members.where((member) => member.isActive).length;
    } catch (_) {
      final activeTechsData = await _client
          .from(techniciansTable)
          .select('id')
          .eq('is_active', true);
      activeTechnicians = activeTechsData.length;
    }

    return AdminDashboardStatsEntity(
      totalInspections: totalInspections,
      openMaintenanceJobs: openMaintenanceJobs,
      activeTechnicians: activeTechnicians,
    );
  }
}
