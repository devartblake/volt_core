/// Totals, filtering and sorting over computed [ReadinessUnit]s. Pure Dart.
library;

import 'readiness_join.dart';
import 'readiness_models.dart';
import 'readiness_rules.dart' show compareWorstFirst;

/// Fleet-level numbers for the top of the dashboard.
class ReadinessSummary {
  const ReadinessSummary({
    required this.total,
    required this.counts,
    required this.percentReady,
    required this.overdueCount,
    required this.dueSoonCount,
    required this.gradeCounts,
    required this.dueByWeek,
    required this.dueLater,
    required this.worstUnits,
    required this.followUpCount,
    required this.partsShortUnits,
  });

  final int total;

  /// Every status is present (0 when none).
  final Map<ReadinessStatus, int> counts;

  /// 0..100. 0.0 when there are no units (an empty fleet is not "100% ready").
  final double percentReady;

  /// Units whose next inspection is past due (any amount).
  final int overdueCount;

  /// Units with status [ReadinessStatus.dueSoon].
  final int dueSoonCount;

  /// Every grade is present, including [ReadinessGrade.none].
  final Map<ReadinessGrade, int> gradeCounts;

  /// 12 buckets, the first being the Monday-start week that contains today.
  /// Units already overdue are not in any bucket (see [overdueCount]).
  final List<DueWeekBucket> dueByWeek;

  /// Due after the 12th week.
  final int dueLater;

  /// The worst few units, worst first.
  final List<ReadinessUnit> worstUnits;

  /// Open follow-ups across the fleet.
  final int followUpCount;

  /// Units with at least one short part.
  final int partsShortUnits;

  int count(ReadinessStatus s) => counts[s] ?? 0;

  static const empty = ReadinessSummary(
    total: 0,
    counts: {
      ReadinessStatus.notReady: 0,
      ReadinessStatus.attention: 0,
      ReadinessStatus.dueSoon: 0,
      ReadinessStatus.ready: 0,
    },
    percentReady: 0,
    overdueCount: 0,
    dueSoonCount: 0,
    gradeCounts: {
      ReadinessGrade.green: 0,
      ReadinessGrade.amber: 0,
      ReadinessGrade.red: 0,
      ReadinessGrade.none: 0,
    },
    dueByWeek: [],
    dueLater: 0,
    worstUnits: [],
    followUpCount: 0,
    partsShortUnits: 0,
  );
}

/// Monday (local midnight) of the week containing [d].
DateTime mondayOf(DateTime d) {
  final x = dayOf(d);
  return DateTime(x.year, x.month, x.day - (x.weekday - DateTime.monday));
}

/// Summarises [units] as of [now]. [worstCount] bounds [ReadinessSummary.worstUnits];
/// only units that are not [ReadinessStatus.ready] qualify.
ReadinessSummary summarizeReadiness(
  List<ReadinessUnit> units,
  DateTime now, {
  int worstCount = 5,
  int weeks = 12,
}) {
  final counts = {for (final s in ReadinessStatus.values) s: 0};
  final grades = {for (final g in ReadinessGrade.values) g: 0};
  final buckets = List<int>.filled(weeks, 0);
  final start = mondayOf(now);
  var overdue = 0, later = 0, followUps = 0, partsUnits = 0;

  for (final u in units) {
    counts[u.status] = counts[u.status]! + 1;
    grades[u.lastGrade] = grades[u.lastGrade]! + 1;
    followUps += u.followUpCount;
    if (u.partsShortCount > 0) partsUnits++;
    final due = u.nextDueAt;
    final days = u.daysToDue;
    if (due == null || days == null) continue;
    if (days < 0) {
      overdue++;
      continue;
    }
    final offset = daysBetween(start, due);
    if (offset < 0) continue; // cannot happen when days >= 0
    final w = offset ~/ 7;
    if (w < weeks) {
      buckets[w]++;
    } else {
      later++;
    }
  }

  final worst = [
    for (final u in units)
      if (u.status != ReadinessStatus.ready) u,
  ]..sort(compareWorstFirst);

  return ReadinessSummary(
    total: units.length,
    counts: Map.unmodifiable(counts),
    percentReady: units.isEmpty
        ? 0.0
        : counts[ReadinessStatus.ready]! * 100.0 / units.length,
    overdueCount: overdue,
    dueSoonCount: counts[ReadinessStatus.dueSoon]!,
    gradeCounts: Map.unmodifiable(grades),
    dueByWeek: List.unmodifiable([
      for (var w = 0; w < weeks; w++)
        DueWeekBucket(DateTime(start.year, start.month, start.day + 7 * w), buckets[w]),
    ]),
    dueLater: later,
    worstUnits: List.unmodifiable(worst.take(worstCount)),
    followUpCount: followUps,
    partsShortUnits: partsUnits,
  );
}

