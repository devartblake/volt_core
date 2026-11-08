import '../../work_orders/domain/entities/work_order_entity.dart';

/// Pure series builders for the Analytics graphs. No Flutter, no Hive: every
/// function takes plain values and a `now`, so boundaries (week, month and
/// year edges, DST) can be unit tested.
///
/// All date arithmetic is calendar arithmetic (`DateTime(y, m, d + n)`), never
/// `add(Duration(days: n))`, which drifts an hour across a DST change.

/// The time window the time-based charts cover.
enum AnalyticsPeriod {
  weeks4('4 weeks', 4),
  weeks12('12 weeks', 12),
  months6('6 months', 26),
  all('All', 52);

  const AnalyticsPeriod(this.label, this.maxWeeks);

  final String label;

  /// Most weekly buckets the weekly chart shows for this period.
  final int maxWeeks;

  /// Months in the monthly charts.
  int get months => switch (this) {
        weeks4 || weeks12 => 6,
        months6 => 12,
        all => 24,
      };

  /// First instant that belongs to the period, or null for [all].
  DateTime? start(DateTime now) => switch (this) {
        weeks4 => addWeeks(mondayOf(now), -3),
        weeks12 => addWeeks(mondayOf(now), -11),
        months6 => DateTime(now.year, now.month - 5),
        all => null,
      };

  /// Keeps the items whose date is inside the period (and not in the future
  /// beyond today).
  List<T> filter<T>(
    Iterable<T> items,
    DateTime Function(T) dateOf, {
    required DateTime now,
  }) {
    final from = start(now);
    return [
      for (final i in items)
        if (from == null || !dateOf(i).isBefore(from)) i,
    ];
  }
}

/// Midnight of the Monday that starts the week containing [d].
DateTime mondayOf(DateTime d) => DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));

/// [d] moved by [weeks] whole weeks, at midnight (DST safe).
DateTime addWeeks(DateTime d, int weeks) => DateTime(d.year, d.month, d.day + 7 * weeks);

/// Whole calendar days from [a] to [b] (DST safe).
int calendarDaysBetween(DateTime a, DateTime b) =>
    DateTime.utc(b.year, b.month, b.day).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

/// One bar or point of a time series.
class TimeBucket {
  const TimeBucket({required this.start, required this.count});

  /// Monday (weekly) or the 1st (monthly), at midnight.
  final DateTime start;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is TimeBucket && other.start == start && other.count == count;

  @override
  int get hashCode => Object.hash(start, count);

  @override
  String toString() => 'TimeBucket($start, $count)';
}

/// Counts per Monday-start week, oldest first, ending with the week of [now].
///
/// [weeks] buckets are produced. Dates before the first bucket or after the
/// current week are ignored.
List<TimeBucket> weeklyBuckets(
  Iterable<DateTime> dates, {
  required DateTime now,
  required int weeks,
}) {
  assert(weeks > 0);
  final thisWeek = mondayOf(now);
  final first = addWeeks(thisWeek, -(weeks - 1));
  final counts = List<int>.filled(weeks, 0);
  for (final d in dates) {
    final days = calendarDaysBetween(first, d);
    if (days < 0) continue;
    final idx = days ~/ 7;
    if (idx >= weeks) continue;
    counts[idx]++;
  }
  return [
    for (var i = 0; i < weeks; i++) TimeBucket(start: addWeeks(first, i), count: counts[i]),
  ];
}

/// Counts per calendar month, oldest first, ending with the month of [now].
List<TimeBucket> monthlyBuckets(
  Iterable<DateTime> dates, {
  required DateTime now,
  required int months,
}) {
  assert(months > 0);
  final first = DateTime(now.year, now.month - (months - 1));
  final counts = List<int>.filled(months, 0);
  for (final d in dates) {
    final idx = (d.year - first.year) * 12 + (d.month - first.month);
    if (idx < 0 || idx >= months) continue;
    counts[idx]++;
  }
  return [
    for (var i = 0; i < months; i++)
      TimeBucket(start: DateTime(first.year, first.month + i), count: counts[i]),
  ];
}

