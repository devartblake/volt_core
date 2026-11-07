import '../domain/entities/inspection_entity.dart';

/// How the inspections list is narrowed by date.
enum InspectionPeriod {
  /// Everything, newest first, grouped by month.
  all,

  /// One calendar day (today until another day is picked).
  day,

  /// A Monday-to-Sunday week.
  week,

  /// A calendar month.
  month,
}

/// A titled run of items (anything with a date) under one heading.
class DateGroup<T> {
  const DateGroup(this.title, this.items);

  final String title;
  final List<T> items;
}

/// A titled run of inspections, as shown under one heading in the list.
class InspectionGroup {
  const InspectionGroup(this.title, this.items);

  final String title;
  final List<InspectionEntity> items;
}

/// The date filter for the inspections list: a [period] plus the date it is
/// anchored on, so "week" means *the week containing [anchor]* and stepping
/// back or forward moves by whole weeks or months.
///
/// Pure value logic with no widgets, so the rules can be tested directly.
/// Dates are compared as the plain year/month/day stored on the inspection's
/// service date, the same way the list prints them, so a record never appears
/// under a different day than the one written on it.
class InspectionDateFilter {
  const InspectionDateFilter._(this.period, this.anchor);

  /// No filtering.
  const InspectionDateFilter.all() : this._(InspectionPeriod.all, null);

  /// [anchor] is normalised to midnight.
  factory InspectionDateFilter.of(InspectionPeriod period, DateTime anchor) =>
      InspectionDateFilter._(period, _dayOnly(anchor));

  final InspectionPeriod period;
  final DateTime? anchor;

  bool get isAll => period == InspectionPeriod.all;

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// First day included.
  DateTime? get start {
    final a = anchor;
    if (a == null) return null;
    switch (period) {
      case InspectionPeriod.all:
        return null;
      case InspectionPeriod.day:
        return a;
      case InspectionPeriod.week:
        // DateTime.weekday: Monday = 1 ... Sunday = 7.
        return a.subtract(Duration(days: a.weekday - DateTime.monday));
      case InspectionPeriod.month:
        return DateTime(a.year, a.month, 1);
    }
  }

  /// Last day included.
  DateTime? get end {
    final s = start;
    if (s == null) return null;
    switch (period) {
      case InspectionPeriod.all:
        return null;
      case InspectionPeriod.day:
        return s;
      case InspectionPeriod.week:
        return DateTime(s.year, s.month, s.day + 6);
      case InspectionPeriod.month:
        // Day 0 of the next month is the last day of this one.
        return DateTime(s.year, s.month + 1, 0);
    }
  }

  bool matches(DateTime serviceDate) {
    final s = start;
    final e = end;
    if (s == null || e == null) return true;
    final d = _dayOnly(serviceDate);
    return !d.isBefore(s) && !d.isAfter(e);
  }

  /// Moves a week or month filter by [steps] (negative = earlier). A single
  /// day moves by days. [all] is unchanged.
  InspectionDateFilter shifted(int steps) {
    final a = anchor;
    if (a == null) return this;
    switch (period) {
      case InspectionPeriod.all:
        return this;
      case InspectionPeriod.day:
        return InspectionDateFilter.of(
            period, DateTime(a.year, a.month, a.day + steps));
      case InspectionPeriod.week:
        return InspectionDateFilter.of(
            period, DateTime(a.year, a.month, a.day + 7 * steps));
      case InspectionPeriod.month:
        return InspectionDateFilter.of(
            period, DateTime(a.year, a.month + steps, 1));
    }
  }

  /// Switches period but stays on the same moment in time.
  InspectionDateFilter withPeriod(InspectionPeriod next, {DateTime? today}) {
    if (next == InspectionPeriod.all) return const InspectionDateFilter.all();
    return InspectionDateFilter.of(next, anchor ?? today ?? DateTime.now());
  }

