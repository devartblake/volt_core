import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/core/services/hive/hive_boxes.dart';
import 'package:voltcore/modules/equipment/domain/entities/equipment_entity.dart';
import 'package:voltcore/modules/equipment/infra/datasources/equipment_remote_datasource.dart';
import 'package:voltcore/modules/equipment/infra/mappers/equipment_supabase_mapper.dart';
import 'package:voltcore/modules/equipment/infra/repositories/equipment_repository_impl.dart';
import 'package:voltcore/modules/inspections/infra/models/inspection.dart';
import 'package:voltcore/modules/inspections/infra/models/nameplate_data.dart';

/// Stands in for the shared `equipment` table.
class _FakeRemote implements EquipmentRemoteDatasource {
  _FakeRemote(this.rows);

  final List<Map<String, dynamic>> rows;
  bool throwOnList = false;

  @override
  Future<List<RemoteEquipmentRow>> list() async {
    if (throwOnList) throw StateError('network down');
    return rows
        .map((r) => RemoteEquipmentRow(identityKey: identityKeyOf(r), raw: r))
        .toList();
  }
}

Map<String, dynamic> _remoteRow({
  required String identityKey,
  String name = 'Remote Unit',
  String make = 'Kohler',
  String serial = 'REM-1',
  String status = 'active',
  String? latestInspectionId,
  DateTime? lastInspection,
}) {
  return {
    'id': '11111111-1111-1111-1111-111111111111',
    'identity_key': identityKey,
    'name': name,
    'asset_type': 'transferSwitch',
    'metadata': {'amp_rating': 400},
    'make': make,
    'model': 'KD500',
    'serial_number': serial,
    'voltage': '480V',
    'location': 'Remote site',
    'site_code': 'RM-1',
    'site_grade': 'Green',
    'status': status,
    'last_inspection_at': lastInspection?.toIso8601String(),
    'inspection_count': 3,
    'latest_inspection_id': latestInspectionId,
  };
}

Inspection _inspection({
  required String id,
  String serial = 'LOCAL-1',
  String make = 'Caterpillar',
  DateTime? serviceDate,
}) {
  return Inspection(
    id: id,
    createdAt: DateTime(2026, 1, 1),
    siteCode: 'AS-100',
    siteGrade: 'Green',
    address: '100 Broadway',
    serviceDate: serviceDate ?? DateTime(2026, 6, 1),
    technicianName: 'Alex',
    generatorMake: make,
    generatorModel: 'C32',
    generatorSerial: serial,
    voltageRating: '480V',
  );
}