/// How many weekly buckets [period] shows: the weeks the period spans, or for
/// [AnalyticsPeriod.all] the weeks back to the oldest of [dates] (at least 4,
/// at most [AnalyticsPeriod.maxWeeks]).
int weeksFor(AnalyticsPeriod period, Iterable<DateTime> dates, DateTime now) {
  final thisWeek = mondayOf(now);
  switch (period) {
    case AnalyticsPeriod.weeks4:
      return 4;
    case AnalyticsPeriod.weeks12:
      return 12;
    case AnalyticsPeriod.months6:
      final from = mondayOf(period.start(now)!);
      return calendarDaysBetween(from, thisWeek) ~/ 7 + 1;
    case AnalyticsPeriod.all:
      DateTime? oldest;
      for (final d in dates) {
        if (oldest == null || d.isBefore(oldest)) oldest = d;
      }
      if (oldest == null) return 4;
      final w = calendarDaysBetween(mondayOf(oldest), thisWeek) ~/ 7 + 1;
      return w.clamp(4, period.maxWeeks);
    }
}

/// Months for the monthly charts: the period's months, or for
/// [AnalyticsPeriod.all] back to the oldest date (at least 6).
int monthsFor(AnalyticsPeriod period, Iterable<DateTime> dates, DateTime now) {
  if (period != AnalyticsPeriod.all) return period.months;
  DateTime? oldest;
  for (final d in dates) {
    if (oldest == null || d.isBefore(oldest)) oldest = d;
  }
  if (oldest == null) return 6;
  final m = (now.year - oldest.year) * 12 + (now.month - oldest.month) + 1;
  return m.clamp(6, period.months);
}

/// Sum of the counts in [buckets].
int bucketTotal(List<TimeBucket> buckets) => buckets.fold(0, (s, b) => s + b.count);

/// A name with a count, for horizontal bars and splits.
class LabelCount {
  const LabelCount(this.label, this.count);

  final String label;
  final int count;

  @override
  bool operator ==(Object other) =>
      other is LabelCount && other.label == label && other.count == count;

  @override
  int get hashCode => Object.hash(label, count);

  @override
  String toString() => 'LabelCount($label, $count)';
}

/// Site grades split. [ungraded] holds blank and unrecognised grades.
class GradeSplit {
  const GradeSplit({
    this.green = 0,
    this.amber = 0,
    this.red = 0,
    this.ungraded = 0,
  });

  final int green;
  final int amber;
  final int red;
  final int ungraded;

  int get total => green + amber + red + ungraded;

  @override
  bool operator ==(Object other) =>
      other is GradeSplit &&
      other.green == green &&
      other.amber == amber &&
      other.red == red &&
      other.ungraded == ungraded;

  @override
  int get hashCode => Object.hash(green, amber, red, ungraded);
}

GradeSplit gradeSplit(Iterable<String> grades) {
  var g = 0, a = 0, r = 0, u = 0;
  for (final raw in grades) {
    switch (raw.trim().toLowerCase()) {
      case 'green':
        g++;
      case 'amber' || 'yellow':
        a++;
      case 'red':
        r++;
      default:
        u++;
    }
  }
  return GradeSplit(green: g, amber: a, red: r, ungraded: u);
}

