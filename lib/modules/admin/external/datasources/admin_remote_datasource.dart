import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/sync/sync_context.dart';
import '../../../auth/domain/user_role.dart';
import '../../domain/entities/admin_dashboard_stats_entity.dart';
import '../../domain/entities/tenant_member_entity.dart';
import '../../domain/entities/tenant_user_lookup.dart';
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
          // `wire`, not `name` — these columns are the app_role enum, which
          // spells the field role "technician". See UserRoleX.wire.
          'role': newRole.wire,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('tenant_id', tenantId)
        .eq('user_id', userId);

    try {
      await _client.from(tenantRoleAssignmentsTable).insert({
        'tenant_id': tenantId,
        'user_id': userId,
        'previous_role': previousRole.wire,
        'new_role': newRole.wire,
        'assigned_by_user_id': assignedByUserId,
        'reason': reason,
      });
    } catch (error) {
      // Do not leave the authoritative membership changed without an audit row.
      await _client
          .from(tenantMembersTable)
          .update({
            'role': previousRole.wire,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('tenant_id', tenantId)
          .eq('user_id', userId);
      rethrow;
    }
  }

  /// Find a registered user by their exact email address.
  ///
  /// Goes through the `admin_lookup_user_by_email` definer function rather than
  /// selecting `user_profiles` directly: somebody who is not yet a member of
  /// this tenant is invisible to every RLS policy the admin has, which is the
  /// whole reason they need adding. Returns null when no account uses that
  /// address.
  Future<TenantUserLookup?> lookupUserByEmail(String email) async {
    final tenantId = SyncContext.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('No active tenant is configured.');
    }

    final rows = (await _client.rpc(
      'admin_lookup_user_by_email',
      params: {'p_tenant_id': tenantId, 'p_email': email},
    ) as List)
        .cast<Map<String, dynamic>>();

    if (rows.isEmpty) return null;
    final row = rows.first;

    final userId = row['user_id']?.toString();
    if (userId == null || userId.isEmpty) return null;

    final displayName = row['display_name']?.toString().trim() ?? '';
    final resolvedEmail = row['email']?.toString() ?? '';

    return TenantUserLookup(
      tenantId: tenantId,
      userId: userId,
      displayName: displayName.isNotEmpty
          ? displayName
          : (resolvedEmail.isEmpty ? 'Registered user' : resolvedEmail.split('@').first),
      email: resolvedEmail,
      phone: row['phone']?.toString(),
      isActiveAccount: row['is_active'] == true,
      isMember: row['is_member'] == true,
      currentRole: UserRoleX.fromString(row['member_role']?.toString()),
    );
  }

  /// Grant [role] to [userId] in the active tenant, with an audit row.
  ///
  /// Upserts rather than inserts: `tenant_members` is keyed on
  /// `(tenant_id, user_id)`, and somebody who was previously deactivated still
  /// has a row. A plain insert would fail on the primary key and leave an admin
  /// unable to re-add a former colleague.
  Future<void> addTenantMember({
    required String userId,
    required UserRole role,
    required String assignedByUserId,
    UserRole? previousRole,
    String? reason,
  }) async {
    final tenantId = SyncContext.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('No active tenant is configured.');
    }

    // Audit first, membership second — the reverse of updateTenantMemberRole,
    // which has an existing row to roll back to and so can afford to write
    // first. Here there may be nothing to restore. If the audit insert fails,
    // nothing has been granted; if the membership write fails, the audit
    // records a change that did not happen. Of the two halves, a privilege
    // granted with no record is the one that must not be possible.
    //
    // `previous_role` is NOT NULL, so a first-time grant records the new role
    // on both sides. previous == new is how this table spells "no prior role".
    await _client.from(tenantRoleAssignmentsTable).insert({
      'tenant_id': tenantId,
      'user_id': userId,
      'previous_role': (previousRole ?? role).wire,
      'new_role': role.wire,
      'assigned_by_user_id': assignedByUserId,
      'reason': reason ?? 'Added to tenant',
    });

    // Upsert, not insert: tenant_members is keyed on (tenant_id, user_id), and
    // somebody previously deactivated still has a row. A plain insert would
    // fail on the primary key and leave an admin unable to re-add a former
    // colleague.
    await _client.from(tenantMembersTable).upsert({
      'tenant_id': tenantId,
      'user_id': userId,
      'role': role.wire,
      'is_active': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
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
