import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../auth/domain/user_role.dart';
import '../../domain/entities/tenant_member_entity.dart';
import '../../infra/repositories/admin_repository_impl.dart';

class TenantRoleManagementState {
  const TenantRoleManagementState({
    this.members = const [],
    this.isLoading = false,
    this.error,
  });

  final List<TenantMemberEntity> members;
  final bool isLoading;
  final String? error;

  TenantRoleManagementState copyWith({
    List<TenantMemberEntity>? members,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return TenantRoleManagementState(
      members: members ?? this.members,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class TenantRoleManagementController
    extends StateNotifier<TenantRoleManagementState> {
  TenantRoleManagementController(this._ref)
      : super(const TenantRoleManagementState());

  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final members = await _ref.read(adminRepositoryProvider).listTenantMembers();
      state = TenantRoleManagementState(members: members);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  Future<bool> assignRole({
    required TenantMemberEntity member,
    required UserRole newRole,
    required String assignedByUserId,
    String? reason,
  }) async {
    if (member.role == newRole) return true;

    if (member.role == UserRole.admin && newRole != UserRole.admin) {
      final activeAdmins = state.members.where(
        (candidate) =>
            candidate.isActive && candidate.role == UserRole.admin,
      );
      if (activeAdmins.length <= 1) {
        state = state.copyWith(
          error: 'At least one active tenant admin must remain.',
        );
        return false;
      }
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _ref.read(adminRepositoryProvider).assignTenantRole(
            member: member,
            newRole: newRole,
            assignedByUserId: assignedByUserId,
            reason: reason,
          );
      final updated = state.members
          .map(
            (candidate) => candidate.userId == member.userId &&
                    candidate.tenantId == member.tenantId
                ? candidate.copyWith(role: newRole)
                : candidate,
          )
          .toList();
      state = TenantRoleManagementState(members: updated);
      return true;
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
      return false;
    }
  }
}

final tenantRoleManagementControllerProvider = StateNotifierProvider<
    TenantRoleManagementController, TenantRoleManagementState>((ref) {
  return TenantRoleManagementController(ref);
});
