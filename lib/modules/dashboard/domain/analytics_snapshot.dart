import 'analytics_series.dart';

/// One inspection, reduced to what Analytics uses.
class InspectionPoint {
  const InspectionPoint({
    required this.date,
    required this.createdAt,
    required this.grade,
    this.siteCode = '',
    this.deficiencies = false,
    this.loadbankDone = false,
  });

  /// Service date (when the inspection happened).
  final DateTime date;
  final DateTime createdAt;
  final String grade;
  final String siteCode;
  final bool deficiencies;
  final bool loadbankDone;
}

/// Everything Analytics reads from the device, as plain values. The page
/// builds one from Hive; tests build one directly.
class AnalyticsSnapshot {
  const AnalyticsSnapshot({
    this.inspections = const [],
    this.maintenance = const [],
    this.tasks = const [],
  });

  static const empty = AnalyticsSnapshot();

  final List<InspectionPoint> inspections;
  final List<MaintenancePoint> maintenance;
  final List<TaskPoint> tasks;
}

/// The numbers shown on the stat cards.
class AnalyticsMetrics {
  const AnalyticsMetrics({
    required this.totalInspections,
    required this.grades,
    required this.deficiencies,
    required this.loadTestsDone,
    required this.inspectionsThisMonth,
    required this.totalMaintenance,
    required this.maintenanceCompleted,
    required this.maintenanceFollowUp,
    required this.upcomingTasks,
    required this.overdueTasks,
  });

  final int totalInspections;
  final GradeSplit grades;
  final int deficiencies;
  final int loadTestsDone;
  final int inspectionsThisMonth;
  final int totalMaintenance;
  final int maintenanceCompleted;
  final int maintenanceFollowUp;
  final int upcomingTasks;
  final int overdueTasks;

  int get maintenanceOpen => totalMaintenance - maintenanceCompleted;

  factory AnalyticsMetrics.from(AnalyticsSnapshot s, DateTime now) {
    final monthStart = DateTime(now.year, now.month);
    var deficiencies = 0, loadTests = 0, thisMonth = 0;
    for (final i in s.inspections) {
      if (i.deficiencies) deficiencies++;
      if (i.loadbankDone) loadTests++;
      if (!i.createdAt.isBefore(monthStart)) thisMonth++;
    }
    var upcoming = 0, overdue = 0;
    for (final t in s.tasks) {
      if (t.status != 'scheduled' && t.status != 'overdue') continue;
      if (t.when.isAfter(now)) {
        upcoming++;
      } else {
        overdue++;
      }
    }
    return AnalyticsMetrics(
      totalInspections: s.inspections.length,
      grades: gradeSplit(s.inspections.map((i) => i.grade)),
      deficiencies: deficiencies,
      loadTestsDone: loadTests,
      inspectionsThisMonth: thisMonth,
      totalMaintenance: s.maintenance.length,
      maintenanceCompleted: s.maintenance.where((m) => m.completed).length,
      maintenanceFollowUp: s.maintenance.where((m) => m.requiresFollowUp).length,
      upcomingTasks: upcoming,
      overdueTasks: overdue,
    );
  }
}
