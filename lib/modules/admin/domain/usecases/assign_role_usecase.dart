import 'package:voltcore/modules/admin/domain/entities/role_assignment_entity.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import '../../infra/repositories/admin_repository.dart';

class AssignRoleUsecase {
  final AdminRepository _repository;

  AssignRoleUsecase(this._repository);

  Future<RoleAssignmentEntity> call({
    required String technicianId,
    required UserRole newRole,
    required String assignedByUserId,
    UserRole? previousRole,
    String? reason,
  }) {
    return _repository.assignRole(
      technicianId: technicianId,
      newRole: newRole,
      assignedByUserId: assignedByUserId,
      previousRole: previousRole,
      reason: reason,
    );
  }
}
