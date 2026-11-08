/// Series behind the small graphs on the readiness number cards. Pure Dart.
library;

import 'readiness_models.dart';
import 'readiness_summary.dart';

/// One slice of a reason breakdown.
class ReasonCount {
  const ReasonCount(this.kind, this.label, this.count);

  final ReadinessReasonKind kind;

  /// Short label for a legend or a screen reader ("Amber grade").
  final String label;
  final int count;
}

/// The reasons shown on the Attention tile, in this order.
const attentionReasonKinds = <ReadinessReasonKind, String>{
  ReadinessReasonKind.amberGrade: 'Amber grade',
  ReadinessReasonKind.overdue: 'Overdue',
  ReadinessReasonKind.followUps: 'Follow-ups',
  ReadinessReasonKind.partsShort: 'Parts short',
};

/// The reasons shown on the Not ready tile, in this order.
const notReadyReasonKinds = <ReadinessReasonKind, String>{
  ReadinessReasonKind.redGrade: 'Red grade',
  ReadinessReasonKind.overdue: 'Long overdue',
  ReadinessReasonKind.neverInspected: 'Never inspected',
};

/// For the units whose status is [status], how many carry each reason of
/// [kinds]. A unit with two reasons counts once under each, so the total can
/// exceed the number of units. Every kind is present (0 when none).
List<ReasonCount> reasonCountsForStatus(
  List<ReadinessUnit> units,
  ReadinessStatus status,
  Map<ReadinessReasonKind, String> kinds,
) {
  final counts = {for (final k in kinds.keys) k: 0};
  for (final u in units) {
    if (u.status != status) continue;
    final seen = <ReadinessReasonKind>{};
    for (final r in u.reasons) {
      if (counts.containsKey(r.kind) && seen.add(r.kind)) {
        counts[r.kind] = counts[r.kind]! + 1;
      }
    }
  }
  return [
    for (final e in kinds.entries) ReasonCount(e.key, e.value, counts[e.key]!),
  ];
}

/// Reasons behind the Attention count.
List<ReasonCount> attentionReasonCounts(List<ReadinessUnit> units) =>
    reasonCountsForStatus(units, ReadinessStatus.attention, attentionReasonKinds);

/// Reasons behind the Not ready count.
List<ReasonCount> notReadyReasonCounts(List<ReadinessUnit> units) =>
    reasonCountsForStatus(units, ReadinessStatus.notReady, notReadyReasonKinds);

/// One week of the Due soon strip.
class DueWeekPoint {
  const DueWeekPoint(this.weekStart, this.count, this.inWindow);

  /// Monday, local midnight.
  final DateTime weekStart;
  final int count;

  /// True when the week overlaps the due-soon window (today to today +
  /// `dueSoonDays`).
  final bool inWindow;
}

/// The next [weeks] weeks of [buckets] (the first is the week containing
/// today), each flagged when it overlaps the due-soon window.
List<DueWeekPoint> dueSoonWeekSlice(
  List<DueWeekBucket> buckets,
  DateTime now,
  int dueSoonDays, {
  int weeks = 12,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final windowEnd = DateTime(today.year, today.month, today.day + dueSoonDays);
  return [
    for (final b in buckets.take(weeks))
      DueWeekPoint(
        b.weekStart,
        b.count,
        // The week is Monday .. Sunday; it overlaps when it starts on or
        // before the window's last day and ends on or after today.
        !b.weekStart.isAfter(windowEnd) &&
            !DateTime(b.weekStart.year, b.weekStart.month, b.weekStart.day + 6)
                .isBefore(today),
      ),
  ];
}

/// Share of the fleet (0..1) with this [status]; 0 for an empty fleet.
double statusShare(ReadinessSummary s, ReadinessStatus status) =>
    s.total == 0 ? 0.0 : s.count(status) / s.total;

/// Units whose due date is an estimate (no next-due date was recorded).
int estimatedDueCount(List<ReadinessUnit> units) =>
    units.where((u) => u.dueIsEstimated).length;

/// True when no unit has anything in the Overdue bar or the 12 weeks.
bool dueChartIsEmpty(ReadinessSummary s) =>
    s.overdueCount == 0 && s.dueByWeek.every((b) => b.count == 0);
