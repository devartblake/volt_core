import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/core/services/hive/hive_boxes.dart';
import 'package:voltcore/modules/equipment/domain/entities/equipment_entity.dart';
import 'package:voltcore/modules/equipment/infra/repositories/equipment_repository_impl.dart';
import 'package:voltcore/modules/inspections/infra/models/inspection.dart';
import 'package:voltcore/modules/inspections/infra/models/nameplate_data.dart';

Inspection _inspection({
  required String id,
  String siteCode = 'AS-100',
  String address = '100 Broadway',
  String make = 'Caterpillar',
  String model = 'C32',
  String serial = 'CAT-001',
  String voltage = '480V',
  String grade = 'Green',
  bool deficiencies = false,
  DateTime? serviceDate,
}) {
  return Inspection(
    id: id,
    createdAt: DateTime(2026, 1, 1),
    siteCode: siteCode,
    siteGrade: grade,
    address: address,
    serviceDate: serviceDate ?? DateTime(2026, 6, 1),
    technicianName: 'Alex',
    generatorMake: make,
    generatorModel: model,
    generatorSerial: serial,
    voltageRating: voltage,
    deficienciesDocumented: deficiencies,
  );
}

void main() {
  late Directory tempDir;
  // No remote datasource: these cover local derivation only.
  const repo = EquipmentRepositoryImpl();

  setUpAll(() {
    Hive.registerAdapter(InspectionAdapter());
    Hive.registerAdapter(NameplateDataAdapter());
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('voltcore_equipment_test');
    Hive.init(tempDir.path);
    HiveBoxes.inspections =
        await Hive.openBox<Inspection>(HiveBoxes.inspectionsBoxName);
    HiveBoxes.nameplates =
        await Hive.openBox<NameplateData>(HiveBoxes.nameplatesBoxName);
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk(HiveBoxes.inspectionsBoxName);
    await Hive.deleteBoxFromDisk(HiveBoxes.nameplatesBoxName);
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('EquipmentRepositoryImpl', () {
    test('returns nothing when no inspections exist', () async {
      expect(await repo.listEquipment(), isEmpty);
    });

    test('derives one entry per inspection of distinct units', () async {
      await HiveBoxes.inspections.put('i1', _inspection(id: 'i1', serial: 'A'));
      await HiveBoxes.inspections.put('i2', _inspection(id: 'i2', serial: 'B'));

      final equipment = await repo.listEquipment();
      expect(equipment.length, 2);
    });

    test('collapses repeat inspections of the same serial into one unit',
        () async {
      await HiveBoxes.inspections.put(
        'old',
        _inspection(id: 'old', serial: 'CAT-001',
            serviceDate: DateTime(2025, 1, 1)),
      );
      await HiveBoxes.inspections.put(
        'new',
        _inspection(id: 'new', serial: 'CAT-001',
            serviceDate: DateTime(2026, 6, 1)),
      );

      final equipment = await repo.listEquipment();
      expect(equipment.length, 1);
      expect(equipment.single.inspectionCount, 2);
      // Reports the latest state, and links to the latest inspection.
      expect(equipment.single.lastInspection, DateTime(2026, 6, 1));
      expect(equipment.single.id, 'new');
    });

    test('serial matching ignores case and surrounding whitespace', () async {
      await HiveBoxes.inspections
          .put('i1', _inspection(id: 'i1', serial: 'cat-001 '));
      await HiveBoxes.inspections
          .put('i2', _inspection(id: 'i2', serial: ' CAT-001'));

      expect((await repo.listEquipment()).length, 1);
    });

    test('falls back to site+make+model when no serial is recorded', () async {
      await HiveBoxes.inspections.put(
        'i1',
        _inspection(id: 'i1', serial: '', siteCode: 'AS-1', model: 'C32'),
      );
      await HiveBoxes.inspections.put(
        'i2',
        _inspection(id: 'i2', serial: '', siteCode: 'AS-1', model: 'C32'),
      );
      await HiveBoxes.inspections.put(
        'i3',
        _inspection(id: 'i3', serial: '', siteCode: 'AS-2', model: 'C32'),
      );

      // Two units: the AS-1 pair collapses, AS-2 stands alone.
      expect((await repo.listEquipment()).length, 2);
    });

    test('nameplate details win over form-typed generator fields', () async {
      await HiveBoxes.inspections.put(
        'i1',
        _inspection(id: 'i1', make: 'typo', model: 'typo', serial: 'typo'),
      );
      await HiveBoxes.nameplates.put(
        'np1',
        NameplateData(
          id: 'np1',
          inspectionId: 'i1',
          generatorMfr: 'Cummins',
          generatorModel: 'QSX15',
          generatorSn: 'CUM-99',
          volts: '208V',
        ),
      );

      final unit = (await repo.listEquipment()).single;
      expect(unit.make, 'Cummins');
      expect(unit.model, 'QSX15');
      expect(unit.serialNumber, 'CUM-99');
      expect(unit.voltage, '208V');
    });

    test('blank nameplate fields fall back to the inspection', () async {
      await HiveBoxes.inspections
          .put('i1', _inspection(id: 'i1', make: 'Kohler', voltage: '240V'));
      await HiveBoxes.nameplates.put(
        'np1',
        NameplateData(id: 'np1', inspectionId: 'i1'),
      );

      final unit = (await repo.listEquipment()).single;
      expect(unit.make, 'Kohler');
      expect(unit.voltage, '240V');
    });

    test('status reflects the latest grade and deficiencies', () async {
      await HiveBoxes.inspections
          .put('ok', _inspection(id: 'ok', serial: 'A', grade: 'Green'));
      await HiveBoxes.inspections
          .put('amber', _inspection(id: 'amber', serial: 'B', grade: 'Amber'));
      await HiveBoxes.inspections
          .put('red', _inspection(id: 'red', serial: 'C', grade: 'Red'));
      await HiveBoxes.inspections.put(
        'def',
        _inspection(id: 'def', serial: 'D', grade: 'Green', deficiencies: true),
      );

      final byId = {for (final e in await repo.listEquipment()) e.id: e};
      expect(byId['ok']!.status, EquipmentStatus.active);
      expect(byId['amber']!.status, EquipmentStatus.maintenance);
      expect(byId['red']!.status, EquipmentStatus.maintenance);
      expect(byId['def']!.status, EquipmentStatus.maintenance);
    });

    test('names a unit by make and model, falling back to site then address',
        () async {
      await HiveBoxes.inspections.put(
        'named',
        _inspection(id: 'named', serial: 'A', make: 'Kohler', model: 'KD500'),
      );
      await HiveBoxes.inspections.put(
        'site',
        _inspection(id: 'site', serial: 'B', make: '', model: '',
            siteCode: 'AS-77'),
      );
      await HiveBoxes.inspections.put(
        'addr',
        _inspection(id: 'addr', serial: 'C', make: '', model: '',
            siteCode: '', address: '9 Wall St'),
      );

      final byId = {for (final e in await repo.listEquipment()) e.id: e};
      expect(byId['named']!.name, 'Kohler KD500');
      expect(byId['site']!.name, 'AS-77');
      expect(byId['addr']!.name, '9 Wall St');
    });

    test('sorts by most recently inspected first', () async {
      await HiveBoxes.inspections.put(
        'a',
        _inspection(id: 'a', serial: 'A', serviceDate: DateTime(2026, 1, 1)),
      );
      await HiveBoxes.inspections.put(
        'b',
        _inspection(id: 'b', serial: 'B', serviceDate: DateTime(2026, 8, 1)),
      );

      expect(
        (await repo.listEquipment()).map((e) => e.id).toList(),
        ['b', 'a'],
      );
    });

    test('facets list only values present in the data', () async {
      await HiveBoxes.inspections.put(
        'i1',
        _inspection(id: 'i1', serial: 'A', make: 'Kohler', voltage: '240V',
            address: 'Site One'),
      );
      await HiveBoxes.inspections.put(
        'i2',
        _inspection(id: 'i2', serial: 'B', make: 'Cummins', voltage: '480V',
            address: 'Site Two'),
      );

      final facets = await repo.facets();
      expect(facets.makes, ['Cummins', 'Kohler']);
      expect(facets.voltages, ['240V', '480V']);
      expect(facets.locations, ['Site One', 'Site Two']);
    });

    test('facets skip blanks and de-duplicate', () async {
      await HiveBoxes.inspections
          .put('i1', _inspection(id: 'i1', serial: 'A', make: 'Kohler'));
      await HiveBoxes.inspections
          .put('i2', _inspection(id: 'i2', serial: 'B', make: 'Kohler'));
      await HiveBoxes.inspections
          .put('i3', _inspection(id: 'i3', serial: 'C', make: ''));

      expect((await repo.facets()).makes, ['Kohler']);
    });
  });

  group('EquipmentEntity.identityKey', () {
    test('prefers the serial number', () {
      expect(
        EquipmentEntity.identityKey(
          serialNumber: 'SN-1',
          siteCode: 'AS-1',
          make: 'Cat',
          model: 'C32',
          fallbackId: 'i1',
        ),
        'sn:sn-1',
      );
    });

    test('uses site/make/model when there is no serial', () {
      expect(
        EquipmentEntity.identityKey(
          serialNumber: '  ',
          siteCode: 'AS-1',
          make: 'Cat',
          model: 'C32',
          fallbackId: 'i1',
        ),
        'composite:as-1|cat|c32',
      );
    });

    test('falls back to the inspection id when nothing identifies the unit',
        () {
      expect(
        EquipmentEntity.identityKey(
          serialNumber: '',
          siteCode: '',
          make: '',
          model: '',
          fallbackId: 'i1',
        ),
        'id:i1',
      );
    });
  });
}
