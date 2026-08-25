import 'package:flutter_riverpod/legacy.dart';

import '../../../auth/domain/user_role.dart';
import '../../domain/entities/tenant_member_entity.dart';
import '../../domain/entities/tenant_user_lookup.dart';
import '../../infra/repositories/admin_repository.dart';
import '../../infra/repositories/admin_repository_impl.dart';

/// Outcome of searching for an account to add to the tenant.
///
/// Three states, not two: an admin who cannot tell "that address has no
/// account" from "the search failed" has no way to know whether to check the
/// spelling or check their configuration.
sealed class TenantUserLookupResult {
  const TenantUserLookupResult();

  const factory TenantUserLookupResult.found(TenantUserLookup user) =
      TenantUserFound;
  const factory TenantUserLookupResult.notFound(String email) =
      TenantUserNotFound;
  const factory TenantUserLookupResult.failed(String message) =
      TenantUserLookupFailed;
}

class TenantUserFound extends TenantUserLookupResult {
  const TenantUserFound(this.user);
  final TenantUserLookup user;
}

class TenantUserNotFound extends TenantUserLookupResult {
  const TenantUserNotFound(this.email);
  final String email;
}

class TenantUserLookupFailed extends TenantUserLookupResult {
  const TenantUserLookupFailed(this.message);
  final String message;
}

class TenantRoleManagementState {
  const TenantRoleManagementState({
    this.members = const [],
    this.isLoading = false,
    this.isLookingUp = false,
    this.error,
  });

  final List<TenantMemberEntity> members;
  final bool isLoading;

  /// Tracked separately from [isLoading]: a lookup runs inside the add dialog
  /// and must not blank out the member list behind it.
  final bool isLookingUp;
  final String? error;

  TenantRoleManagementState copyWith({
    List<TenantMemberEntity>? members,
    bool? isLoading,
    bool? isLookingUp,
    String? error,
    bool clearError = false,
  }) {
    return TenantRoleManagementState(
      members: members ?? this.members,
      isLoading: isLoading ?? this.isLoading,
      isLookingUp: isLookingUp ?? this.isLookingUp,
      error: clearError ? null : error ?? this.error,
    );
  }
}

class TenantRoleManagementController
    extends StateNotifier<TenantRoleManagementState> {
  TenantRoleManagementController(this._repository)
      : super(const TenantRoleManagementState());

  final AdminRepository _repository;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final members = await _repository.listTenantMembers();
      state = TenantRoleManagementState(members: members);
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
    }
  }

  /// Look up a registered account by exact email.
  ///
  /// Returns a [TenantUserLookupResult] rather than a nullable entity because
  /// "no account uses this address" and "the lookup itself failed" lead the
  /// admin to do completely different things, and collapsing them into null
  /// would send someone chasing a typo when the real problem is that their
  /// tenant context is wrong.
  Future<TenantUserLookupResult> lookupUser(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) {
      return const TenantUserLookupResult.failed('Enter an email address.');
    }

    state = state.copyWith(isLookingUp: true, clearError: true);
    try {
      final found = await _repository.lookupUserByEmail(trimmed);
      state = state.copyWith(isLookingUp: false);
      if (found == null) {
        return TenantUserLookupResult.notFound(trimmed);
      }
      return TenantUserLookupResult.found(found);
    } catch (error) {
      state = state.copyWith(isLookingUp: false);
      return TenantUserLookupResult.failed(error.toString());
    }
  }

  /// Grant [role] to a user returned by [lookupUser].
  ///
  /// Reloads afterwards rather than appending locally: the new row is the
  /// server's, and the member list carries profile fields this controller never
  /// saw.
  Future<bool> addMember({
    required TenantUserLookup user,
    required UserRole role,
    required String assignedByUserId,
    String? reason,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.addTenantMember(
        userId: user.userId,
        role: role,
        assignedByUserId: assignedByUserId,
        previousRole: user.currentRole,
        reason: reason,
      );
      await load();
      return true;
    } catch (error) {
      state = state.copyWith(isLoading: false, error: error.toString());
      return false;
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
      final activeAdminCount = state.members
          .where(
            (candidate) =>
                candidate.isActive && candidate.role == UserRole.admin,
          )
          .length;
      if (activeAdminCount <= 1) {
        state = state.copyWith(
          error: 'At least one active tenant admin must remain.',
        );
        return false;
      }
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.assignTenantRole(
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
  return TenantRoleManagementController(ref.watch(adminRepositoryProvider));
});
