import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/readiness/domain/readiness_inputs.dart';
import 'package:voltcore/modules/readiness/domain/readiness_mini_series.dart';
import 'package:voltcore/modules/readiness/domain/readiness_models.dart';
import 'package:voltcore/modules/readiness/domain/readiness_rules.dart';
import 'package:voltcore/modules/readiness/domain/readiness_summary.dart';

import 'readiness_fixtures.dart';

List<ReadinessUnit> _units() => computeReadiness(
      ReadinessInputs(
        inspections: [
          insp('r', serial: 'R', site: 'Q_1', grade: 'Red', ago: 20, dueIn: 40),
          insp('o', serial: 'O', site: 'Q_2', ago: 400, dueIn: -45),
          insp('a', serial: 'A', site: 'Q_3', grade: 'Amber', ago: 30, dueIn: 100),
          insp('d', serial: 'D', site: 'Q_4', ago: 375, dueIn: -10),
          insp('e', serial: 'E', site: 'Q_5', ago: 10), // estimated due date
          insp('g', serial: 'G', site: 'Q_6', ago: 10, dueIn: 90),
        ],
        maintenance: [
          ReadinessMaintenance(
            id: 'm',
            inspectionId: 'a',
            serial: 'A',
            date: day(-5),
            requiresFollowUp: true,
            followUpNotes: 'x',
          ),
        ],
        jobNeeds: [
          const ReadinessJobNeed(
              type: ReadinessJobType.inspection, jobId: 'd', shortCount: 2),
        ],
      ),
      const ReadinessConfig(),
      kNow,
    ).units;

int _n(List<ReasonCount> l, ReadinessReasonKind k) =>
    l.firstWhere((r) => r.kind == k).count;

void main() {
  test('attention reasons count units per reason', () {
    final c = attentionReasonCounts(_units());
    expect(c.map((r) => r.kind), attentionReasonKinds.keys);
    expect(_n(c, ReadinessReasonKind.amberGrade), 1);
    expect(_n(c, ReadinessReasonKind.followUps), 1);
    expect(_n(c, ReadinessReasonKind.overdue), 1); // D, 10 days
    expect(_n(c, ReadinessReasonKind.partsShort), 1);
  });

  test('not ready reasons only count not-ready units', () {
    final c = notReadyReasonCounts(_units());
    expect(_n(c, ReadinessReasonKind.redGrade), 1);
    expect(_n(c, ReadinessReasonKind.overdue), 1); // O, 45 days
    expect(_n(c, ReadinessReasonKind.neverInspected), 0);
  });

  test('empty fleet gives zero counts for every kind', () {
    final c = attentionReasonCounts(const []);
    expect(c, hasLength(4));
    expect(c.every((r) => r.count == 0), isTrue);
    expect(notReadyReasonCounts(const []).every((r) => r.count == 0), isTrue);
  });

  test('due soon slice flags the weeks inside the window', () {
    final s = summarizeReadiness(_units(), kNow);
    final slice = dueSoonWeekSlice(s.dueByWeek, kNow, 30);
    expect(slice, hasLength(12));
    // Today is Sat 7 Nov; the window ends Mon 7 Dec. Weeks starting 2, 9, 16,
    // 23, 30 Nov and 7 Dec overlap it.
    expect(slice.where((p) => p.inWindow).length, 6);
    expect(slice.first.inWindow, isTrue);
    expect(slice.last.inWindow, isFalse);
    expect(slice.map((p) => p.count).fold<int>(0, (a, b) => a + b),
        s.dueByWeek.fold<int>(0, (a, b) => a + b.count));
  });

  test('a zero-day window still flags the current week', () {
    final s = summarizeReadiness(_units(), kNow);
    final slice = dueSoonWeekSlice(s.dueByWeek, kNow, 0);
    expect(slice.where((p) => p.inWindow).length, 1);
  });

  test('an empty bucket list gives an empty slice', () {
    expect(dueSoonWeekSlice(const [], kNow, 30), isEmpty);
  });

  test('shares, estimates and the empty chart check', () {
    final units = _units();
    final s = summarizeReadiness(units, kNow);
    final sum = [for (final st in ReadinessStatus.values) statusShare(s, st)]
        .fold<double>(0, (a, b) => a + b);
    expect(sum, closeTo(1, 1e-9));
    expect(statusShare(ReadinessSummary.empty, ReadinessStatus.ready), 0);
    expect(estimatedDueCount(units), 1);
    expect(dueChartIsEmpty(s), isFalse);
    expect(dueChartIsEmpty(summarizeReadiness(const [], kNow)), isTrue);
  });
}
