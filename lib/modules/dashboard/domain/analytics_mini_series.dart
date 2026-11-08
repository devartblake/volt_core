import 'analytics_series.dart';
import 'analytics_snapshot.dart';

/// Pure series for the small graphs on the Analytics number cards. Same rules
/// as `analytics_series.dart`: plain values and a `now`, calendar arithmetic
/// only (no `Duration(days:)`), so month lengths and DST are unit tested.

/// Days in the month that contains [d] (28 to 31).
int daysInMonth(DateTime d) => DateTime(d.year, d.month + 1, 0).day;

/// Counts per calendar day for [days] days starting at the day of [start]
/// (index 0 is that day). Dates outside the window are ignored.
List<int> dailyCounts(Iterable<DateTime> dates, {required DateTime start, required int days}) {
  assert(days > 0);
  final counts = List<int>.filled(days, 0);
  for (final d in dates) {
    final i = calendarDaysBetween(start, d);
    if (i < 0 || i >= days) continue;
    counts[i]++;
  }
  return counts;
}

/// One bar per day of the month of [now] (28 to 31 of them); today is
/// `now.day - 1`. Days after today are 0.
List<int> dailyCountsThisMonth(Iterable<DateTime> dates, DateTime now) => dailyCounts(
      dates,
      start: DateTime(now.year, now.month),
      days: daysInMonth(now),
    );

/// Tasks per day for the next [days] days, starting today (index 0). Only
/// upcoming tasks count (see [upcomingTaskDates]).
List<int> nextDaysCounts(Iterable<TaskPoint> tasks, DateTime now, {int days = 7}) =>
    dailyCounts(upcomingTaskDates(tasks, now), start: now, days: days);

bool _isPending(TaskPoint t) => t.status == 'scheduled' || t.status == 'overdue';

/// Dates of the tasks the Upcoming card counts: pending and after [now].
List<DateTime> upcomingTaskDates(Iterable<TaskPoint> tasks, DateTime now) =>
    [for (final t in tasks) if (_isPending(t) && t.when.isAfter(now)) t.when];

/// Dates of the tasks the Overdue card counts: pending and not after [now].
List<DateTime> overdueTaskDates(Iterable<TaskPoint> tasks, DateTime now) =>
    [for (final t in tasks) if (_isPending(t) && !t.when.isAfter(now)) t.when];

/// Overdue tasks by how late they are.
class OverdueAges {
  const OverdueAges({this.week = 0, this.month = 0, this.older = 0});

  /// Up to 7 days late (a task that was due earlier today is here).
  final int week;

  /// 8 to 30 days late.
  final int month;

  /// 31 days or more.
  final int older;

  int get total => week + month + older;

  @override
  bool operator ==(Object other) =>
      other is OverdueAges && other.week == week && other.month == month && other.older == older;

  @override
  int get hashCode => Object.hash(week, month, older);

  @override
  String toString() => 'OverdueAges($week, $month, $older)';
}

/// Buckets [dueDates] by whole calendar days before today: 0 to 7, 8 to 30,
/// 31 and more. A date in the future counts as 0 days late.
OverdueAges overdueAges(Iterable<DateTime> dueDates, DateTime now) {
  var w = 0, m = 0, o = 0;
  for (final d in dueDates) {
    final late = calendarDaysBetween(d, now);
    if (late <= 7) {
      w++;
    } else if (late <= 30) {
      m++;
    } else {
      o++;
    }
  }
  return OverdueAges(week: w, month: m, older: o);
}

/// Inspections created per day this month: the "This month" card counts by
/// creation time, so its graph does too.
List<int> inspectionsCreatedThisMonth(Iterable<InspectionPoint> inspections, DateTime now) =>
    dailyCountsThisMonth([for (final i in inspections) i.createdAt], now);

/// Part over whole as 0..1; 0 when [whole] is 0 or less.
double share(int part, int whole) => whole <= 0 ? 0 : (part / whole).clamp(0.0, 1.0).toDouble();

/// Rounded percent of [part] in [whole].
int percentOf(int part, int whole) => (share(part, whole) * 100).round();
