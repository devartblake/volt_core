import 'package:voltcore/modules/admin/domain/entities/role_assignment_entity.dart';
import 'package:voltcore/modules/admin/domain/entities/technician_entity.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';

import '../../domain/entities/admin_dashboard_stats_entity.dart';

abstract class AdminRepository {
  /// List all technicians/users visible to the current admin.
  Future<List<TechnicianEntity>> listTechnicians();

  /// Assign a new role to a technician and return the updated TechnicianEntity
  /// plus a domain event describing the role change.
  Future<RoleAssignmentEntity> assignRole({
    required String technicianId,
    required UserRole newRole,
    required String assignedByUserId,
    UserRole? previousRole,
    String? reason,
  });

  /// Load aggregate stats for the admin dashboard.
  Future<AdminDashboardStatsEntity> getDashboardStats();
}
