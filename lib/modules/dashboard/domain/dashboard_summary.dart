import 'package:flutter/material.dart';

import '../../auth/domain/user_role.dart';
import '../../schedule/domain/entities/task_schedule_entity.dart';
import '../../work_orders/presenter/work_order_workload.dart';

/// Whether a scheduled task still needs doing.
bool isOpenTaskStatus(String status) =>
    status != 'completed' && status != 'cancelled';

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// What the dashboard says about the schedule, worked out once and shared by
/// the stat tiles, the "needs attention" list and "today".
///
/// "Overdue" means a task dated before today that is still open. The previous
/// dashboard counted every past task as overdue and every past task as
/// completed, whatever its status.
class DashboardSummary {
  const DashboardSummary({
    required this.today,
    required this.todayOpen,
    required this.todayDone,
    required this.overdue,
    required this.completedThisWeek,
    required this.upcomingWeek,
  });

  /// Today's tasks except cancelled ones, earliest first.
  final List<TaskScheduleEntity> today;
  final int todayOpen;
  final int todayDone;

  /// Open tasks dated before today, oldest first.
  final List<TaskScheduleEntity> overdue;

  /// Tasks completed in the last seven days.
  final int completedThisWeek;

  /// Open tasks in the next seven days (not counting today).
  final int upcomingWeek;

  static const empty = DashboardSummary(
    today: [],
    todayOpen: 0,
    todayDone: 0,
    overdue: [],
    completedThisWeek: 0,
    upcomingWeek: 0,
  );

  factory DashboardSummary.fromTasks(
    Iterable<TaskScheduleEntity> tasks, {
    required DateTime now,
  }) {
    final today = _day(now);
    final tomorrow = today.add(const Duration(days: 1));
    final weekAhead = today.add(const Duration(days: 8));
    final weekAgo = today.subtract(const Duration(days: 7));

    final todays = <TaskScheduleEntity>[];
    final overdue = <TaskScheduleEntity>[];
    var completedThisWeek = 0;
    var upcoming = 0;

    for (final task in tasks) {
      final date = _day(task.scheduledDate);
      final open = isOpenTaskStatus(task.status);

      if (date == today) {
        if (task.status != 'cancelled') todays.add(task);
      } else if (date.isBefore(today)) {
        if (open) overdue.add(task);
        if (task.status == 'completed' && !date.isBefore(weekAgo)) {
          completedThisWeek++;
        }
      } else if (open && !date.isBefore(tomorrow) && date.isBefore(weekAhead)) {
        upcoming++;
      }
    }

    todays.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    overdue.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return DashboardSummary(
      today: todays,
      todayOpen: todays.where((t) => isOpenTaskStatus(t.status)).length,
      todayDone: todays.where((t) => t.status == 'completed').length,
      overdue: overdue,
      completedThisWeek: completedThisWeek,
      upcomingWeek: upcoming,
    );
  }
}

/// How a role uses the home screen. Decides the stat tiles, what is flagged
/// for attention, and which shortcuts lead.
enum DashboardAudience {
  /// Technicians: "my day" - their own work and their vehicle's daily check.
  field,

  /// Dispatchers: assigning and scheduling work.
  dispatch,

  /// Supervisors: review of completed inspections.
  review,

  /// Admins: the whole picture.
  admin;

  static DashboardAudience of(UserRole? role) => switch (role) {
        UserRole.tech || UserRole.apprentice => field,
        UserRole.dispatcher => dispatch,
        UserRole.supervisor => review,
        UserRole.admin => admin,
        null => field,
      };

  String get headline => switch (this) {
        field => 'Your day',
        dispatch => 'Dispatch',
        review => 'Review',
        admin => 'Overview',
      };
}

/// One line in the "needs attention" list.
@immutable
class AttentionItem {
  const AttentionItem({
    required this.icon,
    required this.label,
    required this.detail,
    required this.severity,
    required this.route,
  });

  final IconData icon;
  final String label;
  final String detail;
  final AttentionSeverity severity;

  /// Where tapping it goes.
  final String route;
}

enum AttentionSeverity { critical, warning, info }

/// The inputs "needs attention" is worked out from. Anything a role may not
/// see (no fleet access, say) is passed as null / zero and simply omitted.
class AttentionInputs {
  const AttentionInputs({
    required this.audience,
    required this.summary,
    required this.workload,
    required this.redGradeSites,
    required this.vehiclesNeedingDailyCheck,
    required this.routes,
    this.jobsShortOfParts = 0,
    this.generatorsNotReady = 0,
  });

  final DashboardAudience audience;
  final DashboardSummary summary;
  final WorkOrderWorkload? workload;
  final int redGradeSites;

  /// Vehicles with no daily inspection today; null when the role has no fleet.
  final int? vehiclesNeedingDailyCheck;

  final AttentionRoutes routes;

