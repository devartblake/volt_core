import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/readiness/domain/readiness_inputs.dart';
import 'package:voltcore/modules/readiness/domain/readiness_models.dart';
import 'package:voltcore/modules/readiness/domain/readiness_rules.dart';
import 'package:voltcore/modules/readiness/domain/readiness_summary.dart';
import 'package:voltcore/modules/readiness/domain/readiness_view.dart';

import 'readiness_fixtures.dart';
import 'ui/readiness_ui_harness.dart' show fleetInputs;

ReadinessReport _report() =>
    computeReadiness(fleetInputs(), const ReadinessConfig(), kNow);

void main() {
  group('readinessDueText', () {
    ReadinessUnit one(ReadinessInspection i) =>
        computeReadiness(oneUnit(i), const ReadinessConfig(), kNow).units.single;

    test('future, today, overdue, estimated', () {
      expect(readinessDueText(one(insp('a', dueIn: 9))), 'Due in 9 days');
      expect(readinessDueText(one(insp('a', dueIn: 1))), 'Due in 1 day');
      expect(readinessDueText(one(insp('a', dueIn: 0))), 'Due today');
      expect(readinessDueText(one(insp('a', dueIn: -12))), 'Overdue 12 days');
      expect(readinessDueText(one(insp('a', dueIn: -1))), 'Overdue 1 day');
      // No next-due date: last + 365 days, flagged as an estimate.
      final est = one(insp('a', ago: 60));
      expect(est.dueIsEstimated, isTrue);
      expect(readinessDueText(est), 'Due ~Sep 2027 (estimated)');
      expect(readinessDueText(one(insp('a', ago: 400))), 'Overdue 35 days (estimated)');
    });

    test('never inspected', () {
      final r = computeReadiness(
        const ReadinessInputs(equipment: [
          ReadinessEquipment(id: 'e1', make: 'Kohler', model: 'X', serial: 'Q9'),
        ]),
        const ReadinessConfig(),
        kNow,
      );
      expect(readinessDueText(r.units.single), 'No inspection on record');
    });
  });

  test('readinessClock formats a 12-hour time', () {
    expect(readinessClock(DateTime(2026, 11, 7, 15, 20)), '3:20 PM');
    expect(readinessClock(DateTime(2026, 11, 7, 0, 5)), '12:05 AM');
    expect(readinessClock(DateTime(2026, 11, 7, 12, 0)), '12:00 PM');
  });

  group('groupByDueWeek', () {
    test('Overdue, This week, Next week, dated weeks, Later, No date', () {
      final units = _report().units;
      final groups = groupByDueWeek(units, kNow);
      expect(groups.map((g) => g.label), [
        'Overdue', // S2, S3
        'Next week', // S5 (12 Nov)
        'Week of 16 Nov', // S7 (16 Nov)
        'Week of 23 Nov', // S6 (27 Nov)
        'Week of 14 Dec', // S1 (17 Dec)
        'Week of 4 Jan 2027', // S8 (6 Jan)
        'Later', // S4, S9..S12
      ]);
      expect(groups.first.label, 'Overdue');
      expect(groups.first.units.map((u) => u.serial), ['S2', 'S3']);
      expect(groups.map((g) => g.label), containsAllInOrder(['Overdue', 'Next week']));
      expect(groups.fold<int>(0, (a, g) => a + g.count), units.length);
    });

    test('units without a due date go last', () {
      final r = computeReadiness(
        ReadinessInputs(
          inspections: [insp('a', dueIn: 3)],
          equipment: const [
            ReadinessEquipment(id: 'e1', make: 'Cat', model: 'Z', serial: 'NEW1'),
          ],
        ),
        const ReadinessConfig(),
        kNow,
      );
      final g = groupByDueWeek(r.units, kNow);
      expect(g.last.label, 'No due date');
      expect(g.last.units.single.serial, 'NEW1');
    });
  });

  group('inspectionHistoryFor', () {
    final all = [
      insp('old', serial: 'S1', ago: 400),
      insp('new', serial: 'S1', ago: 10),
      insp('other', serial: 'S2', ago: 5),
      insp('noserial', serial: '', site: 'Q_900', ago: 3),
    ];

    test('matches by serial, newest first', () {
      final u = _report().units.firstWhere((x) => x.serial == 'S1');
      expect(inspectionHistoryFor(u, all).map((i) => i.id), ['new', 'old']);
    });

    test('falls back to the site code when the unit has no serial', () {
      final r = computeReadiness(
        ReadinessInputs(inspections: [all.last]),
        const ReadinessConfig(),
        kNow,
      );
      expect(inspectionHistoryFor(r.units.single, all).map((i) => i.id), ['noserial']);
    });

    test('limit and trend (oldest first)', () {
      final many = [
        for (var i = 0; i < 20; i++)
          insp('h$i', serial: 'S1', ago: i + 1, grade: i == 0 ? 'Red' : 'Green'),
      ];
      final u = _report().units.firstWhere((x) => x.serial == 'S1');
      final h = inspectionHistoryFor(u, many);
      expect(h, hasLength(12));
      final t = gradeTrend(h);
      expect(t.last, ReadinessGrade.red); // newest is last
      expect(t.first, ReadinessGrade.green);
    });
  });

  group('filters', () {
    test('dueWeekStart keeps only units due in that week', () {
      final units = _report().units;
      const f = ReadinessFilter();
      final week = f.copyWith(dueWeekStart: DateTime(2026, 11, 9));
      expect(week.apply(units).map((u) => u.serial), ['S5']);
      expect(week.isEmpty, isFalse);
      expect(week.copyWith(clearDueWeek: true).isEmpty, isTrue);
      expect(week == f.copyWith(dueWeekStart: DateTime(2026, 11, 9)), isTrue);
      expect(week == f, isFalse);
    });

    test('activeFilterCount counts conditions, not values', () {
      expect(activeFilterCount(const ReadinessFilter()), 0);
      final f = ReadinessFilter(
        query: 'kohler',
        statuses: {ReadinessStatus.ready, ReadinessStatus.dueSoon},
        grade: ReadinessGrade.red,
        dueWeekStart: DateTime(2026, 11, 9),
        hasFollowUps: true,
      );
      expect(activeFilterCount(f), 5);
      expect(sheetFilterCount(f), 3);
    });
  });

  test('dueChartSummary reads the counts out', () {
    final s = summarizeReadiness(_report().units, kNow);
    final text = dueChartSummary(s.overdueCount, [for (final b in s.dueByWeek) b.count], mondayOf(kNow));
    expect(text, startsWith('2 overdue'));
    expect(text, contains('1 due week of 9 Nov'));
  });
}
