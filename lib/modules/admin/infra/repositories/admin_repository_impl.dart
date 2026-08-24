import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voltcore/modules/admin/domain/entities/role_assignment_entity.dart';
import 'package:voltcore/modules/admin/domain/entities/technician_entity.dart';
import 'package:voltcore/modules/admin/infra/repositories/admin_repository.dart';
import 'package:voltcore/modules/admin/external/datasources/admin_remote_datasource.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';

import '../../domain/entities/admin_dashboard_stats_entity.dart';
import '../../domain/entities/tenant_member_entity.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final remote = AdminRemoteDatasource();
  return AdminRepositoryImpl(remote);
});

class AdminRepositoryImpl implements AdminRepository {
  final AdminRemoteDatasource _remote;

  AdminRepositoryImpl(this._remote);

  @override
  Future<List<TenantMemberEntity>> listTenantMembers() {
    return _remote.fetchTenantMembers();
  }

  @override
  Future<void> assignTenantRole({
    required TenantMemberEntity member,
    required UserRole newRole,
    required String assignedByUserId,
    String? reason,
  }) {
    return _remote.updateTenantMemberRole(
      tenantId: member.tenantId,
      userId: member.userId,
      previousRole: member.role,
      newRole: newRole,
      assignedByUserId: assignedByUserId,
      reason: reason,
    );
  }

  @override
  Future<List<TechnicianEntity>> listTechnicians() async {
    final models = await _remote.fetchTechnicianModels();
    return models.map<TechnicianEntity>((model) => model).toList();
  }

  @override
  Future<AdminDashboardStatsEntity> getDashboardStats() {
    return _remote.fetchDashboardStats();
  }

  @override
  Future<RoleAssignmentEntity> assignRole({
    required String technicianId,
    required UserRole newRole,
    String? reason,
    UserRole? previousRole,
    required String assignedByUserId,
  }) async {
    final technicians = await listTechnicians();
    final tech = technicians.firstWhere(
      (technician) => technician.id == technicianId,
      orElse: () => throw StateError('Technician not found: $technicianId'),
    );

    final previousRole = tech.role;

    await _remote.updateTechnicianRole(
      technicianId: technicianId,
      role: newRole.name,
    );

    final assignmentRow = await _remote.insertRoleAssignment(
      technicianId: technicianId,
      previousRole: previousRole.name,
      newRole: newRole.name,
      assignedByUserId: assignedByUserId,
      reason: reason,
    );

    final assignedAtRaw =
        assignmentRow['created_at'] ?? assignmentRow['assigned_at'];
    final assignedAt = assignedAtRaw != null
        ? DateTime.tryParse(assignedAtRaw.toString()) ?? DateTime.now()
        : DateTime.now();

    return RoleAssignmentEntity(
      technicianId: technicianId,
      previousRole: previousRole,
      newRole: newRole,
      assignedByUserId: assignedByUserId,
      assignedAt: assignedAt,
      reason: reason,
    );
  }
}
