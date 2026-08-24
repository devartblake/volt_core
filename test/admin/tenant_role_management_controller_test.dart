import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/admin/domain/entities/admin_dashboard_stats_entity.dart';
import 'package:voltcore/modules/admin/domain/entities/role_assignment_entity.dart';
import 'package:voltcore/modules/admin/domain/entities/technician_entity.dart';
import 'package:voltcore/modules/admin/domain/entities/tenant_member_entity.dart';
import 'package:voltcore/modules/admin/infra/repositories/admin_repository.dart';
import 'package:voltcore/modules/admin/presenter/controllers/tenant_role_management_controller.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';

void main() {
  const tenantId = 'tenant-1';
  const actorId = 'admin-1';

  TenantMemberEntity member(String id, UserRole role) => TenantMemberEntity(
        tenantId: tenantId,
        userId: id,
        displayName: id,
        email: '$id@example.com',
        role: role,
        isActive: true,
      );

  test('refuses to demote the final active tenant admin', () async {
    final repo = _FakeAdminRepository([member(actorId, UserRole.admin)]);
    final controller = TenantRoleManagementController(repo);
    await controller.load();

    final changed = await controller.assignRole(
      member: controller.state.members.single,
      newRole: UserRole.tech,
      assignedByUserId: actorId,
    );

    expect(changed, isFalse);
    expect(repo.assignCalls, 0);
    expect(controller.state.error, contains('one active tenant admin'));
  });

  test('allows admin demotion when another active admin remains', () async {
    final repo = _FakeAdminRepository([
      member(actorId, UserRole.admin),
      member('admin-2', UserRole.admin),
    ]);
    final controller = TenantRoleManagementController(repo);
    await controller.load();

    final changed = await controller.assignRole(
      member: controller.state.members.first,
      newRole: UserRole.supervisor,
      assignedByUserId: 'admin-2',
      reason: 'Coverage change',
    );

    expect(changed, isTrue);
    expect(repo.assignCalls, 1);
    expect(controller.state.members.first.role, UserRole.supervisor);
  });
}

class _FakeAdminRepository implements AdminRepository {
  _FakeAdminRepository(this.members);

  final List<TenantMemberEntity> members;
  int assignCalls = 0;

  @override
  Future<List<TenantMemberEntity>> listTenantMembers() async =>
      List<TenantMemberEntity>.of(members);

  @override
  Future<void> assignTenantRole({
    required TenantMemberEntity member,
    required UserRole newRole,
    required String assignedByUserId,
    String? reason,
  }) async {
    assignCalls += 1;
  }

  @override
  Future<List<TechnicianEntity>> listTechnicians() async => const [];

  @override
  Future<RoleAssignmentEntity> assignRole({
    required String technicianId,
    required UserRole newRole,
    required String assignedByUserId,
    UserRole? previousRole,
    String? reason,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdminDashboardStatsEntity> getDashboardStats() {
    throw UnimplementedError();
  }
}
