import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../domain/entities/technician_entity.dart';
import '../../domain/usecases/assign_role_usecase.dart';
import '../../domain/usecases/list_users_usecase.dart';
import '../../infra/repositories/admin_repository_impl.dart';
import '../../../auth/domain/user_role.dart';

/// Expose the AssignRoleUsecase
final assignRoleUsecaseProvider = Provider<AssignRoleUsecase>((ref) {
  final repo = ref.watch(adminRepositoryProvider); // ✅ now defined
  return AssignRoleUsecase(repo);
});

/// Expose the ListUsersUsecase (technicians)
final listUsersUsecaseProvider = Provider<ListUsersUsecase>((ref) {
  final repo = ref.watch(adminRepositoryProvider);
  return ListUsersUsecase(repo);
});

/// Simple state for role management UI
class RoleManagementState {
  final List<TechnicianEntity> technicians;
  final bool isLoading;
  final String? error;

  const RoleManagementState({
    required this.technicians,
    required this.isLoading,
    this.error,
  });

  const RoleManagementState.initial()
      : technicians = const [],
        isLoading = false,
        error = null;

  RoleManagementState copyWith({
    List<TechnicianEntity>? technicians,
    bool? isLoading,
    String? error,
  }) {
    return RoleManagementState(
      technicians: technicians ?? this.technicians,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class RoleManagementController extends StateNotifier<RoleManagementState> {
  final ListUsersUsecase _listUsers;
  final AssignRoleUsecase _assignRole;

  RoleManagementController(
      this._listUsers,
      this._assignRole,
      ) : super(const RoleManagementState.initial());

  Future<void> loadTechnicians() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final techs = await _listUsers();
      state = state.copyWith(technicians: techs, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> assignRoleToTech({
    required TechnicianEntity technician,
    required UserRole newRole,
    required String assignedByUserId,
    String? reason,
  }) async {
    try {
      await _assignRole(
        technicianId: technician.id,
        newRole: newRole,
        assignedByUserId: assignedByUserId,
        previousRole: technician.role,
        reason: reason,
      );

      // Optimistically update local state
      final updated = technician.copyWith(role: newRole);
      final list = state.technicians
          .map((t) => t.id == updated.id ? updated : t)
          .toList();
      state = state.copyWith(technicians: list);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

/// Provider for the RoleManagementController
final roleManagementControllerProvider = StateNotifierProvider<
    RoleManagementController, RoleManagementState>((ref) {
  final listUsers = ref.watch(listUsersUsecaseProvider);
  final assignRole = ref.watch(assignRoleUsecaseProvider);
  return RoleManagementController(listUsers, assignRole);
});
