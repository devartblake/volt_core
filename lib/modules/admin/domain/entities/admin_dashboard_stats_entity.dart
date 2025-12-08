import 'package:meta/meta.dart';

/// Aggregated stats for the admin dashboard.
///
/// You can extend this later with more fields (e.g. closedInspections,
/// overdueJobs, etc.) without breaking the rest of the wiring.
@immutable
class AdminDashboardStatsEntity {
  final int totalInspections;
  final int openMaintenanceJobs;
  final int activeTechnicians;

  const AdminDashboardStatsEntity({
    required this.totalInspections,
    required this.openMaintenanceJobs,
    required this.activeTechnicians,
  });

  AdminDashboardStatsEntity copyWith({
    int? totalInspections,
    int? openMaintenanceJobs,
    int? activeTechnicians,
  }) {
    return AdminDashboardStatsEntity(
      totalInspections: totalInspections ?? this.totalInspections,
      openMaintenanceJobs: openMaintenanceJobs ?? this.openMaintenanceJobs,
      activeTechnicians: activeTechnicians ?? this.activeTechnicians,
    );
  }

  @override
  String toString() {
    return 'AdminDashboardStatsEntity('
        'totalInspections: $totalInspections, '
        'openMaintenanceJobs: $openMaintenanceJobs, '
        'activeTechnicians: $activeTechnicians'
        ')';
  }
}
