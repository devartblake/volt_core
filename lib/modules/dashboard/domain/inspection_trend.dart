/// Number of inspections per calendar day for the last [days] days, oldest
/// first, ending with the day of [now]. Dates outside the window (older, or in
/// the future) are ignored. Pure.
List<int> dailyCounts(
  Iterable<DateTime> dates, {
  required DateTime now,
  int days = 7,
}) {
  assert(days > 0);
  final today = DateTime(now.year, now.month, now.day);
  final counts = List<int>.filled(days, 0);
  for (final d in dates) {
    final day = DateTime(d.year, d.month, d.day);
    // Calendar-day difference, safe across DST changes.
    final ago = DateTime.utc(today.year, today.month, today.day)
        .difference(DateTime.utc(day.year, day.month, day.day))
        .inDays;
    if (ago < 0 || ago >= days) continue;
    counts[days - 1 - ago]++;
  }
  return counts;
}

/// Screen-reader text for a trend, e.g.
/// "Inspections per day, last 7 days: 1, 0, 2, 0, 0, 3, 1".
String trendSemanticLabel(String what, List<int> counts) =>
    '$what per day, last ${counts.length} days: ${counts.join(', ')}';
