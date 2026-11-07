import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/maintenance/domain/maintenance_progress.dart';
import 'package:voltcore/modules/maintenance/domain/maintenance_validation.dart';
import 'package:voltcore/modules/maintenance/infra/models/maintenance_record.dart';

MaintenanceRecord _complete() => MaintenanceRecord(id: 'r')
  ..address = '1 Main St'
  ..dateOfService = DateTime(2026, 11, 3)
  ..technicianName = 'Daniel'
  ..generatorMake = 'Generac'
  ..generatorModel = 'RG048'
  ..generatorSerial = 'SN1'
  ..technicianSignatureName = 'Daniel'
  ..customerSignatureName = 'Sam';

void main() {
  const all = {...MaintenanceStep.values};

  test('a complete record has no issues', () {
    expect(MaintenanceValidation.issues(_complete(), revealed: all), isEmpty);
  });

  test('a blank record flags every required field once revealed', () {
    final m = MaintenanceRecord(id: 'x');
    final issues = MaintenanceValidation.issues(m, revealed: all);
    expect(issues.keys.toSet(), MaintenanceField.values.toSet());
    expect(issues.values.toSet(), {MaintenanceValidation.requiredMessage});
  });

  test('nothing shows for steps that are not revealed', () {
    final m = MaintenanceRecord(id: 'x');
    expect(MaintenanceValidation.issues(m, revealed: {}), isEmpty);
    final siteOnly = MaintenanceValidation.issues(m,
        revealed: {MaintenanceStep.siteInfo});
    expect(siteOnly, isNotEmpty);
    expect(siteOnly.keys.every((f) => f.step == MaintenanceStep.siteInfo),
        isTrue);
  });

  test('whitespace does not count as filled', () {
    final m = _complete()..address = '   ';
    expect(MaintenanceValidation.messageFor(m, MaintenanceField.address),
        MaintenanceValidation.requiredMessage);
  });

  test('a signature counts as present by name or by saved image', () {
    final m = MaintenanceRecord(id: 'x')
      ..customerSignaturePath = '/sig/c.png'
      ..technicianSignatureName = 'Tech';
    expect(
        MaintenanceValidation.isFilled(m, MaintenanceField.customerSignature),
        isTrue);
    expect(
        MaintenanceValidation.isFilled(m, MaintenanceField.technicianSignature),
        isTrue);
  });

  test('missingOn is empty for optional steps', () {
    final m = MaintenanceRecord(id: 'x');
    expect(MaintenanceValidation.missingOn(m, MaintenanceStep.photos), isEmpty);
  });

  test('agrees with MaintenanceProgress about Site Information and '
      'Signatures being done', () {
    void clear(MaintenanceRecord m, MaintenanceField f) {
      switch (f) {
        case MaintenanceField.address:
          m.address = '';
        case MaintenanceField.dateOfService:
          m.dateOfService = null;
        case MaintenanceField.technicianName:
          m.technicianName = '';
        case MaintenanceField.generatorMake:
          m.generatorMake = '';
        case MaintenanceField.generatorModel:
          m.generatorModel = '';
        case MaintenanceField.generatorSerial:
          m.generatorSerial = '';
        case MaintenanceField.technicianSignature:
          m.technicianSignatureName = '';
        case MaintenanceField.customerSignature:
          m.customerSignatureName = '';
      }
    }

    final base = MaintenanceProgress.compute(_complete());
    expect(base.of(MaintenanceStep.siteInfo), StepStatus.done);
    expect(base.of(MaintenanceStep.signatures), StepStatus.done);

    for (final f in MaintenanceField.values) {
      final m = _complete();
      clear(m, f);
      final p = MaintenanceProgress.compute(m);
      expect(p.of(f.step) == StepStatus.done, isFalse, reason: '$f');
      expect(MaintenanceValidation.missingOn(m, f.step), [f], reason: '$f');
    }
  });
}