/// How soon the next inspection is due.
enum ReadinessDueWindow {
  overdue('Overdue'),
  next7('Next 7 days'),
  next30('Next 30 days'),
  next90('Next 90 days');

  const ReadinessDueWindow(this.label);

  final String label;

  bool matches(int? daysToDue) {
    if (daysToDue == null) return false;
    switch (this) {
      case overdue:
        return daysToDue < 0;
      case next7:
        return daysToDue >= 0 && daysToDue <= 7;
      case next30:
        return daysToDue >= 0 && daysToDue <= 30;
      case next90:
        return daysToDue >= 0 && daysToDue <= 90;
    }
  }
}

enum ReadinessSort {
  /// Worst status, then most overdue.
  worstFirst('Worst first'),

  /// Earliest due date first; no date last.
  nextDue('Next due'),

  /// Oldest inspection first (never inspected at the top).
  lastInspection('Last inspected'),

  /// A to Z.
  title('Name');

  const ReadinessSort(this.label);

  final String label;
}

/// A set of optional conditions; all that are set must hold. [isEmpty] when
/// none are.
class ReadinessFilter {
  const ReadinessFilter({
    this.statuses = const {},
    this.query = '',
    this.make,
    this.borough,
    this.dueWindow,
    this.hasFollowUps,
    this.grade,
    this.dueWeekStart,
  });

  /// Empty = any status.
  final Set<ReadinessStatus> statuses;

  /// Words, all of which must appear (case-insensitive) in the title, site
  /// code, address, serial or customer.
  final String query;
  final String? make;
  final String? borough;
  final ReadinessDueWindow? dueWindow;

  /// true = only units with follow-ups; false = only units without.
  final bool? hasFollowUps;
  final ReadinessGrade? grade;

  /// Only units whose next inspection falls in the Monday-start week that
  /// begins on this date (used by the due-by-week chart).
  final DateTime? dueWeekStart;

  bool get isEmpty =>
      statuses.isEmpty &&
      query.trim().isEmpty &&
      make == null &&
      borough == null &&
      dueWindow == null &&
      hasFollowUps == null &&
      grade == null &&
      dueWeekStart == null;

  ReadinessFilter copyWith({
    Set<ReadinessStatus>? statuses,
    String? query,
    String? make,
    String? borough,
    ReadinessDueWindow? dueWindow,
    bool? hasFollowUps,
    ReadinessGrade? grade,
    DateTime? dueWeekStart,
    bool clearDueWeek = false,
    bool clearMake = false,
    bool clearBorough = false,
    bool clearDueWindow = false,
    bool clearHasFollowUps = false,
    bool clearGrade = false,
  }) =>
      ReadinessFilter(
        statuses: statuses ?? this.statuses,
        query: query ?? this.query,
        make: clearMake ? null : (make ?? this.make),
        borough: clearBorough ? null : (borough ?? this.borough),
        dueWindow: clearDueWindow ? null : (dueWindow ?? this.dueWindow),
        hasFollowUps: clearHasFollowUps ? null : (hasFollowUps ?? this.hasFollowUps),
        grade: clearGrade ? null : (grade ?? this.grade),
        dueWeekStart:
            clearDueWeek ? null : (dueWeekStart ?? this.dueWeekStart),
      );

