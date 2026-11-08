/// Pure helpers the readiness screens share: wording, week grouping and a
/// unit's inspection history. No Flutter, no Hive, so they are unit tested.
library;

import 'readiness_inputs.dart';
import 'readiness_join.dart';
import 'readiness_models.dart';
import 'readiness_rules.dart' show readinessDate;
import 'readiness_summary.dart' show ReadinessFilter, mondayOf;

const _monthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "3:20 PM".
String readinessClock(DateTime t) {
  final l = t.toLocal();
  final h = l.hour % 12 == 0 ? 12 : l.hour % 12;
  final m = l.minute.toString().padLeft(2, '0');
  return '$h:$m ${l.hour < 12 ? 'AM' : 'PM'}';
}

String _days(int n) => n == 1 ? '1 day' : '$n days';

/// The due countdown on a card: "Due in 9 days", "Overdue 12 days",
/// "Due ~Mar 2027 (estimated)", "No inspection on record".
String readinessDueText(ReadinessUnit u) {
  final due = u.nextDueAt;
  final d = u.daysToDue;
  if (due == null || d == null) return 'No inspection on record';
  if (d < 0) {
    return 'Overdue ${_days(-d)}${u.dueIsEstimated ? ' (estimated)' : ''}';
  }
  if (u.dueIsEstimated) {
    return 'Due ~${_monthNames[due.month - 1]} ${due.year} (estimated)';
  }
  if (d == 0) return 'Due today';
  return 'Due in ${_days(d)}';
}

/// One section of the "Due calendar".
class ReadinessWeekGroup {
  const ReadinessWeekGroup(this.label, this.units, {this.weekStart});

  final String label;

  /// Monday of the week, null for Overdue / Later / No date.
  final DateTime? weekStart;
  final List<ReadinessUnit> units;

  int get count => units.length;
}

/// Units grouped for the calendar: Overdue, This week, Next week, then
/// "Week of 23 Nov" up to [weeks] weeks, then Later, then units with no due
/// date. Empty groups are left out; units inside a group are in due order.
List<ReadinessWeekGroup> groupByDueWeek(
  Iterable<ReadinessUnit> units,
  DateTime now, {
  int weeks = 12,
}) {
  final start = mondayOf(now);
  final overdue = <ReadinessUnit>[];
  final later = <ReadinessUnit>[];
  final none = <ReadinessUnit>[];
  final byWeek = List.generate(weeks, (_) => <ReadinessUnit>[]);

  for (final u in units) {
    final due = u.nextDueAt, days = u.daysToDue;
    if (due == null || days == null) {
      none.add(u);
    } else if (days < 0) {
      overdue.add(u);
    } else {
      final w = daysBetween(start, due) ~/ 7;
      (w >= 0 && w < weeks ? byWeek[w] : later).add(u);
    }
  }

  int byDue(ReadinessUnit a, ReadinessUnit b) {
    final c = (a.daysToDue ?? 0).compareTo(b.daysToDue ?? 0);
    return c != 0 ? c : a.title.toLowerCase().compareTo(b.title.toLowerCase());
  }

  for (final l in [overdue, later, ...byWeek]) {
    l.sort(byDue);
  }
  none.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

  final out = <ReadinessWeekGroup>[];
  if (overdue.isNotEmpty) out.add(ReadinessWeekGroup('Overdue', overdue));
  for (var w = 0; w < weeks; w++) {
    if (byWeek[w].isEmpty) continue;
    final ws = DateTime(start.year, start.month, start.day + 7 * w);
    final label = w == 0
        ? 'This week'
        : w == 1
            ? 'Next week'
            : 'Week of ${readinessDate(ws, now)}';
    out.add(ReadinessWeekGroup(label, byWeek[w], weekStart: ws));
  }
  if (later.isNotEmpty) out.add(ReadinessWeekGroup('Later', later));
  if (none.isNotEmpty) out.add(ReadinessWeekGroup('No due date', none));
  return out;
}

/// The inspections that belong to [unit], newest first (at most [limit]).
///
/// Matches by serial when the unit has one, else by site code, else by the
/// unit's latest inspection id.
List<ReadinessInspection> inspectionHistoryFor(
  ReadinessUnit unit,
  Iterable<ReadinessInspection> all, {
  int limit = 12,
}) {
  final serial = normSerial(unit.serial);
  final site = normSite(unit.siteCode);
  bool mine(ReadinessInspection i) {
    if (serial.isNotEmpty) return normSerial(i.serial) == serial;
    if (site.isNotEmpty) {
      return normSerial(i.serial).isEmpty && normSite(i.siteCode) == site;
    }
    return i.id == unit.latestInspectionId;
  }

  final list = [
    for (final i in all)
      if (mine(i)) i,
  ]..sort((a, b) => b.serviceDate.compareTo(a.serviceDate));
  return list.length > limit ? list.sublist(0, limit) : list;
}

/// Grades of [history] oldest first, for the trend strip.
List<ReadinessGrade> gradeTrend(List<ReadinessInspection> history) => [
      for (final i in history.reversed) ReadinessGrade.parse(i.grade),
    ];

/// Counts of the due-by-week histogram as one plain sentence for screen
/// readers: "3 overdue. This week 2, next week 0, ...".
String dueChartSummary(int overdue, List<int> weekCounts, DateTime start) {
  final b = StringBuffer('$overdue overdue');
  for (var i = 0; i < weekCounts.length; i++) {
    if (weekCounts[i] == 0) continue;
    final ws = DateTime(start.year, start.month, start.day + 7 * i);
    b.write('. ${weekCounts[i]} due ');
    b.write(i == 0 ? 'this week' : 'week of ${ws.day} ${_monthNames[ws.month - 1]}');
  }
  return b.toString();
}

/// How many separate conditions [f] sets (search, statuses, make, borough, due
/// window or week, follow-ups, grade). For the "Filters (3)" badge.
int activeFilterCount(ReadinessFilter f) =>
    (f.query.trim().isEmpty ? 0 : 1) +
    (f.statuses.isEmpty ? 0 : 1) +
    (f.make == null ? 0 : 1) +
    (f.borough == null ? 0 : 1) +
    (f.dueWindow == null && f.dueWeekStart == null ? 0 : 1) +
    (f.hasFollowUps == null ? 0 : 1) +
    (f.grade == null ? 0 : 1);

/// The conditions that live in the "Filters" sheet on a phone (everything but
/// the search box and the status chips).
int sheetFilterCount(ReadinessFilter f) =>
    activeFilterCount(f) -
    (f.query.trim().isEmpty ? 0 : 1) -
    (f.statuses.isEmpty ? 0 : 1);
