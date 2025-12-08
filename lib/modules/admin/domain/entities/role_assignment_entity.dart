import 'package:voltcore/modules/auth/domain/user_role.dart';

/// Domain entity representing a single role assignment event
/// (who changed whose role, when, and to what).
class RoleAssignmentEntity {
  final String technicianId;
  final UserRole previousRole;
  final UserRole newRole;
  final String assignedByUserId;
  final DateTime assignedAt;
  final String? reason;

  const RoleAssignmentEntity({
    required this.technicianId,
    required this.previousRole,
    required this.newRole,
    required this.assignedByUserId,
    required this.assignedAt,
    this.reason,
  });
}