void main() {
  group('equipmentIdFor', () {
    test('is deterministic for the same tenant and identity', () {
      final a = equipmentIdFor(tenantId: 't1', identityKey: 'sn:cat-001');
      final b = equipmentIdFor(tenantId: 't1', identityKey: 'sn:cat-001');

      // This is what lets two devices upsert the same row instead of creating
      // duplicates — the sync queue has no conflict-target support.
      expect(a, b);
    });

    test('differs per unit and per tenant', () {
      final unitA = equipmentIdFor(tenantId: 't1', identityKey: 'sn:a');
      final unitB = equipmentIdFor(tenantId: 't1', identityKey: 'sn:b');
      final otherTenant = equipmentIdFor(tenantId: 't2', identityKey: 'sn:a');

      expect(unitA, isNot(unitB));
      expect(unitA, isNot(otherTenant));
    });

    test('produces a well-formed uuid', () {
      final id = equipmentIdFor(tenantId: 't1', identityKey: 'sn:cat-001');
      expect(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-5[0-9a-f]{3}-[89ab][0-9a-f]{3}-'
          r'[0-9a-f]{12}$',
        ).hasMatch(id),
        isTrue,
        reason: 'expected a v5 uuid, got $id',
      );
    });
  });

  group('equipment row mapping', () {
    test('round-trips through the Supabase shape', () {
      const unit = EquipmentEntity(
        id: 'insp-9',
        name: 'Cummins QSX15',
        make: 'Cummins',
        model: 'QSX15',
        serialNumber: 'CUM-99',
        voltage: '208V',
        location: '9 Wall St',
        assetType: AssetType.transferSwitch,
        metadata: {'amp_rating': 400},
        siteCode: 'AS-9',
        siteGrade: 'Amber',
        inspectionCount: 2,
        status: EquipmentStatus.maintenance,
      );

      final row = equipmentToSupabaseJson(
        unit,
        identityKey: 'sn:cum-99',
        tenantId: 'tenant-1',
      );

      expect(row['identity_key'], 'sn:cum-99');
      expect(row['tenant_id'], 'tenant-1');
      expect(row['status'], 'maintenance');
      expect(row['asset_type'], 'transferSwitch');
      expect(row['metadata'], {'amp_rating': 400});
      // The deep-link target travels separately from the row id.
      expect(row['latest_inspection_id'], 'insp-9');
      expect(
        row['id'],
        equipmentIdFor(tenantId: 'tenant-1', identityKey: 'sn:cum-99'),
      );

      final back = equipmentFromSupabaseJson(row);
      expect(back.serialNumber, 'CUM-99');
      expect(back.status, EquipmentStatus.maintenance);
      expect(back.assetType, AssetType.transferSwitch);
      expect(back.metadata, {'amp_rating': 400});
      expect(back.id, 'insp-9');
    });

    test(
      'a row never inspected here keeps its row id but cannot open a nameplate',
      () {
        final unit = equipmentFromSupabaseJson(
          _remoteRow(identityKey: 'sn:rem-1', latestInspectionId: null),
        );
        expect(unit.id, '11111111-1111-1111-1111-111111111111');
        expect(unit.hasInspectionLink, isFalse);
      },
    );

    test('a row with an inspection id can open its nameplate record', () {
      final unit = equipmentFromSupabaseJson(
        _remoteRow(identityKey: 'sn:inspected', latestInspectionId: 'insp-7'),
      );

      expect(unit.id, 'insp-7');
      expect(unit.hasInspectionLink, isTrue);
    });

    test('a manually registered asset has no inspection deep link', () {
      const unit = EquipmentEntity(
        id: '22222222-2222-2222-2222-222222222222',
        name: 'Main ATS',
        make: 'ASCO',
        model: '7000',
        serialNumber: 'ATS-9',
        voltage: '480V',
        location: 'Electrical room',
        assetType: AssetType.transferSwitch,
        metadata: {'notes': 'Annual service due'},
        hasInspectionLink: false,
        status: EquipmentStatus.inactive,
      );

      final row = equipmentToSupabaseJson(
        unit,
        identityKey: 'sn:ats-9',
        tenantId: 'tenant-1',
      );

      expect(row['latest_inspection_id'], isNull);
      expect(row['is_manual'], isTrue);
      expect(row['notes'], 'Annual service due');
      expect(equipmentFromSupabaseJson(row).hasInspectionLink, isFalse);
    });

    test('an unknown status degrades to active rather than throwing', () {
      final unit = equipmentFromSupabaseJson(
        _remoteRow(identityKey: 'sn:x', status: 'decommissioned'),
      );
      expect(unit.status, EquipmentStatus.active);
    });
  });

  group('local/remote merge', () {
    late Directory tempDir;

    setUpAll(() {
      Hive.registerAdapter(InspectionAdapter());
      Hive.registerAdapter(NameplateDataAdapter());
    });

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('voltcore_eq_sync_test');
      Hive.init(tempDir.path);
      HiveBoxes.inspections = await Hive.openBox<Inspection>(
        HiveBoxes.inspectionsBoxName,
      );
      HiveBoxes.nameplates = await Hive.openBox<NameplateData>(
        HiveBoxes.nameplatesBoxName,
      );
    });

    tearDown(() async {
      await Hive.deleteBoxFromDisk(HiveBoxes.inspectionsBoxName);
      await Hive.deleteBoxFromDisk(HiveBoxes.nameplatesBoxName);
      await Hive.close();
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('surfaces units this device has never inspected', () async {
      await HiveBoxes.inspections.put(
        'i1',
        _inspection(id: 'i1', serial: 'LOCAL-1'),
      );

      final repo = EquipmentRepositoryImpl(
        remote: _FakeRemote([_remoteRow(identityKey: 'sn:rem-1')]),
      );

      final serials = (await repo.listEquipment())
          .map((e) => e.serialNumber)
          .toSet();
      expect(serials, containsAll(['LOCAL-1', 'REM-1']));
    });

    test('local data wins when both sources know the same unit', () async {
      await HiveBoxes.inspections.put(
        'i1',
        _inspection(id: 'i1', serial: 'SHARED', make: 'LocalMake'),
      );

      final repo = EquipmentRepositoryImpl(
        remote: _FakeRemote([
          _remoteRow(identityKey: 'sn:shared', make: 'StaleRemoteMake'),
        ]),
      );

      final units = await repo.listEquipment();
      expect(units.length, 1);
      expect(units.single.make, 'LocalMake');
    });

    test('a registry with only remote units still works', () async {
      final repo = EquipmentRepositoryImpl(
        remote: _FakeRemote([
          _remoteRow(identityKey: 'sn:a', serial: 'A'),
          _remoteRow(identityKey: 'sn:b', serial: 'B'),
        ]),
      );

      expect((await repo.listEquipment()).length, 2);
    });

    test(
      'a remote failure degrades to local data instead of erroring',
      () async {
        await HiveBoxes.inspections.put(
          'i1',
          _inspection(id: 'i1', serial: 'LOCAL-1'),
        );

        final remote = _FakeRemote([])..throwOnList = true;
        final repo = EquipmentRepositoryImpl(remote: remote);

        final units = await repo.listEquipment();
        expect(units.single.serialNumber, 'LOCAL-1');
      },
    );

    test(
      'rows with no identity key are skipped rather than merged blindly',
      () async {
        final repo = EquipmentRepositoryImpl(
          remote: _FakeRemote([
            _remoteRow(identityKey: '', serial: 'ORPHAN'),
            _remoteRow(identityKey: 'sn:ok', serial: 'OK'),
          ]),
        );

        final serials = (await repo.listEquipment())
            .map((e) => e.serialNumber)
            .toList();
        expect(serials, ['OK']);
      },
    );

    test('facets include remote-only units', () async {
      final repo = EquipmentRepositoryImpl(
        remote: _FakeRemote([
          _remoteRow(identityKey: 'sn:rem-1', make: 'Kohler'),
        ]),
      );

      final facets = await repo.facets();
      expect(facets.makes, contains('Kohler'));
      expect(facets.assetTypes, contains(AssetType.transferSwitch));
    });
  });
}