  /// Jobs whose parts the warehouse cannot fully cover. Only dispatchers,
  /// supervisors and admins are told.
  final int jobsShortOfParts;

  /// Generators whose fleet-readiness status is "Not ready". Only dispatchers,
  /// supervisors and admins are told.
  final int generatorsNotReady;
}

/// Route paths the attention items link to, passed in so this file stays free
/// of routing constants.
class AttentionRoutes {
  const AttentionRoutes({
    required this.schedule,
    required this.jobs,
    required this.inspections,
    required this.fleetLog,
    this.shortages = '',
    this.readinessNotReady = '',
  });

  final String schedule;
  final String jobs;
  final String inspections;
  final String fleetLog;

  /// The Shortages page.
  final String shortages;

  /// Fleet readiness with the Not ready filter applied.
  final String readinessNotReady;
}

/// The fleet readiness tile value: "87% ready". An empty fleet is "-" (it is
/// not "100% ready").
String fleetReadinessValue(double percentReady, int total) =>
    total == 0 ? '-' : '${percentReady.round()}% ready';

/// "Generator fleet readiness 87% ready", for a tile label or a screen reader.
String fleetReadinessLabel(double percentReady, int total) => total == 0
    ? 'Generator fleet readiness: no generators yet'
    : 'Generator fleet readiness ${percentReady.round()}% ready';

String _plural(int n, String one, [String? many]) =>
    '$n ${n == 1 ? one : (many ?? '${one}s')}';

/// The things worth a look right now, most urgent first.
List<AttentionItem> buildAttention(AttentionInputs i) {
  final items = <AttentionItem>[];

  if (i.summary.overdue.isNotEmpty) {
    final n = i.summary.overdue.length;
    items.add(AttentionItem(
      icon: Icons.warning_amber_rounded,
      label: _plural(n, 'overdue task'),
      detail: 'Dated before today and not finished',
      severity: AttentionSeverity.critical,
      route: i.routes.schedule,
    ));
  }

  final daily = i.vehiclesNeedingDailyCheck;
  if (daily != null && daily > 0) {
    items.add(AttentionItem(
      icon: Icons.local_shipping_outlined,
      label: i.audience == DashboardAudience.field
          ? 'Daily vehicle check not done'
          : '${_plural(daily, 'vehicle')} without a daily check',
      detail: i.audience == DashboardAudience.field
          ? 'Complete it before taking the vehicle out'
          : 'No daily inspection recorded today',
      severity: AttentionSeverity.warning,
      route: i.routes.fleetLog,
    ));
  }

  final workload = i.workload;
  if (workload != null) {
    if (workload.overdue > 0) {
      items.add(AttentionItem(
        icon: Icons.work_history_outlined,
        label: _plural(workload.overdue, 'overdue job'),
        detail: 'Scheduled for a past date and still open',
        severity: AttentionSeverity.critical,
        route: i.routes.jobs,
      ));
    }
    final dispatches = i.audience == DashboardAudience.dispatch ||
        i.audience == DashboardAudience.admin;
    if (dispatches && workload.unassigned > 0) {
      items.add(AttentionItem(
        icon: Icons.person_off_outlined,
        label: _plural(workload.unassigned, 'unassigned job'),
        detail: 'Open jobs nobody is working yet',
        severity: AttentionSeverity.warning,
        route: i.routes.jobs,
      ));
    }
  }

  final reviews = i.audience == DashboardAudience.review ||
      i.audience == DashboardAudience.admin;
  if (reviews && i.redGradeSites > 0) {
    items.add(AttentionItem(
      icon: Icons.error_outline,
      label: _plural(i.redGradeSites, 'red-grade site'),
      detail: 'Inspections that failed and need follow-up',
      severity: AttentionSeverity.warning,
      route: i.routes.inspections,
    ));
  }

  if (i.audience != DashboardAudience.field &&
      i.jobsShortOfParts > 0 &&
      i.routes.shortages.isNotEmpty) {
    items.add(AttentionItem(
      icon: Icons.inventory_2_outlined,
      label: 'Parts short for ${_plural(i.jobsShortOfParts, 'job')}',
      detail: 'The warehouse cannot cover what they need',
      severity: AttentionSeverity.warning,
      route: i.routes.shortages,
    ));
  }

  if (i.audience != DashboardAudience.field &&
      i.generatorsNotReady > 0 &&
      i.routes.readinessNotReady.isNotEmpty) {
    final n = i.generatorsNotReady;
    items.add(AttentionItem(
      icon: Icons.power_off_outlined,
      label: '$n ${n == 1 ? 'generator' : 'generators'} not ready',
      detail: 'Red grade, long overdue or never inspected',
      severity: AttentionSeverity.critical,
      route: i.routes.readinessNotReady,
    ));
  }

  items.sort((a, b) => a.severity.index.compareTo(b.severity.index));
  return items;
}