/// The [n] most frequent non-blank keys: highest count first, ties broken by
/// name (case-insensitive) so the order is stable.
List<LabelCount> topN(Iterable<String> keys, int n) {
  final counts = <String, int>{};
  for (final k in keys) {
    final key = k.trim();
    if (key.isEmpty) continue;
    counts[key] = (counts[key] ?? 0) + 1;
  }
  final out = [for (final e in counts.entries) LabelCount(e.key, e.value)]
    ..sort((a, b) {
      final c = b.count.compareTo(a.count);
      return c != 0 ? c : a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
  return out.length > n ? out.sublist(0, n) : out;
}

/// Work-order inputs the charts need.
class OrderPoint {
  const OrderPoint({required this.status, this.scheduledFor});

  final WorkOrderStatus status;
  final DateTime? scheduledFor;

  bool get isOpen =>
      status != WorkOrderStatus.completed && status != WorkOrderStatus.cancelled;
}

/// Display name for a work-order status.
String orderStatusLabel(WorkOrderStatus s) => switch (s) {
      WorkOrderStatus.draft => 'Draft',
      WorkOrderStatus.scheduled => 'Scheduled',
      WorkOrderStatus.inProgress => 'In progress',
      WorkOrderStatus.completed => 'Completed',
      WorkOrderStatus.cancelled => 'Cancelled',
    };

/// Orders per status, in lifecycle order, zeros included.
List<LabelCount> ordersByStatus(Iterable<OrderPoint> orders) {
  final counts = {for (final s in WorkOrderStatus.values) s: 0};
  for (final o in orders) {
    counts[o.status] = counts[o.status]! + 1;
  }
  return [for (final s in WorkOrderStatus.values) LabelCount(orderStatusLabel(s), counts[s]!)];
}

/// Open orders split by whether they are late. Overdue = open and scheduled
/// before today (same rule as the dashboard's workload). Open orders with no
/// date, or dated today or later, are on time.
({int onTime, int overdue}) overdueSplit(Iterable<OrderPoint> orders, DateTime today) {
  final dayStart = DateTime(today.year, today.month, today.day);
  var onTime = 0, overdue = 0;
  for (final o in orders) {
    if (!o.isOpen) continue;
    final at = o.scheduledFor;
    if (at != null && at.isBefore(dayStart)) {
      overdue++;
    } else {
      onTime++;
    }
  }
  return (onTime: onTime, overdue: overdue);
}

/// A dated maintenance record.
class MaintenancePoint {
  const MaintenancePoint({
    required this.date,
    required this.completed,
    this.requiresFollowUp = false,
  });

  final DateTime date;
  final bool completed;
  final bool requiresFollowUp;
}

/// Completed records per month.
List<TimeBucket> completedPerMonth(
  Iterable<MaintenancePoint> records, {
  required DateTime now,
  required int months,
}) =>
    monthlyBuckets(
      [for (final r in records) if (r.completed) r.date],
      now: now,
      months: months,
    );

/// In progress vs completed.
({int inProgress, int completed}) maintenanceSplit(Iterable<MaintenancePoint> records) {
  var done = 0, open = 0;
  for (final r in records) {
    r.completed ? done++ : open++;
  }
  return (inProgress: open, completed: done);
}

/// A scheduled task, for the workload chart.
class TaskPoint {
  const TaskPoint({required this.when, required this.status, this.assignee});

  final DateTime when;
  final String status;
  final String? assignee;
}

/// Tasks per technician in the Monday-start week of [now], busiest first.
///
/// [roster] technicians with nothing this week are listed with 0 (a
/// dispatcher wants to see who is free). Cancelled tasks are ignored.
/// Unassigned tasks are one "Unassigned" row. Names come from [names]; an
/// unknown id gets "Technician" plus its first 4 characters. At most [limit]
/// rows; ties are ordered by name.
List<LabelCount> tasksPerTechnician(
  Iterable<TaskPoint> tasks, {
  required DateTime now,
  required Map<String, String> names,
  Iterable<String> roster = const [],
  int limit = 8,
}) {
  final from = mondayOf(now);
  final to = addWeeks(from, 1);
  final counts = <String, int>{for (final id in roster) id: 0};
  var unassigned = 0;
  for (final t in tasks) {
    if (t.status == 'cancelled') continue;
    if (t.when.isBefore(from) || !t.when.isBefore(to)) continue;
    final id = t.assignee;
    if (id == null || id.isEmpty) {
      unassigned++;
    } else {
      counts[id] = (counts[id] ?? 0) + 1;
    }
  }
  String nameOf(String id) {
    final n = names[id];
    if (n != null && n.trim().isNotEmpty) return n.trim();
    return 'Technician ${id.length > 4 ? id.substring(0, 4) : id}';
  }

  final rows = [
    for (final e in counts.entries) LabelCount(nameOf(e.key), e.value),
    if (unassigned > 0) LabelCount('Unassigned', unassigned),
  ]..sort((a, b) {
      final c = b.count.compareTo(a.count);
      return c != 0 ? c : a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
  return rows.length > limit ? rows.sublist(0, limit) : rows;
}

/// Parts by stock state.
class StockSplit {
  const StockSplit({this.ok = 0, this.low = 0, this.out = 0});

  final int ok;
  final int low;
  final int out;

  int get total => ok + low + out;

  @override
  bool operator ==(Object other) =>
      other is StockSplit && other.ok == ok && other.low == low && other.out == out;

  @override
  int get hashCode => Object.hash(ok, low, out);
}

/// Short date label, e.g. "3 Nov".
String shortDate(DateTime d) => '${d.day} ${monthAbbr(d.month)}';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Jan".."Dec" for month 1..12 (month 13 wraps to Jan, 0 to Dec).
String monthAbbr(int month) => _months[(month - 1) % 12];
