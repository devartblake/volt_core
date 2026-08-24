import 'package:voltcore/modules/admin/domain/entities/role_assignment_entity.dart';
import 'package:voltcore/modules/admin/domain/entities/technician_entity.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';

import '../../domain/entities/admin_dashboard_stats_entity.dart';
import '../../domain/entities/tenant_member_entity.dart';

abstract class AdminRepository {
  /// Legacy technician registry. Kept for compatibility with older screens.
  Future<List<TechnicianEntity>> listTechnicians();

  /// Legacy technician-role writer. New RBAC UI must use tenant membership.
  Future<RoleAssignmentEntity> assignRole({
    required String technicianId,
    required UserRole newRole,
    required String assignedByUserId,
    UserRole? previousRole,
    String? reason,
  });

  /// Members of the active tenant using the same role source as authentication.
  Future<List<TenantMemberEntity>> listTenantMembers();

  /// Change one active tenant membership role and write a tenant-scoped audit.
  Future<void> assignTenantRole({
    required TenantMemberEntity member,
    required UserRole newRole,
    required String assignedByUserId,
    String? reason,
  });

  Future<AdminDashboardStatsEntity> getDashboardStats();
}
