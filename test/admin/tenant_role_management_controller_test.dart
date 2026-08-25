import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/admin/domain/entities/admin_dashboard_stats_entity.dart';
import 'package:voltcore/modules/admin/domain/entities/role_assignment_entity.dart';
import 'package:voltcore/modules/admin/domain/entities/technician_entity.dart';
import 'package:voltcore/modules/admin/domain/entities/tenant_member_entity.dart';
import 'package:voltcore/modules/admin/domain/entities/tenant_user_lookup.dart';
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

  group('adding a user who is not yet a member', () {
    TenantUserLookup lookupOf({
      bool isMember = false,
      UserRole? currentRole,
      bool isActiveAccount = true,
    }) =>
        TenantUserLookup(
          tenantId: tenantId,
          userId: 'user-9',
          displayName: 'Sam Rivera',
          email: 'sam@example.com',
          isActiveAccount: isActiveAccount,
          isMember: isMember,
          currentRole: currentRole,
        );

    test('grants the chosen role and refreshes the member list', () async {
      final repo = _FakeAdminRepository(
        [member(actorId, UserRole.admin)],
        lookup: lookupOf(),
      );
      final controller = TenantRoleManagementController(repo);
      await controller.load();

      final result = await controller.lookupUser('sam@example.com');
      expect(result, isA<TenantUserFound>());

      final added = await controller.addMember(
        user: (result as TenantUserFound).user,
        role: UserRole.tech,
        assignedByUserId: actorId,
      );

      expect(added, isTrue);
      expect(repo.addCalls, 1);
      expect(repo.addedRole, UserRole.tech);
      // Nobody held a role before, so there is no previous one to record.
      expect(repo.addedPreviousRole, isNull);
      expect(controller.state.members.length, 2);
    });

    test('passes the existing role through when they are already a member',
        () async {
      // "Add member" on somebody who is already on the team is really a role
      // change, and the audit row needs the role they are moving off.
      final repo = _FakeAdminRepository(
        [member(actorId, UserRole.admin)],
        lookup: lookupOf(isMember: true, currentRole: UserRole.dispatcher),
      );
      final controller = TenantRoleManagementController(repo);
      await controller.load();

      final result =
          await controller.lookupUser('sam@example.com') as TenantUserFound;
      await controller.addMember(
        user: result.user,
        role: UserRole.supervisor,
        assignedByUserId: actorId,
      );

      expect(repo.addedPreviousRole, UserRole.dispatcher);
      expect(repo.addedRole, UserRole.supervisor);
    });

    test('separates "no such account" from "the lookup failed"', () async {
      // Collapsing these into one null would send an admin hunting for a typo
      // when the real problem is their tenant configuration.
      final missing = _FakeAdminRepository([], lookup: null);
      final broken = _FakeAdminRepository(
        [],
        lookupError: StateError('No active tenant is configured.'),
      );

      final notFound = await TenantRoleManagementController(missing)
          .lookupUser('nobody@example.com');
      final failed = await TenantRoleManagementController(broken)
          .lookupUser('sam@example.com');

      expect(notFound, isA<TenantUserNotFound>());
      expect((notFound as TenantUserNotFound).email, 'nobody@example.com');

      expect(failed, isA<TenantUserLookupFailed>());
      expect(
        (failed as TenantUserLookupFailed).message,
        contains('No active tenant'),
      );
    });

    test('trims the email and rejects a blank one without a round trip',
        () async {
      final repo = _FakeAdminRepository([], lookup: lookupOf());
      final controller = TenantRoleManagementController(repo);

      final blank = await controller.lookupUser('   ');
      expect(blank, isA<TenantUserLookupFailed>());
      expect(repo.lookedUpEmail, isNull);

      await controller.lookupUser('  sam@example.com  ');
      expect(repo.lookedUpEmail, 'sam@example.com');
    });

    test('a failed grant surfaces the error and adds nobody', () async {
      final repo = _FailingAddRepository();
      final controller = TenantRoleManagementController(repo);

      final added = await controller.addMember(
        user: lookupOf(),
        role: UserRole.admin,
        assignedByUserId: actorId,
      );

      expect(added, isFalse);
      expect(controller.state.error, contains('row-level security'));
      expect(controller.state.members, isEmpty);
    });

    test('a lookup does not blank out the member list behind the dialog',
        () async {
      final repo = _FakeAdminRepository(
        [member(actorId, UserRole.admin)],
        lookup: lookupOf(),
      );
      final controller = TenantRoleManagementController(repo);
      await controller.load();

      final future = controller.lookupUser('sam@example.com');
      expect(controller.state.isLookingUp, isTrue);
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.members, hasLength(1));

      await future;
      expect(controller.state.isLookingUp, isFalse);
    });
  });

  group('app_role wire format', () {
    test('the technician role is spelled differently in Postgres', () {
      // public.app_role is ('admin','supervisor','dispatcher','technician').
      // Writing UserRole.tech.name would send "tech" and fail with
      // 22P02 invalid input value for enum app_role.
      expect(UserRole.tech.name, 'tech');
      expect(UserRole.tech.wire, 'technician');
    });

    test('every role has a wire value the database enum accepts', () {
      const accepted = {'admin', 'supervisor', 'dispatcher', 'technician'};
      for (final role in UserRole.values) {
        expect(accepted, contains(role.wire), reason: 'role ${role.name}');
      }
    });

    test('wire values round-trip back to the same role', () {
      for (final role in UserRole.values) {
        expect(UserRoleX.fromString(role.wire), role);
      }
    });
  });
}

/// Rejects the grant the way Postgres does when the caller is not an admin.
class _FailingAddRepository extends _FakeAdminRepository {
  _FailingAddRepository() : super([]);

  @override
  Future<void> addTenantMember({
    required String userId,
    required UserRole role,
    required String assignedByUserId,
    UserRole? previousRole,
    String? reason,
  }) async {
    throw StateError(
      'new row violates row-level security policy for table "tenant_members"',
    );
  }
}

class _FakeAdminRepository implements AdminRepository {
  _FakeAdminRepository(this.members, {this.lookup, this.lookupError});

  final List<TenantMemberEntity> members;

  /// Result handed back by [lookupUserByEmail] when it succeeds.
  final TenantUserLookup? lookup;

  /// When set, [lookupUserByEmail] throws this instead of answering.
  final Object? lookupError;

  int assignCalls = 0;
  int addCalls = 0;
  UserRole? addedRole;
  UserRole? addedPreviousRole;
  String? lookedUpEmail;

  @override
  Future<List<TenantMemberEntity>> listTenantMembers() async =>
      List<TenantMemberEntity>.of(members);

  @override
  Future<TenantUserLookup?> lookupUserByEmail(String email) async {
    lookedUpEmail = email;
    if (lookupError != null) throw lookupError!;
    return lookup;
  }

  @override
  Future<void> addTenantMember({
    required String userId,
    required UserRole role,
    required String assignedByUserId,
    UserRole? previousRole,
    String? reason,
  }) async {
    addCalls += 1;
    addedRole = role;
    addedPreviousRole = previousRole;
    members.add(
      TenantMemberEntity(
        tenantId: 'tenant-1',
        userId: userId,
        displayName: userId,
        email: '$userId@example.com',
        role: role,
        isActive: true,
      ),
    );
  }

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
