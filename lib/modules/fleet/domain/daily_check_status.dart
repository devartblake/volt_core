import 'entities/vehicle_inspection.dart';

/// Where today's daily vehicle check stands.
enum DailyCheckState {
  /// A daily (or longer) inspection was recorded today.
  doneToday,

  /// Not done today, but nothing was missed yesterday (or never started).
  due,

  /// More than a day has passed since the last check.
  overdue,
}

/// Pure function: today's daily-check state from a vehicle's [inspections]
/// (any order, one vehicle). Reuses [InspectionStatus.compute], so a weekly or
/// monthly walk-around today also counts as the daily check.
///
/// - done today -> [DailyCheckState.doneToday]
/// - never checked -> [DailyCheckState.due]
/// - last check yesterday -> [DailyCheckState.due]
/// - last check before yesterday -> [DailyCheckState.overdue]
DailyCheckState dailyCheckState(
  Iterable<VehicleInspection> inspections, {
  DateTime? now,
}) {
  final clock = now ?? DateTime.now();
  final status = InspectionStatus.compute(
    InspectionCadence.daily,
    inspections,
    now: clock,
  );
  switch (status.state) {
    case InspectionDueState.ok:
      return DailyCheckState.doneToday;
    case InspectionDueState.never:
      return DailyCheckState.due;
    case InspectionDueState.dueSoon:
    case InspectionDueState.overdue:
      final last = status.lastAt!;
      final today = DateTime(clock.year, clock.month, clock.day);
      final lastDay = DateTime(last.year, last.month, last.day);
      final missedDays = today.difference(lastDay).inDays;
      return missedDays <= 1 ? DailyCheckState.due : DailyCheckState.overdue;
  }
}
