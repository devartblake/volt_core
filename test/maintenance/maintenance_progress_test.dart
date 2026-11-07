import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/maintenance/domain/maintenance_progress.dart';
import 'package:voltcore/modules/maintenance/infra/models/maintenance_record.dart';

MaintenanceRecord _blank() => MaintenanceRecord(id: 'r1');

MaintenanceRecord _siteDone() => _blank()
  ..address = '244 East 168 Street'
  ..dateOfService = DateTime(2026, 11, 3)
  ..technicianName = 'Daniel'
  ..generatorMake = 'Generac'
  ..generatorModel = 'RG048'
  ..generatorSerial = 'SN1';

void main() {
  group('MaintenanceProgress', () {
    test('a brand-new record is blank and nothing is done', () {
      final p = MaintenanceProgress.compute(_blank());
      expect(p.isBlank, isTrue);
      expect(p.doneCount, 0);
      expect(p.fraction, 0);
      for (final step in MaintenanceStep.values) {
        expect(p.of(step), StepStatus.empty, reason: step.title);
      }
    });

    test('site information is done only when its key details are in', () {
      final partial = _blank()..address = '1 Main St';
      expect(MaintenanceProgress.compute(partial).of(MaintenanceStep.siteInfo),
          StepStatus.started);

      expect(MaintenanceProgress.compute(_siteDone()).of(MaintenanceStep.siteInfo),
          StepStatus.done);

      // The service date is part of the key details.
      final noDate = _siteDone()..dateOfService = null;
      expect(MaintenanceProgress.compute(noDate).of(MaintenanceStep.siteInfo),
          StepStatus.started);

      // Extra optional details alone only make it "started".
      final optionalOnly = _blank()..engineHours = '120';
      expect(
          MaintenanceProgress.compute(optionalOnly)
              .of(MaintenanceStep.siteInfo),
          StepStatus.started);
    });

    test('walkthrough needs a location and an enclosure answer', () {
      final m = _blank()..generatorLocation = 'Outdoors';
      expect(MaintenanceProgress.compute(m).of(MaintenanceStep.walkthrough),
          StepStatus.started);
      m.enclosureIntact = true;
      expect(MaintenanceProgress.compute(m).of(MaintenanceStep.walkthrough),
          StepStatus.done);
    });

    test('general maintenance needs coolant level and battery type', () {
      final m = _blank()..coolantLevel = 'Full';
      expect(MaintenanceProgress.compute(m).of(MaintenanceStep.general),
          StepStatus.started);
      m.batteryType = 'Lead Acid';
      expect(MaintenanceProgress.compute(m).of(MaintenanceStep.general),
          StepStatus.done);
    });

    test('actions: ticking work is "started", observations finish it', () {
      final m = _blank()..oilFilterChanged = true;
      expect(MaintenanceProgress.compute(m).of(MaintenanceStep.actions),
          StepStatus.started);
      m.serviceObservations = 'Ran under load, all normal.';
      expect(MaintenanceProgress.compute(m).of(MaintenanceStep.actions),
          StepStatus.done);
    });

    test('post-service is done when the six core checks are ticked', () {
      final m = _blank()
        ..postVerifyRunsUnderLoad = true
        ..postCheckVoltFreq = true;
      expect(MaintenanceProgress.compute(m).of(MaintenanceStep.postService),
          StepStatus.started);
      m
        ..postInspectExhaust = true
        ..postVerifyGrounding = true
        ..postCheckControlPanel = true
        ..postEnsureSafetyDevices = true;
      expect(MaintenanceProgress.compute(m).of(MaintenanceStep.postService),
          StepStatus.done);
    });

    test('parts are optional: any entry completes the step', () {
      final m = _blank()..partsOilTypeQty = '2 qt 15W-40';
      expect(MaintenanceProgress.compute(m).of(MaintenanceStep.parts),
          StepStatus.done);
    });

    test('photos come from the count passed in', () {
      expect(
          MaintenanceProgress.compute(_blank(), photoCount: 3)
              .of(MaintenanceStep.photos),
          StepStatus.done);
      expect(MaintenanceProgress.compute(_blank()).of(MaintenanceStep.photos),
          StepStatus.empty);
      // A photo alone means the record is not blank.
      expect(MaintenanceProgress.compute(_blank(), photoCount: 1).isBlank,
          isFalse);
    });

    test('signatures: one is started, both are done; name or image counts', () {
      final m = _blank()..technicianSignatureName = 'Daniel';
      expect(MaintenanceProgress.compute(m).of(MaintenanceStep.signatures),
          StepStatus.started);
      m.customerSignaturePath = 'sig/customer.png';
      expect(MaintenanceProgress.compute(m).of(MaintenanceStep.signatures),
          StepStatus.done);
    });

    test('missingExpected lists only site information and signatures', () {
      expect(MaintenanceProgress.compute(_blank()).missingExpected,
          [MaintenanceStep.siteInfo, MaintenanceStep.signatures]);

      final m = _siteDone();
      expect(MaintenanceProgress.compute(m).missingExpected,
          [MaintenanceStep.signatures]);

      m
        ..technicianSignatureName = 'T'
        ..customerSignatureName = 'C';
      expect(MaintenanceProgress.compute(m).missingExpected, isEmpty);
    });

    test('fraction counts a step in progress as half', () {
      final m = _siteDone()..generatorLocation = 'Roof';
      final p = MaintenanceProgress.compute(m);
      // site done (1) + walkthrough started (0.5) of 8 steps
      expect(p.fraction, closeTo(1.5 / 8, 1e-9));
      expect(p.doneCount, 1);
    });
  });
}
