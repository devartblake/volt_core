import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/materials/domain/material_list.dart';
import 'package:voltcore/modules/readiness/domain/readiness_inputs.dart';
import 'package:voltcore/modules/readiness/domain/readiness_models.dart';
import 'package:voltcore/modules/readiness/domain/readiness_rules.dart';

import 'readiness_fixtures.dart';

const cfg = ReadinessConfig();

ReadinessUnit only(ReadinessInputs i, [ReadinessConfig c = cfg]) {
  final r = computeReadiness(i, c, kNow);
  expect(r.units, hasLength(1));
  return r.units.single;
}

ReadinessStatus statusFor(int dueIn, [ReadinessConfig c = cfg]) =>
    only(oneUnit(insp('a', dueIn: dueIn)), c).status;

void main() {
  group('defaults', () {
    test('config defaults', () {
      expect(cfg.dueSoonDays, 30);
      expect(cfg.criticalOverdueDays, 30);
      expect(cfg.staleInspectionDays, 365);
    });
  });

  group('due date edges', () {
    test('due in 31 days is ready, 30 is dueSoon, today is dueSoon', () {
      expect(statusFor(31), ReadinessStatus.ready);
      expect(statusFor(30), ReadinessStatus.dueSoon);
      expect(statusFor(1), ReadinessStatus.dueSoon);
      expect(statusFor(0), ReadinessStatus.dueSoon);
    });

    test('overdue 1..30 days is attention, 31 is notReady', () {
      expect(statusFor(-1), ReadinessStatus.attention);
      expect(statusFor(-30), ReadinessStatus.attention);
      expect(statusFor(-31), ReadinessStatus.notReady);
    });

    test('custom thresholds move the edges', () {
      const c = ReadinessConfig(dueSoonDays: 7, criticalOverdueDays: 5);
      expect(statusFor(8, c), ReadinessStatus.ready);
      expect(statusFor(7, c), ReadinessStatus.dueSoon);
      expect(statusFor(-5, c), ReadinessStatus.attention);
      expect(statusFor(-6, c), ReadinessStatus.notReady);
    });

    test('daysToDue counts calendar days, ignoring the time of day', () {
      final u = only(oneUnit(insp('a', dueIn: 9)));
      expect(u.daysToDue, 9);
      expect(u.nextDueAt, day(9));
    });
  });

  group('no next-due date', () {
    test('fresh inspection: estimated from last + 365 days', () {
      final u = only(oneUnit(insp('a', ago: 300)));
      expect(u.dueIsEstimated, isTrue);
      expect(u.daysToDue, 65);
      expect(u.status, ReadinessStatus.ready);
      expect(u.reasons.map((r) => r.kind),
          contains(ReadinessReasonKind.estimatedDueDate));
    });

    test('approaching the year is dueSoon', () {
      expect(only(oneUnit(insp('a', ago: 340))).status, ReadinessStatus.dueSoon);
    });

    test('stale inspection is attention, then notReady', () {
      expect(only(oneUnit(insp('a', ago: 380))).status,
          ReadinessStatus.attention); // 15 days over
      expect(only(oneUnit(insp('a', ago: 395))).status,
          ReadinessStatus.attention); // exactly 30 over
      expect(only(oneUnit(insp('a', ago: 396))).status,
          ReadinessStatus.notReady); // 31 over
    });

    test('staleInspectionDays is configurable', () {
      final u = only(oneUnit(insp('a', ago: 100)),
          const ReadinessConfig(staleInspectionDays: 90));
      expect(u.daysToDue, -10);
      expect(u.status, ReadinessStatus.attention);
    });

    test('an explicit nextDueAt is never marked estimated', () {
      expect(only(oneUnit(insp('a', dueIn: 100))).dueIsEstimated, isFalse);
    });
  });

  group('grade', () {
    test('Red is notReady even when not due', () {
      final u = only(oneUnit(insp('a', grade: 'Red', ago: 3, dueIn: 200)));
      expect(u.status, ReadinessStatus.notReady);
      expect(u.lastGrade, ReadinessGrade.red);
    });

    test('a later Green clears an earlier Red', () {
      final u = only(ReadinessInputs(inspections: [
        insp('old', grade: 'Red', ago: 60, dueIn: 100),
        insp('new', grade: 'Green', ago: 5, dueIn: 200),
      ]));
      expect(u.status, ReadinessStatus.ready);
      expect(u.lastGrade, ReadinessGrade.green);
    });

    test('a later Amber replaces Red but needs attention', () {
      final u = only(ReadinessInputs(inspections: [
        insp('old', grade: 'Red', ago: 60),
        insp('new', grade: 'Amber', ago: 5, dueIn: 200),
      ]));
      expect(u.status, ReadinessStatus.attention);
    });

    test('a later ungraded inspection does not clear a Red', () {
      final u = only(ReadinessInputs(inspections: [
        insp('old', grade: 'Red', ago: 60),
        insp('new', grade: '', ago: 5, dueIn: 200),
      ]));
      expect(u.status, ReadinessStatus.notReady);
      expect(u.reasons.first.text, 'Last graded inspection was Red (8 Sep)');
    });

    test('Green earlier then Red later is notReady', () {
      final u = only(ReadinessInputs(inspections: [
        insp('old', grade: 'Green', ago: 60),
        insp('new', grade: 'red', ago: 5, dueIn: 200),
      ]));
      expect(u.status, ReadinessStatus.notReady);
    });

    test('Amber is attention; grade parsing is case-insensitive', () {
      final u = only(oneUnit(insp('a', grade: ' AMBER ', dueIn: 200)));
      expect(u.status, ReadinessStatus.attention);
      expect(u.lastGrade, ReadinessGrade.amber);
    });

    test('unrecognised grade is ungraded and does not affect status', () {
      final u = only(oneUnit(insp('a', grade: 'Purple', dueIn: 200)));
      expect(u.lastGrade, ReadinessGrade.none);
      expect(u.status, ReadinessStatus.ready);
    });
  });

  group('never inspected', () {
    test('registry-only generator is notReady with no due date', () {
      final u = only(const ReadinessInputs(equipment: [
        ReadinessEquipment(
            id: 'e1', make: 'Generac', model: 'G1', serial: 'S9', siteCode: 'X_7'),
      ]));
      expect(u.status, ReadinessStatus.notReady);
      expect(u.lastInspectionAt, isNull);
      expect(u.nextDueAt, isNull);
      expect(u.daysToDue, isNull);
      expect(u.reasons.single.text, 'No inspection on record');
      expect(u.reasons.single.severity, ReadinessSeverity.critical);
    });

    test('registry lastInspection is used when no inspection record exists', () {
      final u = only(ReadinessInputs(equipment: [
        ReadinessEquipment(id: 'e1', serial: 'S9', lastInspection: day(-20)),
      ]));
      expect(u.lastInspectionAt, day(-20));
      expect(u.dueIsEstimated, isTrue);
      expect(u.status, ReadinessStatus.ready);
    });

    test('a future-dated inspection is a planned visit, not history', () {
      final u = only(ReadinessInputs(inspections: [
        insp('p', ago: -14, dueIn: 400),
      ]));
      expect(u.lastInspectionAt, isNull);
      expect(u.status, ReadinessStatus.notReady);
      expect(u.scheduledTaskNext, day(14));
    });

    test('retired generators are left out', () {
      final r = computeReadiness(
          ReadinessInputs(inspections: [
            insp('a', dueIn: 100)
          ], equipment: const [
            ReadinessEquipment(id: 'e', serial: 'SN1', isRetired: true),
          ]),
          cfg,
          kNow);
      expect(r.units, isEmpty);
    });

    test('non-generator equipment is skipped and counted', () {
      final r = computeReadiness(
          const ReadinessInputs(equipment: [
            ReadinessEquipment(id: 'e', serial: 'U1', isGenerator: false),
          ]),
          cfg,
          kNow);
      expect(r.units, isEmpty);
      expect(r.unmatched.skippedEquipment, 1);
    });
  });

  group('follow-ups', () {
    ReadinessMaintenance fu(String id, int ago,
            {bool done = false, bool need = true, String? notes = 'Replace belt'}) =>
        ReadinessMaintenance(
          id: id,
          serial: 'SN1',
          date: day(-ago),
          completed: done,
          requiresFollowUp: need,
          followUpNotes: notes,
        );

    test('an open follow-up needs attention', () {
      final u = only(oneUnit(insp('a', dueIn: 200), maintenance: [fu('m1', 5)]));
      expect(u.status, ReadinessStatus.attention);
      expect(u.followUpCount, 1);
      expect(u.openFollowUps.single.note, 'Replace belt');
      expect(u.reasons.map((r) => r.text), contains('1 open follow-up'));
    });

    test('plural text and blank notes', () {
      final u = only(oneUnit(insp('a', dueIn: 200),
          maintenance: [fu('m1', 5, notes: ''), fu('m2', 6, notes: null)]));
      expect(u.reasons.map((r) => r.text), contains('2 open follow-ups'));
      expect(u.openFollowUps.first.note, 'Follow-up needed');
    });

    test('long notes are clipped to 80 characters', () {
      final u = only(oneUnit(insp('a', dueIn: 200),
          maintenance: [fu('m1', 5, notes: 'x' * 200)]));
      expect(u.openFollowUps.single.note.length, 80);
      expect(u.openFollowUps.single.note.endsWith('…'), isTrue);
    });

    test('a later completed visit resolves earlier follow-ups', () {
      final u = only(oneUnit(insp('a', dueIn: 200), maintenance: [
        fu('m1', 20),
        fu('m2', 5, done: true, need: false),
      ]));
      expect(u.followUpCount, 0);
      expect(u.status, ReadinessStatus.ready);
    });

    test('a completed visit on the same day does not resolve it', () {
      final u = only(oneUnit(insp('a', dueIn: 200), maintenance: [
        fu('m1', 5, done: true),
      ]));
      expect(u.followUpCount, 1);
    });

    test('records without the flag are ignored', () {
      final u = only(oneUnit(insp('a', dueIn: 200),
          maintenance: [fu('m1', 5, need: false)]));
      expect(u.followUpCount, 0);
    });
  });

  group('parts short', () {
    test('short parts on the latest inspection need attention', () {
      final u = only(oneUnit(insp('a', dueIn: 200), jobNeeds: const [
        ReadinessJobNeed(type: ReadinessJobType.inspection, jobId: 'a', shortCount: 3),
      ]));
      expect(u.status, ReadinessStatus.attention);
      expect(u.partsShortCount, 3);
      expect(u.reasons.map((r) => r.text),
          contains('Parts short for next job (3 parts)'));
    });

    test('an older inspection no longer counts', () {
      final u = only(ReadinessInputs(inspections: [
        insp('old', ago: 100, dueIn: 200),
        insp('new', ago: 5, dueIn: 200),
      ], jobNeeds: const [
        ReadinessJobNeed(type: ReadinessJobType.inspection, jobId: 'old', shortCount: 2),
      ]));
      expect(u.partsShortCount, 0);
      expect(u.status, ReadinessStatus.ready);
    });

    test('open maintenance counts, completed maintenance does not', () {
      final u = only(oneUnit(insp('a', dueIn: 200), maintenance: const [
        ReadinessMaintenance(id: 'open', serial: 'SN1'),
        ReadinessMaintenance(id: 'done', serial: 'SN1', completed: true),
      ], jobNeeds: const [
        ReadinessJobNeed(type: ReadinessJobType.maintenance, jobId: 'open', shortCount: 1),
        ReadinessJobNeed(type: ReadinessJobType.maintenance, jobId: 'done', shortCount: 4),
      ]));
      expect(u.partsShortCount, 1);
      expect(u.reasons.map((r) => r.text), contains('Parts short for next job (1 part)'));
    });
  });

  group('schedule', () {
    test('earliest open future task is scheduledTaskNext', () {
      final u = only(oneUnit(insp('a', dueIn: 200), tasks: [
        ReadinessTask(id: 't1', scheduledAt: day(20), siteCode: 'Q_001'),
        ReadinessTask(id: 't2', scheduledAt: day(5), siteCode: 'Q_001'),
        ReadinessTask(
            id: 't3', scheduledAt: day(2), siteCode: 'Q_001', status: 'cancelled'),
        ReadinessTask(
            id: 't4', scheduledAt: day(3), siteCode: 'Q_001', status: 'completed'),
      ]));
      expect(u.scheduledTaskNext, day(5));
      expect(u.reasons.map((r) => r.text), contains('Visit scheduled 12 Nov'));
      expect(u.status, ReadinessStatus.ready, reason: 'schedule never changes status');
    });

    test('only a past open task gives a missed-visit note', () {
      final u = only(oneUnit(insp('a', dueIn: 200), tasks: [
        ReadinessTask(id: 't1', scheduledAt: day(-3), siteCode: 'Q_001'),
      ]));
      expect(u.scheduledTaskNext, isNull);
      expect(u.reasons.single.kind, ReadinessReasonKind.visitMissed);
      expect(u.reasons.single.text, 'Scheduled visit missed (4 Nov)');
    });

    test('a task today counts as upcoming', () {
      final u = only(oneUnit(insp('a', dueIn: 200), tasks: [
        ReadinessTask(id: 't1', scheduledAt: kNow, siteCode: 'Q_001'),
      ]));
      expect(u.scheduledTaskNext, kNow);
    });
  });

  group('load tests', () {
    test('uses the newest inspection with the load bank switch', () {
      final u = only(ReadinessInputs(inspections: [
        insp('a', ago: 400, load: true),
        insp('b', ago: 200, load: true, dueIn: 100),
        insp('c', ago: 10, dueIn: 100),
      ]));
      expect(u.lastLoadTestAt, day(-200));
      expect(u.nextLoadTestDueAt, day(165));
    });

    test('none when never done', () {
      final u = only(oneUnit(insp('a', dueIn: 100)));
      expect(u.lastLoadTestAt, isNull);
      expect(u.nextLoadTestDueAt, isNull);
    });
  });

  group('reasons', () {
    test('plain-language text and worst first', () {
      final u = only(oneUnit(
        insp('a', grade: 'Red', ago: 35, dueIn: -12),
        maintenance: [
          ReadinessMaintenance(
              id: 'm', serial: 'SN1', date: day(-3), requiresFollowUp: true)
        ],
      ));
      expect(u.reasons.map((r) => r.text).toList(), [
        'Last inspection was Red (3 Oct)',
        'Inspection overdue by 12 days',
        '1 open follow-up',
      ]);
      expect(u.reasons.map((r) => r.severity).toList(), [
        ReadinessSeverity.critical,
        ReadinessSeverity.warning,
        ReadinessSeverity.warning,
      ]);
    });

    test('due wording', () {
      String due(int n) => only(oneUnit(insp('a', dueIn: n))).reasons.first.text;
      expect(due(9), 'Due in 9 days');
      expect(due(1), 'Due tomorrow');
      expect(due(0), 'Due today');
      expect(only(oneUnit(insp('a', dueIn: -1))).reasons.first.text,
          'Inspection overdue by 1 day');
    });

    test('dates in another year include the year', () {
      expect(readinessDate(DateTime(2025, 10, 3), kNow), '3 Oct 2025');
      expect(readinessDate(DateTime(2026, 1, 9), kNow), '9 Jan');
    });

    test('a ready unit has no warnings', () {
      expect(only(oneUnit(insp('a', dueIn: 200))).reasons, isEmpty);
    });
  });

  group('identity fields', () {
    test('title, key, borough, fuel', () {
      final u = only(oneUnit(insp('a', dueIn: 200, site: 'X_12')));
      expect(u.title, 'Kohler 250REOZD');
      expect(u.borough, 'Bronx');
      expect(u.fuelType, 'Diesel');
      expect(u.latestInspectionId, 'a');
      expect(u.key,
          generatorProfileKey(make: 'Kohler', model: '250REOZD', serial: 'SN1'));
      expect(u.profileKey, u.key);
    });

    test('profile key matches generatorProfileKey for messy input', () {
      final u = only(oneUnit(
          insp('a', dueIn: 200, make: ' Cat ', model: 'C|9', serial: ' ab  12 ')));
      expect(u.profileKey,
          generatorProfileKey(make: ' Cat ', model: 'C|9', serial: ' ab  12 '));
    });

    test('borough only from known prefixes', () {
      String b(String s) => only(oneUnit(insp('a', site: s, dueIn: 200))).borough;
      expect(b('Q_5'), 'Queens');
      expect(b('q_5'), 'Queens');
      expect(b('X_5'), 'Bronx');
      expect(b('B_5'), '');
      expect(b('Queens 5'), '');
      expect(b(''), '');
    });

    test('title falls back to site code, address, then Unknown unit', () {
      expect(
          only(oneUnit(insp('a', make: '', model: '', serial: '', dueIn: 9)))
              .title,
          'Q_001');
      expect(
          only(oneUnit(insp('a',
                  make: '', model: '', serial: '', site: '', dueIn: 9)))
              .title,
          '1 Main St');
      expect(
          only(oneUnit(insp('a',
                  make: '', model: '', serial: '', site: '', address: '', dueIn: 9)))
              .title,
          'Unknown unit');
    });

    test('customer and address come from the site directory', () {
      final r = computeReadiness(
          ReadinessInputs(
            inspections: [insp('a', address: '', dueIn: 100)],
            sites: const [
              ReadinessSite(
                  siteCode: ' q_001 ', address: '9 Dir Ave', customerName: 'City Hall'),
            ],
          ),
          cfg,
          kNow);
      expect(r.units.single.customer, 'City Hall');
      expect(r.units.single.address, '9 Dir Ave');
    });
  });

  group('determinism', () {
    test('input order does not change the result', () {
      final ins = [
        for (var n = 0; n < 30; n++)
          insp('i$n',
              serial: 'S${n % 10}',
              ago: 5 + n,
              dueIn: (n * 13) % 90 - 40,
              grade: ['Green', 'Amber', 'Red', ''][n % 4],
              site: 'Q_${n % 7}'),
      ];
      String sig(List<ReadinessInspection> l) =>
          computeReadiness(ReadinessInputs(inspections: l), cfg, kNow)
              .units
              .map((u) => '${u.key}:${u.status.name}:${u.daysToDue}')
              .join('|');
      expect(sig(ins.reversed.toList()), sig(ins));
      expect(sig([...ins]..shuffle()), sig(ins));
    });
  });
}
