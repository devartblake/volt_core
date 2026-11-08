import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/dashboard/domain/analytics_series.dart';
import 'package:voltcore/modules/dashboard/domain/analytics_snapshot.dart';
import 'package:voltcore/modules/work_orders/domain/entities/work_order_entity.dart';

// Sunday 8 Nov 2026: the last day of the week that starts Monday 2 Nov.
final _now = DateTime(2026, 11, 8, 15);

void main() {
  group('mondayOf / addWeeks', () {
    test('Monday stays, Sunday goes back six days, at midnight', () {
      expect(mondayOf(DateTime(2026, 11, 2, 9)), DateTime(2026, 11, 2));
      expect(mondayOf(DateTime(2026, 11, 8, 23, 59)), DateTime(2026, 11, 2));
      expect(mondayOf(DateTime(2026, 11, 4)), DateTime(2026, 11, 2));
    });

    test('crosses month and year edges', () {
      expect(mondayOf(DateTime(2027, 1, 1)), DateTime(2026, 12, 28));
      expect(mondayOf(DateTime(2026, 3, 1)), DateTime(2026, 2, 23));
    });

    test('addWeeks is calendar arithmetic across DST', () {
      // US clocks go back on Sun 1 Nov 2026; Duration math would land on 23:00.
      expect(addWeeks(DateTime(2026, 10, 26), 1), DateTime(2026, 11, 2));
      expect(addWeeks(DateTime(2026, 11, 2), -1), DateTime(2026, 10, 26));
      expect(addWeeks(DateTime(2026, 3, 2), 2), DateTime(2026, 3, 16));
    });
  });

  group('weeklyBuckets', () {
    test('empty input gives zero-filled buckets, oldest first', () {
      final b = weeklyBuckets(const [], now: _now, weeks: 3);
      expect(b.map((e) => e.start), [
        DateTime(2026, 10, 19),
        DateTime(2026, 10, 26),
        DateTime(2026, 11, 2),
      ]);
      expect(b.map((e) => e.count), [0, 0, 0]);
    });

    test('Sunday night and Monday midnight fall in different weeks', () {
      final b = weeklyBuckets([
        DateTime(2026, 11, 1, 23, 59), // Sunday, week of 26 Oct (and DST day)
        DateTime(2026, 11, 2), // Monday, week of 2 Nov
        DateTime(2026, 11, 8, 23, 59), // Sunday, week of 2 Nov
      ], now: _now, weeks: 2);
      expect(b.map((e) => e.count), [1, 2]);
    });

    test('ignores dates before the first bucket and in the future', () {
      final b = weeklyBuckets([
        DateTime(2026, 10, 25, 23, 59), // week before the window
        DateTime(2026, 11, 9), // next Monday
        DateTime(2027, 1, 1),
        DateTime(2026, 10, 26),
      ], now: _now, weeks: 2);
      expect(b.map((e) => e.count), [1, 0]);
    });

    test('spans the year edge', () {
      final now = DateTime(2027, 1, 3); // Sunday; week of Mon 28 Dec 2026
      final b = weeklyBuckets([
        DateTime(2026, 12, 31),
        DateTime(2027, 1, 1),
        DateTime(2026, 12, 27),
      ], now: now, weeks: 2);
      expect(b.map((e) => e.start), [DateTime(2026, 12, 21), DateTime(2026, 12, 28)]);
      expect(b.map((e) => e.count), [1, 2]);
    });

    test('a spring-forward week still counts all seven days', () {
      final now = DateTime(2026, 3, 15); // Sunday after 8 Mar DST start
      final dates = [for (var d = 9; d <= 15; d++) DateTime(2026, 3, d, 12)];
      expect(weeklyBuckets(dates, now: now, weeks: 1).single.count, 7);
    });
  });

  group('monthlyBuckets', () {
    test('empty input', () {
      final b = monthlyBuckets(const [], now: _now, months: 3);
      expect(b.map((e) => e.start), [
        DateTime(2026, 9),
        DateTime(2026, 10),
        DateTime(2026, 11),
      ]);
      expect(bucketTotal(b), 0);
    });

    test('month end and start land in their own months', () {
      final b = monthlyBuckets([
        DateTime(2026, 10, 31, 23, 59),
        DateTime(2026, 11, 1),
        DateTime(2026, 11, 30, 23, 59),
        DateTime(2026, 12, 1), // future
        DateTime(2026, 8, 31), // before the window
      ], now: _now, months: 3);
      expect(b.map((e) => e.count), [0, 1, 2]);
    });

    test('crosses the year edge', () {
      final now = DateTime(2027, 2, 10);
      final b = monthlyBuckets([DateTime(2026, 12, 31), DateTime(2027, 1, 1)],
          now: now, months: 3);
      expect(b.map((e) => e.start), [DateTime(2026, 12), DateTime(2027, 1), DateTime(2027, 2)]);
      expect(b.map((e) => e.count), [1, 1, 0]);
    });
  });

  group('AnalyticsPeriod', () {
    test('start of each period', () {
      expect(AnalyticsPeriod.weeks4.start(_now), DateTime(2026, 10, 12));
      expect(AnalyticsPeriod.weeks12.start(_now), DateTime(2026, 8, 17));
      expect(AnalyticsPeriod.months6.start(_now), DateTime(2026, 6));
      expect(AnalyticsPeriod.all.start(_now), isNull);
    });

    test('months6 crosses a year boundary', () {
      expect(AnalyticsPeriod.months6.start(DateTime(2027, 2, 10)), DateTime(2026, 9));
    });

    test('filter keeps items on the first day and drops older ones', () {
      final dates = [
        DateTime(2026, 10, 11, 23, 59),
        DateTime(2026, 10, 12),
        _now,
      ];
      expect(AnalyticsPeriod.weeks4.filter(dates, (d) => d, now: _now).length, 2);
      expect(AnalyticsPeriod.all.filter(dates, (d) => d, now: _now).length, 3);
      expect(AnalyticsPeriod.weeks4.filter(<DateTime>[], (d) => d, now: _now), isEmpty);
    });

    test('weeksFor: fixed periods, months6 span, all from the oldest date', () {
      expect(weeksFor(AnalyticsPeriod.weeks4, const [], _now), 4);
      expect(weeksFor(AnalyticsPeriod.weeks12, const [], _now), 12);
      // Mon 1 Jun 2026 -> Mon 2 Nov 2026 is 22 weeks, so 23 buckets.
      expect(weeksFor(AnalyticsPeriod.months6, const [], _now), 23);
      expect(weeksFor(AnalyticsPeriod.all, const [], _now), 4);
      expect(weeksFor(AnalyticsPeriod.all, [DateTime(2026, 10, 1)], _now), 6);
      expect(weeksFor(AnalyticsPeriod.all, [DateTime(2020, 1, 1)], _now), 52);
    });

    test('monthsFor', () {
      expect(monthsFor(AnalyticsPeriod.weeks4, const [], _now), 6);
      expect(monthsFor(AnalyticsPeriod.months6, const [], _now), 12);
      expect(monthsFor(AnalyticsPeriod.all, const [], _now), 6);
      expect(monthsFor(AnalyticsPeriod.all, [DateTime(2025, 11, 5)], _now), 13);
      expect(monthsFor(AnalyticsPeriod.all, [DateTime(2010, 1, 1)], _now), 24);
    });
  });

  group('gradeSplit', () {
    test('empty', () {
      expect(gradeSplit(const []).total, 0);
    });

    test('counts case-insensitively; blank and unknown are ungraded', () {
      final s = gradeSplit(['Green', 'green ', 'AMBER', 'Yellow', 'Red', '', 'Purple']);
      expect((s.green, s.amber, s.red, s.ungraded), (2, 2, 1, 2));
      expect(s.total, 7);
    });
  });

  group('topN', () {
    test('empty and blank keys', () {
      expect(topN(const [], 5), isEmpty);
      expect(topN(['', '  '], 5), isEmpty);
    });

    test('highest first, ties by name, limited to n', () {
      final r = topN(['b', 'a', 'c', 'c', 'B', 'd', 'e', 'f', 'b'], 3);
      // b/B/b is one site (3); c has 2; a, d, e, f have 1 each, 'a' sorts first.
      expect(r, [const LabelCount('b', 3), const LabelCount('c', 2), const LabelCount('a', 1)]);
    });

    test('fewer than n returns all', () {
      expect(topN(['x'], 5), [const LabelCount('x', 1)]);
    });

    test('groups case-insensitively and trimmed, showing the first spelling seen', () {
      expect(topN(['b', 'B', ' b ', 'a'], 5),
          [const LabelCount('b', 3), const LabelCount('a', 1)]);
      expect(topN(['Site_X', 'SITE_X', 'site_x'], 5), [const LabelCount('Site_X', 3)]);
      // Tie after grouping falls back to name order.
      expect(topN(['Zed', 'zed', 'Amy', 'AMY'], 5),
          [const LabelCount('Amy', 2), const LabelCount('Zed', 2)]);
    });

    test('trims keys', () {
      expect(topN([' Q_1', 'Q_1 '], 5), [const LabelCount('Q_1', 2)]);
    });
  });

  group('orders', () {
    OrderPoint o(WorkOrderStatus s, [DateTime? at]) => OrderPoint(status: s, scheduledFor: at);

    test('ordersByStatus lists every status in lifecycle order, zeros included', () {
      final r = ordersByStatus([
        o(WorkOrderStatus.completed),
        o(WorkOrderStatus.completed),
        o(WorkOrderStatus.draft),
      ]);
      expect(r.map((e) => e.label),
          ['Draft', 'Scheduled', 'In progress', 'Completed', 'Cancelled']);
      expect(r.map((e) => e.count), [1, 0, 0, 2, 0]);
      expect(ordersByStatus(const []).every((e) => e.count == 0), isTrue);
    });

    test('overdue means open and dated before today', () {
      final r = overdueSplit([
        o(WorkOrderStatus.scheduled, DateTime(2026, 11, 7, 23, 59)), // overdue
        o(WorkOrderStatus.inProgress, DateTime(2026, 11, 8, 0, 0)), // today: on time
        o(WorkOrderStatus.scheduled, DateTime(2026, 11, 20)), // on time
        o(WorkOrderStatus.draft), // undated: on time
        o(WorkOrderStatus.completed, DateTime(2026, 1, 1)), // closed: ignored
        o(WorkOrderStatus.cancelled, DateTime(2026, 1, 1)), // closed: ignored
      ], _now);
      expect((r.onTime, r.overdue), (3, 1));
      expect(overdueSplit(const [], _now), (onTime: 0, overdue: 0));
    });
  });

  group('maintenance', () {
    MaintenancePoint m(DateTime d, bool done) => MaintenancePoint(date: d, completed: done);

    test('completedPerMonth counts only completed records', () {
      final b = completedPerMonth([
        m(DateTime(2026, 11, 2), true),
        m(DateTime(2026, 11, 3), false),
        m(DateTime(2026, 10, 31), true),
      ], now: _now, months: 2);
      expect(b.map((e) => e.count), [1, 1]);
      expect(completedPerMonth(const [], now: _now, months: 2).map((e) => e.count), [0, 0]);
    });

    test('split', () {
      final s = maintenanceSplit([
        m(_now, true),
        m(_now, false),
        m(_now, false),
      ]);
      expect((s.inProgress, s.completed), (2, 1));
      expect(maintenanceSplit(const []), (inProgress: 0, completed: 0));
    });
  });

  group('tasksPerTechnician', () {
    TaskPoint t(DateTime when, {String? who, String status = 'scheduled'}) =>
        TaskPoint(when: when, status: status, assignee: who);

    test('empty', () {
      expect(tasksPerTechnician(const [], now: _now, names: const {}), isEmpty);
    });

    test('this week only (Monday to Sunday), cancelled ignored, names resolved', () {
      final r = tasksPerTechnician([
        t(DateTime(2026, 11, 2), who: 'u1'), // Monday 00:00, in
        t(DateTime(2026, 11, 8, 23, 59), who: 'u1'), // Sunday night, in
        t(DateTime(2026, 11, 1, 23, 59), who: 'u1'), // last Sunday, out
        t(DateTime(2026, 11, 9), who: 'u1'), // next Monday, out
        t(DateTime(2026, 11, 3), who: 'u2', status: 'cancelled'), // out
        t(DateTime(2026, 11, 3), who: 'u2', status: 'completed'), // counts
        t(DateTime(2026, 11, 4)), // unassigned
        t(DateTime(2026, 11, 4), who: 'abcdefgh'), // unknown id
      ], now: _now, names: {'u1': 'Ana', 'u2': 'Ben'});
      expect(r, [
        const LabelCount('Ana', 2),
        const LabelCount('Ben', 1),
        const LabelCount('Technician abcd', 1),
        const LabelCount('Unassigned', 1),
      ]);
    });

    test('roster technicians with no tasks are listed with zero; ties by name', () {
      final r = tasksPerTechnician([t(DateTime(2026, 11, 3), who: 'u2')],
          now: _now, names: {'u1': 'Zed', 'u2': 'Amy', 'u3': 'Bo'}, roster: ['u1', 'u2', 'u3']);
      expect(r, [
        const LabelCount('Amy', 1),
        const LabelCount('Bo', 0),
        const LabelCount('Zed', 0),
      ]);
    });

    test('limit', () {
      final ids = [for (var i = 0; i < 12; i++) 'u$i'];
      final r = tasksPerTechnician(const [],
          now: _now, names: {for (final i in ids) i: i}, roster: ids, limit: 5);
      expect(r.length, 5);
    });
  });

  group('analytics metrics', () {
    test('empty snapshot gives zeros', () {
      final m = AnalyticsMetrics.from(AnalyticsSnapshot.empty, _now);
      expect(m.totalInspections, 0);
      expect(m.grades.total, 0);
      expect(m.maintenanceOpen, 0);
    });

    test('counts, this month by created date, upcoming vs overdue tasks', () {
      final s = AnalyticsSnapshot(
        inspections: [
          InspectionPoint(
              date: DateTime(2026, 10, 1),
              createdAt: DateTime(2026, 11, 1),
              grade: 'Red',
              deficiencies: true,
              loadbankDone: true),
          InspectionPoint(
              date: DateTime(2026, 10, 1), createdAt: DateTime(2026, 10, 31), grade: ''),
        ],
        maintenance: [
          MaintenancePoint(date: _now, completed: true),
          MaintenancePoint(date: _now, completed: false, requiresFollowUp: true),
        ],
        tasks: [
          TaskPoint(when: DateTime(2026, 11, 20), status: 'scheduled'),
          TaskPoint(when: DateTime(2026, 11, 1), status: 'overdue'),
          TaskPoint(when: DateTime(2026, 11, 1), status: 'completed'),
        ],
      );
      final m = AnalyticsMetrics.from(s, _now);
      expect((m.totalInspections, m.inspectionsThisMonth, m.deficiencies, m.loadTestsDone),
          (2, 1, 1, 1));
      expect((m.grades.red, m.grades.ungraded), (1, 1));
      expect((m.maintenanceCompleted, m.maintenanceOpen, m.maintenanceFollowUp), (1, 1, 1));
      expect((m.upcomingTasks, m.overdueTasks), (1, 1));
    });
  });

  test('month names', () {
    expect(monthAbbr(1), 'Jan');
    expect(monthAbbr(12), 'Dec');
    expect(shortDate(DateTime(2026, 11, 3)), '3 Nov');
  });
}