  /// Short human label: "All dates", "Tue, Nov 3, 2026", "Oct 26 - Nov 1,
  /// 2026" or "November 2026".
  String get label {
    final s = start;
    final e = end;
    if (s == null || e == null) return 'All dates';
    switch (period) {
      case InspectionPeriod.all:
        return 'All dates';
      case InspectionPeriod.day:
        return '${_weekdays[s.weekday - 1]}, ${_months[s.month - 1].substring(0, 3)} ${s.day}, ${s.year}';
      case InspectionPeriod.week:
        final from = '${_months[s.month - 1].substring(0, 3)} ${s.day}';
        final to = s.month == e.month
            ? '${e.day}'
            : '${_months[e.month - 1].substring(0, 3)} ${e.day}';
        return '$from - $to, ${e.year}';
      case InspectionPeriod.month:
        return '${_months[s.month - 1]} ${s.year}';
    }
  }

  /// Whether [today] falls inside the filter, for a "current" marker.
  bool containsToday(DateTime today) => matches(today);

  /// Narrow any dated [items] to this filter, newest first. [thenBy] orders
  /// items that fall on the same instant.
  List<T> applyBy<T>(
    Iterable<T> items,
    DateTime Function(T) dateOf, {
    int Function(T a, T b)? thenBy,
  }) {
    return items.where((i) => matches(dateOf(i))).toList()
      ..sort((a, b) {
        final byDate = dateOf(b).compareTo(dateOf(a));
        if (byDate != 0 || thenBy == null) return byDate;
        return thenBy(a, b);
      });
  }

  /// Dated [items] (already filtered and newest first) under one heading per
  /// day; the heading carries the year when browsing all dates.
  List<DateGroup<T>> groupByDay<T>(
    List<T> items,
    DateTime Function(T) dateOf,
  ) {
    final withYear = period == InspectionPeriod.all;
    final groups = <DateGroup<T>>[];
    String? currentKey;
    List<T>? bucket;

    for (final item in items) {
      final d = dateOf(item);
      final key = '${d.year}-${d.month}-${d.day}';
      if (key != currentKey) {
        currentKey = key;
        bucket = <T>[];
        final day = '${_weekdays[_dayOnly(d).weekday - 1]}, '
            '${_months[d.month - 1].substring(0, 3)} ${d.day}';
        groups.add(DateGroup<T>(withYear ? '$day, ${d.year}' : day, bucket));
      }
      bucket!.add(item);
    }
    return groups;
  }

  /// Narrow [items] to this filter and order them newest first.
  List<InspectionEntity> apply(Iterable<InspectionEntity> items) {
    final out = items.where((i) => matches(i.serviceDate)).toList()
      ..sort((a, b) {
        final byDate = b.serviceDate.compareTo(a.serviceDate);
        // Same day: most recently created first, so today's newest is on top.
        return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
      });
    return out;
  }

  /// [items] (already filtered and sorted) under one heading per day. When
  /// browsing everything the heading carries the year too, since the list can
  /// span several.
  List<InspectionGroup> group(List<InspectionEntity> items) {
    final withYear = period == InspectionPeriod.all;
    final groups = <InspectionGroup>[];
    String? currentKey;
    List<InspectionEntity>? bucket;

    for (final i in items) {
      final d = i.serviceDate;
      final key = '${d.year}-${d.month}-${d.day}';
      if (key != currentKey) {
        currentKey = key;
        bucket = <InspectionEntity>[];
        final day = '${_weekdays[_dayOnly(d).weekday - 1]}, '
            '${_months[d.month - 1].substring(0, 3)} ${d.day}';
        final title = withYear ? '$day, ${d.year}' : day;
        groups.add(InspectionGroup(title, bucket));
      }
      bucket!.add(i);
    }
    return groups;
  }

  static const _weekdays = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June', 'July',
    'August', 'September', 'October', 'November', 'December',
  ];
}
