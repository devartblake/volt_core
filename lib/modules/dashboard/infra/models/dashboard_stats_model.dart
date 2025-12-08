import '../../domain/entities/dashboard_stats_entity.dart';

/// Data model used to map from a JSON / RPC payload to a domain entity.
///
/// For now we assume you're calling a Supabase RPC that returns:
/// {
///   "my_open_inspections": 3,
///   "my_completed_inspections": 12,
///   "my_open_maintenance_jobs": 1,
///   "my_completed_maintenance_jobs": 5,
///   "upcoming_tasks": 4
/// }
class DashboardStatsModel extends DashboardStatsEntity {
  const DashboardStatsModel({
    required super.myOpenInspections,
    required super.myCompletedInspections,
    required super.myOpenMaintenanceJobs,
    required super.myCompletedMaintenanceJobs,
    required super.upcomingTasks,
  });

  factory DashboardStatsModel.fromMap(Map<String, dynamic> map) {
    return DashboardStatsModel(
      myOpenInspections: (map['my_open_inspections'] as int?) ?? 0,
      myCompletedInspections:
      (map['my_completed_inspections'] as int?) ?? 0,
      myOpenMaintenanceJobs:
      (map['my_open_maintenance_jobs'] as int?) ?? 0,
      myCompletedMaintenanceJobs:
      (map['my_completed_maintenance_jobs'] as int?) ?? 0,
      upcomingTasks: (map['upcoming_tasks'] as int?) ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'my_open_inspections': myOpenInspections,
      'my_completed_inspections': myCompletedInspections,
      'my_open_maintenance_jobs': myOpenMaintenanceJobs,
      'my_completed_maintenance_jobs': myCompletedMaintenanceJobs,
      'upcoming_tasks': upcomingTasks,
    };
  }

  DashboardStatsEntity toEntity() => this;
}