  bool matches(ReadinessUnit u) {
    if (statuses.isNotEmpty && !statuses.contains(u.status)) return false;
    if (make != null && u.make.trim().toLowerCase() != make!.trim().toLowerCase()) {
      return false;
    }
    if (borough != null &&
        u.borough.toLowerCase() != borough!.trim().toLowerCase()) {
      return false;
    }
    if (dueWindow != null && !dueWindow!.matches(u.daysToDue)) return false;
    if (hasFollowUps != null && u.hasFollowUps != hasFollowUps) return false;
    if (grade != null && u.lastGrade != grade) return false;
    if (dueWeekStart != null) {
      final due = u.nextDueAt;
      if (due == null) return false;
      final offset = daysBetween(dueWeekStart!, due);
      if (offset < 0 || offset >= 7) return false;
    }
    final words = query.trim().toLowerCase().split(RegExp(r'\s+'))
      ..removeWhere((w) => w.isEmpty);
    if (words.isNotEmpty) {
      final hay = '${u.title} ${u.siteCode} ${u.address} ${u.serial} ${u.customer}'
          .toLowerCase();
      for (final w in words) {
        if (!hay.contains(w)) return false;
      }
    }
    return true;
  }

  /// The matching units, in the order given.
  List<ReadinessUnit> apply(Iterable<ReadinessUnit> units) =>
      [for (final u in units) if (matches(u)) u];

  @override
  bool operator ==(Object other) =>
      other is ReadinessFilter &&
      other.query == query &&
      other.make == make &&
      other.borough == borough &&
      other.dueWindow == dueWindow &&
      other.hasFollowUps == hasFollowUps &&
      other.grade == grade &&
      other.dueWeekStart == dueWeekStart &&
      other.statuses.length == statuses.length &&
      other.statuses.containsAll(statuses);

  @override
  int get hashCode => Object.hash(
      query, make, borough, dueWindow, hasFollowUps, grade, dueWeekStart,
      statuses.length);
}

/// The distinct makes / boroughs present, sorted, for filter menus.
List<String> distinctMakes(Iterable<ReadinessUnit> units) => _distinct(units.map((u) => u.make));
List<String> distinctBoroughs(Iterable<ReadinessUnit> units) =>
    _distinct(units.map((u) => u.borough));

List<String> _distinct(Iterable<String> values) {
  final seen = <String, String>{};
  for (final v in values) {
    final t = v.trim();
    if (t.isNotEmpty) seen.putIfAbsent(t.toLowerCase(), () => t);
  }
  return seen.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
}

/// [units] sorted by [sort]. Always a total order (ties fall back to title,
/// then key), so the result does not depend on the input order.
List<ReadinessUnit> sortReadiness(Iterable<ReadinessUnit> units, ReadinessSort sort) {
  int byTitle(ReadinessUnit a, ReadinessUnit b) {
    final t = a.title.toLowerCase().compareTo(b.title.toLowerCase());
    return t != 0 ? t : a.key.compareTo(b.key);
  }

  int nullsLast(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return dayOf(a).compareTo(dayOf(b));
  }

  int nullsFirst(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;
    return dayOf(a).compareTo(dayOf(b));
  }

  final list = units.toList();
  switch (sort) {
    case ReadinessSort.worstFirst:
      list.sort(compareWorstFirst);
    case ReadinessSort.nextDue:
      list.sort((a, b) {
        final c = nullsLast(a.nextDueAt, b.nextDueAt);
        return c != 0 ? c : byTitle(a, b);
      });
    case ReadinessSort.lastInspection:
      list.sort((a, b) {
        final c = nullsFirst(a.lastInspectionAt, b.lastInspectionAt);
        return c != 0 ? c : byTitle(a, b);
      });
    case ReadinessSort.title:
      list.sort(byTitle);
  }
  return list;
}
