/// Role-agnostic dashboard stats for a *single* technician/user.
///
/// You can extend this later (e.g. per-site counts, SLA breaches, etc.).
class DashboardStatsEntity {
  /// Number of inspections assigned to this tech that are still open/pending.
  final int myOpenInspections;

  /// Number of inspections this tech has completed.
  final int myCompletedInspections;

  /// Number of maintenance jobs currently open for this tech.
  final int myOpenMaintenanceJobs;

  /// Number of maintenance jobs this tech has completed.
  final int myCompletedMaintenanceJobs;

  /// Number of upcoming scheduled tasks (inspections/maintenance) in the near future.
  final int upcomingTasks;

  const DashboardStatsEntity({
    required this.myOpenInspections,
    required this.myCompletedInspections,
    required this.myOpenMaintenanceJobs,
    required this.myCompletedMaintenanceJobs,
    required this.upcomingTasks,
  });

  const DashboardStatsEntity.empty()
      : myOpenInspections = 0,
        myCompletedInspections = 0,
        myOpenMaintenanceJobs = 0,
        myCompletedMaintenanceJobs = 0,
        upcomingTasks = 0;

  DashboardStatsEntity copyWith({
    int? myOpenInspections,
    int? myCompletedInspections,
    int? myOpenMaintenanceJobs,
    int? myCompletedMaintenanceJobs,
    int? upcomingTasks,
  }) {
    return DashboardStatsEntity(
      myOpenInspections: myOpenInspections ?? this.myOpenInspections,
      myCompletedInspections:
      myCompletedInspections ?? this.myCompletedInspections,
      myOpenMaintenanceJobs:
      myOpenMaintenanceJobs ?? this.myOpenMaintenanceJobs,
      myCompletedMaintenanceJobs:
      myCompletedMaintenanceJobs ?? this.myCompletedMaintenanceJobs,
      upcomingTasks: upcomingTasks ?? this.upcomingTasks,
    );
  }
}