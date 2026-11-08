import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/dashboard/domain/analytics_mini_series.dart';
import 'package:voltcore/modules/dashboard/domain/analytics_series.dart';
import 'package:voltcore/modules/dashboard/domain/analytics_snapshot.dart';

// Sunday 8 Nov 2026.
final _now = DateTime(2026, 11, 8, 15);

TaskPoint _task(DateTime when, [String status = 'scheduled']) =>
    TaskPoint(when: when, status: status);

void main() {
  group('daysInMonth', () {
    test('28 to 31, leap years', () {
      expect(daysInMonth(DateTime(2026, 2, 10)), 28);
      expect(daysInMonth(DateTime(2028, 2, 29)), 29);
      expect(daysInMonth(DateTime(2026, 4, 1)), 30);
      expect(daysInMonth(DateTime(2026, 12, 31)), 31);
      expect(daysInMonth(DateTime(2100, 2, 1)), 28);
    });
  });

  group('dailyCounts', () {
    test('empty input is all zero with the requested length', () {
      expect(dailyCounts(const [], start: _now, days: 7), List.filled(7, 0));
    });

    test('window edges: first day in, day after the last out, before start out', () {
      final r = dailyCounts([
        DateTime(2026, 11, 7, 23, 59), // day before start
        DateTime(2026, 11, 8, 0, 0), // day 0
        DateTime(2026, 11, 8, 23, 59), // day 0
        DateTime(2026, 11, 14, 23, 59), // day 6
        DateTime(2026, 11, 15), // outside
      ], start: _now, days: 7);
      expect(r, [2, 0, 0, 0, 0, 0, 1]);
    });

    test('is calendar based across the DST change (US, 1 Nov 2026)', () {
      final r = dailyCounts([DateTime(2026, 11, 2, 0, 30)],
          start: DateTime(2026, 10, 30), days: 5);
      expect(r, [0, 0, 0, 1, 0]);
    });
  });

  group('dailyCountsThisMonth', () {
    test('length follows the month (28, 29, 30, 31)', () {
      expect(dailyCountsThisMonth(const [], DateTime(2026, 2, 5)).length, 28);
      expect(dailyCountsThisMonth(const [], DateTime(2028, 2, 5)).length, 29);
      expect(dailyCountsThisMonth(const [], DateTime(2026, 11, 5)).length, 30);
      expect(dailyCountsThisMonth(const [], DateTime(2026, 12, 5)).length, 31);
    });

    test('first and last day of the month, other months ignored', () {
      final r = dailyCountsThisMonth([
        DateTime(2026, 10, 31, 23, 59),
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 1, 18),
        DateTime(2026, 11, 30, 23, 59),
        DateTime(2026, 12, 1),
      ], _now);
      expect(r.length, 30);
      expect(r.first, 2);
      expect(r.last, 1);
      expect(r.fold<int>(0, (a, b) => a + b), 3);
    });

    test('inspectionsCreatedThisMonth uses createdAt, not the service date', () {
      final r = inspectionsCreatedThisMonth([
        InspectionPoint(
            date: DateTime(2026, 9, 1), createdAt: DateTime(2026, 11, 8), grade: 'green'),
        InspectionPoint(
            date: DateTime(2026, 11, 8), createdAt: DateTime(2026, 9, 1), grade: 'green'),
      ], _now);
      expect(r[7], 1);
      expect(r.fold<int>(0, (a, b) => a + b), 1);
    });
  });

  group('task dates and next days', () {
    final tasks = [
      _task(DateTime(2026, 11, 8, 16)), // upcoming today
      _task(DateTime(2026, 11, 8, 9)), // earlier today: overdue
      _task(DateTime(2026, 11, 9), 'overdue'),
      _task(DateTime(2026, 11, 10), 'completed'),
      _task(DateTime(2026, 11, 10), 'cancelled'),
      _task(DateTime(2026, 11, 20)),
    ];

    test('match the numbers on the Upcoming and Overdue cards', () {
      final m = AnalyticsMetrics.from(AnalyticsSnapshot(tasks: tasks), _now);
      expect(upcomingTaskDates(tasks, _now).length, m.upcomingTasks);
      expect(overdueTaskDates(tasks, _now).length, m.overdueTasks);
      expect(m.upcomingTasks, 3);
      expect(m.overdueTasks, 1);
    });

    test('next 7 days start today; later and finished tasks are left out', () {
      expect(nextDaysCounts(tasks, _now), [1, 1, 0, 0, 0, 0, 0]);
      expect(nextDaysCounts(tasks, _now, days: 12).length, 12);
      expect(nextDaysCounts(tasks, _now, days: 12).last, 0); // 20 Nov is day 12
      expect(nextDaysCounts(tasks, _now, days: 13).last, 1);
      expect(nextDaysCounts(const [], _now), List.filled(7, 0));
    });
  });

  group('overdueAges', () {
    test('empty', () {
      expect(overdueAges(const [], _now), const OverdueAges());
      expect(const OverdueAges().total, 0);
    });

    test('boundaries: 0, 7 | 8, 30 | 31 days', () {
      final r = overdueAges([
        DateTime(2026, 11, 8, 9), // 0 days
        DateTime(2026, 11, 1), // 7
        DateTime(2026, 10, 31), // 8
        DateTime(2026, 10, 9), // 30
        DateTime(2026, 10, 8), // 31
        DateTime(2025, 1, 1),
      ], _now);
      expect(r, const OverdueAges(week: 2, month: 2, older: 2));
      expect(r.total, 6);
    });

    test('a future date counts as not late', () {
      expect(overdueAges([DateTime(2026, 12, 1)], _now).week, 1);
    });
  });

  group('share', () {
    test('zero whole, bounds and rounding', () {
      expect(share(0, 0), 0);
      expect(share(3, 0), 0);
      expect(share(5, 4), 1);
      expect(share(-1, 4), 0);
      expect(percentOf(1, 3), 33);
      expect(percentOf(2, 3), 67);
      expect(percentOf(1, 2), 50);
    });
  });
}
