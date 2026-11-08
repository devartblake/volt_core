import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/readiness/domain/readiness_inputs.dart';
import 'package:voltcore/modules/readiness/domain/readiness_join.dart';
import 'package:voltcore/modules/readiness/domain/readiness_models.dart';
import 'package:voltcore/modules/readiness/domain/readiness_rules.dart';

import 'readiness_fixtures.dart';

ReadinessReport run(ReadinessInputs i) =>
    computeReadiness(i, const ReadinessConfig(), kNow);

void main() {
  group('serial first', () {
    test('inspections with the same serial are one unit, whatever the spelling',
        () {
      final r = run(ReadinessInputs(inspections: [
        insp('a', serial: 'ABC 123', ago: 100, dueIn: 50),
        insp('b', serial: ' abc  123 ', ago: 10, dueIn: 200, site: 'Q_002'),
      ]));
      expect(r.units, hasLength(1));
      expect(r.units.single.latestInspectionId, 'b');
      expect(r.units.single.siteCode, 'Q_002');
    });

    test('same site, different serials are different units', () {
      final r = run(ReadinessInputs(inspections: [
        insp('a', serial: 'S1', dueIn: 100),
        insp('b', serial: 'S2', dueIn: 100),
      ]));
      expect(r.units, hasLength(2));
    });

    test('placeholder serials count as unknown', () {
      for (final s in ['', 'N/A', 'none', ' - ', 'Unknown']) {
        expect(normSerial(s), '', reason: s);
      }
      final r = run(ReadinessInputs(inspections: [
        insp('a', serial: 'n/a', site: 'Q_9', dueIn: 100),
        insp('b', serial: 'N/A', site: 'Q_8', dueIn: 100),
      ]));
      expect(r.units, hasLength(2), reason: 'two different sites, not one shared "n/a"');
    });

    test('maintenance with a serial joins by serial even at another site code',
        () {
      final r = run(ReadinessInputs(
        inspections: [insp('a', serial: 'S1', dueIn: 100)],
        maintenance: [
          ReadinessMaintenance(
              id: 'm', serial: 's1', siteCode: 'ELSEWHERE', date: day(-1), requiresFollowUp: true),
        ],
      ));
      expect(r.units.single.followUpCount, 1);
      expect(r.unmatched.total, 0);
    });

    test('a serial that matches no unit does not fall back to the site', () {
      final r = run(ReadinessInputs(
        inspections: [insp('a', serial: 'S1', dueIn: 100)],
        maintenance: [
          ReadinessMaintenance(
              id: 'm', serial: 'OTHER', siteCode: 'Q_001', requiresFollowUp: true),
        ],
      ));
      expect(r.units.single.followUpCount, 0);
      expect(r.unmatched.maintenance, 1);
    });
  });

  group('site code fallback', () {
    test('an inspection without serial is one unit per site', () {
      final r = run(ReadinessInputs(inspections: [
        insp('a', serial: '', make: '', model: '', ago: 100, dueIn: 10),
        insp('b', serial: '', make: '', model: '', ago: 5, dueIn: 300),
        insp('c', serial: '', make: '', model: '', site: 'Q_002', dueIn: 300),
      ]));
      expect(r.units, hasLength(2));
      final q1 = r.units.firstWhere((u) => u.siteCode == 'Q_001');
      expect(q1.key, 'site:q_001');
      expect(q1.latestInspectionId, 'b');
    });

    test('a no-serial inspection joins the only serial unit at that site', () {
      final r = run(ReadinessInputs(inspections: [
        insp('a', serial: 'S1', ago: 100, dueIn: 50),
        insp('b', serial: '', ago: 5, dueIn: 300),
      ]));
      expect(r.units, hasLength(1));
      expect(r.units.single.latestInspectionId, 'b');
    });

    test('a no-serial inspection with a different make does not join', () {
      final r = run(ReadinessInputs(inspections: [
        insp('a', serial: 'S1', make: 'Kohler', dueIn: 50),
        insp('b', serial: '', make: 'Generac', dueIn: 300),
      ]));
      expect(r.units, hasLength(2));
    });

    test('two serial units at one site: ambiguous record is unmatched', () {
      final r = run(ReadinessInputs(
        inspections: [
          insp('a', serial: 'S1', model: 'M1', dueIn: 100),
          insp('b', serial: 'S2', model: 'M2', dueIn: 100),
        ],
        maintenance: const [
          ReadinessMaintenance(id: 'm', siteCode: 'Q_001', requiresFollowUp: true),
          ReadinessMaintenance(
              id: 'm2', siteCode: 'Q_001', model: 'M2', requiresFollowUp: true),
        ],
      ));
      // m is ambiguous; m2 names model M2 so it picks exactly one unit.
      expect(r.unmatched.maintenance, 1);
      expect(r.units.where((u) => u.followUpCount == 1), hasLength(1));
    });

    test('site match ignores case and spacing', () {
      final r = run(ReadinessInputs(
        inspections: [insp('a', site: 'Q_001', dueIn: 100)],
        maintenance: const [
          ReadinessMaintenance(id: 'm', siteCode: ' q_001 ', requiresFollowUp: true),
        ],
      ));
      expect(r.units.single.followUpCount, 1);
    });

    test('an inspection with neither serial nor site is a unit of one', () {
      final r = run(ReadinessInputs(inspections: [
        insp('a', serial: '', site: '', make: '', model: '', dueIn: 10),
        insp('b', serial: '', site: '', make: '', model: '', dueIn: 10),
      ]));
      expect(r.units, hasLength(2));
      expect(r.units.map((u) => u.key).toSet(), {'id:a', 'id:b'});
    });
  });

  group('links and other sources', () {
    test('maintenance links by inspection id before anything else', () {
      final r = run(ReadinessInputs(
        inspections: [insp('a', serial: 'S1', dueIn: 100)],
        maintenance: const [
          ReadinessMaintenance(
              id: 'm', inspectionId: 'a', siteCode: 'NOWHERE', requiresFollowUp: true),
        ],
      ));
      expect(r.units.single.followUpCount, 1);
    });

    test('tasks join by inspection link, maintenance link, then site', () {
      final r = run(ReadinessInputs(
        inspections: [
          insp('a', serial: 'S1', site: 'Q_1', dueIn: 100),
          insp('b', serial: 'S2', site: 'Q_2', dueIn: 100),
          insp('c', serial: 'S3', site: 'Q_3', dueIn: 100),
        ],
        maintenance: const [ReadinessMaintenance(id: 'm', serial: 'S2')],
        tasks: [
          ReadinessTask(id: 't1', scheduledAt: day(3), inspectionId: 'a'),
          ReadinessTask(
              id: 't2', scheduledAt: day(4), sourceType: 'maintenance_record', sourceId: 'm'),
          ReadinessTask(id: 't3', scheduledAt: day(5), siteCode: 'Q_3'),
          ReadinessTask(id: 't4', scheduledAt: day(6), siteCode: 'NOPE'),
        ],
      ));
      DateTime? next(String site) =>
          r.units.firstWhere((u) => u.siteCode == site).scheduledTaskNext;
      expect(next('Q_1'), day(3));
      expect(next('Q_2'), day(4));
      expect(next('Q_3'), day(5));
      expect(r.unmatched.tasks, 1);
    });

    test('unmatched records never create units', () {
      final r = run(ReadinessInputs(
        maintenance: [ReadinessMaintenance(id: 'm', serial: 'X', siteCode: 'Q_9')],
        tasks: [ReadinessTask(id: 't', scheduledAt: day(1), siteCode: 'Q_9')],
        jobNeeds: const [
          ReadinessJobNeed(type: ReadinessJobType.inspection, jobId: 'ghost', shortCount: 1),
          ReadinessJobNeed(type: ReadinessJobType.maintenance, jobId: 'ghost', shortCount: 1),
        ],
      ));
      expect(r.units, isEmpty);
      expect(r.unmatched.maintenance, 1);
      expect(r.unmatched.tasks, 1);
      expect(r.unmatched.jobNeeds, 2);
      expect(r.unmatched.total, 4);
    });
  });

  group('registry equipment', () {
    test('joins an inspected unit by serial and adds nothing', () {
      final r = run(ReadinessInputs(
        inspections: [insp('a', serial: 'S1', dueIn: 100)],
        equipment: const [ReadinessEquipment(id: 'e', serial: 's1', make: 'Kohler')],
      ));
      expect(r.units, hasLength(1));
    });

    test('joins a site-level unit by site and make', () {
      final r = run(ReadinessInputs(
        inspections: [insp('a', serial: '', dueIn: 100)],
        equipment: const [
          ReadinessEquipment(id: 'e', siteCode: 'Q_001', make: 'Kohler', model: '250REOZD'),
        ],
      ));
      expect(r.units, hasLength(1));
    });

    test('an uninspected registered generator becomes a notReady unit', () {
      final r = run(ReadinessInputs(
        inspections: [insp('a', serial: 'S1', dueIn: 100)],
        equipment: const [
          ReadinessEquipment(id: 'e', serial: 'S2', make: 'Cat', model: 'C9', siteCode: 'X_1'),
        ],
      ));
      expect(r.units, hasLength(2));
      final n = r.units.firstWhere((u) => u.serial == 'S2');
      expect(n.status, ReadinessStatus.notReady);
      expect(n.borough, 'Bronx');
    });

    test('registry fills in what inspections lack', () {
      final r = run(ReadinessInputs(
        inspections: [insp('a', serial: 'S1', fuel: '', dueIn: 100)],
        equipment: const [ReadinessEquipment(id: 'e', serial: 'S1', fuelType: 'Natural Gas')],
      ));
      expect(r.units.single.fuelType, 'Natural Gas');
    });
  });

  group('helpers', () {
    test('daysBetween ignores time of day and crosses year ends', () {
      expect(daysBetween(DateTime(2026, 12, 31, 23, 59), DateTime(2027, 1, 1, 0, 1)), 1);
      expect(daysBetween(DateTime(2027, 1, 1), DateTime(2026, 12, 25)), -7);
    });

    test('daysBetween is not shifted by daylight saving', () {
      // US clocks change on 1 Nov 2026 and 8 Mar 2026; whole days either way.
      expect(daysBetween(DateTime(2026, 10, 31), DateTime(2026, 11, 2)), 2);
      expect(daysBetween(DateTime(2026, 3, 7), DateTime(2026, 3, 9)), 2);
      expect(daysBetween(DateTime(2026, 1, 1), DateTime(2027, 1, 1)), 365);
    });
  });
}
