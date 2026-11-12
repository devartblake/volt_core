import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/core/services/sync/sync_summary.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_inspection.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_maintenance_check.dart';
import 'package:voltcore/modules/fleet/infra/mappers/vehicle_inspection_supabase_mapper.dart';
import 'package:voltcore/modules/fleet/infra/repositories/vehicle_inspection_repository.dart';

VehicleInspection _full() => VehicleInspection(
      id: 'i1',
      vehicleId: 'v1',
      cadence: InspectionCadence.monthly,
      inspectedAt: DateTime.utc(2026, 11, 2, 9),
      createdAt: DateTime.utc(2026, 11, 2, 9),
      inspectorUserId: 'u1',
      inspectorName: 'Ana',
      odometer: 1234,
      results: {'tires': CheckStatus.ok, 'brakes': CheckStatus.fail},
      itemNotes: {'brakes': 'squeal'},
      notes: 'n',
      driverName: 'Sam',
      driverSignaturePath: '/x/d.png',
      dispatcherName: 'Dana',
      dispatcherSignaturePath: '/x/p.png',
      signedAt: DateTime.utc(2026, 11, 2, 10),
    );

void main() {
  group('row mapping', () {
    test('round-trips every field through payload', () {
      final i = _full();
      final row = vehicleInspectionToRow(i,
          tenantId: 't', userId: 'u9', updatedAt: DateTime.utc(2026, 11, 3));
      expect(row['tenant_id'], 't');
      expect(row['cadence'], 'monthly');
      expect(row['issue_count'], 1);
      expect(row['fail_count'], 1);
      expect(row['inspector_user_id'], 'u1');
      expect(row['updated_by'], 'u9');
      final back = vehicleInspectionFromRow(row)!;
      expect(back.toMap(), i.toMap());
      expect(vehicleInspectionRowUpdatedAt(row), DateTime.utc(2026, 11, 3));
    });

    test('inspector falls back to the signed-in user', () {
      final i = VehicleInspection.newDraft(
          vehicleId: 'v', cadence: InspectionCadence.daily);
      final row = vehicleInspectionToRow(i,
          tenantId: 't', userId: 'u9', updatedAt: DateTime.utc(2026));
      expect(row['inspector_user_id'], 'u9');
    });

    test('row without payload rebuilds from columns', () {
      final back = vehicleInspectionFromRow({
        'id': 'a',
        'vehicle_id': 'v',
        'cadence': 'daily',
        'inspected_at': '2026-11-01T08:00:00Z',
        'odometer': 5,
      })!;
      expect(back.id, 'a');
      expect(back.cadence, InspectionCadence.daily);
      expect(back.odometer, 5);
    });

    test('friendly name', () {
      expect(friendlyTableName('vehicle_inspections'), 'Vehicle inspections');
    });
  });

  group('repository sync', () {
    late Directory dir;
    late Box<String> box;
    late Box<String> sync;
    late List<Map<String, dynamic>> upserts;
    late List<String> deletes;
    late List<Map<String, dynamic>> cloud;
    String? tenant = 't';
    var clock = DateTime.utc(2026, 11, 5);

    VehicleInspectionRepository repo() => VehicleInspectionRepository(
          box: box,
          syncBox: sync,
          upsert: (t, id, row) async {
            expect(t, 'vehicle_inspections');
            upserts.add(row);
          },
          delete: (t, id) async => deletes.add(id),
          fetch: ({vehicleId}) async => cloud,
          tenantId: () => tenant,
          userId: () => 'u9',
          now: () => clock,
        );

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('vi_sync');
      Hive.init(dir.path);
      box = await Hive.openBox<String>('vi');
      sync = await Hive.openBox<String>('vis');
      upserts = [];
      deletes = [];
      cloud = [];
      tenant = 't';
      clock = DateTime.utc(2026, 11, 5);
    });

    tearDown(() async {
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('save stores locally and queues an upsert', () async {
      await repo().save(_full());
      expect(box.length, 1);
      expect(upserts.single['id'], 'i1');
      expect(upserts.single['updated_at'], clock.toIso8601String());
    });

    test('delete removes locally and queues a delete', () async {
      final r = repo();
      await r.save(_full());
      await r.delete('i1');
      expect(box.length, 0);
      expect(deletes, ['i1']);
    });

    test('backfill queues unsynced local records once', () async {
      await box.put('i1', _full().toJson());
      final r = repo();
      expect(await r.backfillUnsynced(), 1);
      expect(await r.backfillUnsynced(), 0);
      expect(upserts.length, 1);
    });

    test('backfill waits for a tenant and then queues', () async {
      await box.put('i1', _full().toJson());
      tenant = null;
      final r = repo();
      expect(await r.backfillUnsynced(), 0);
      tenant = 't';
      expect(await r.backfillUnsynced(), 1);
    });

    test('refresh adds unknown cloud rows and keeps a newer local copy',
        () async {
      final r = repo();
      final remoteOnly = _full().copyWith(notes: 'remote');
      final other = VehicleInspection(
        id: 'i2',
        vehicleId: 'v1',
        cadence: InspectionCadence.daily,
        inspectedAt: DateTime.utc(2026, 11, 1),
        createdAt: DateTime.utc(2026, 11, 1),
      );
      await r.save(other); // local i2 written at clock (Nov 5)
      cloud = [
        vehicleInspectionToRow(remoteOnly,
            tenantId: 't', updatedAt: DateTime.utc(2026, 11, 4)),
        // older than local i2: ignored
        vehicleInspectionToRow(other.copyWith(notes: 'stale'),
            tenantId: 't', updatedAt: DateTime.utc(2026, 11, 1)),
      ];
      expect(await r.refreshFromCloud(), 1);
      expect((await r.listAll()).length, 2);
      final i2 = (await r.listForVehicle('v1')).firstWhere((x) => x.id == 'i2');
      expect(i2.notes, '');
    });

    test('refresh replaces local with a newer cloud copy', () async {
      final r = repo();
      await r.save(_full());
      cloud = [
        vehicleInspectionToRow(_full().copyWith(notes: 'edited elsewhere'),
            tenantId: 't', updatedAt: DateTime.utc(2026, 11, 6)),
      ];
      expect(await r.refreshFromCloud(), 1);
      expect((await r.listAll()).single.notes, 'edited elsewhere');
    });

    test('a locally deleted record is not resurrected by a pull', () async {
      final r = repo();
      await r.save(_full());
      await r.delete('i1');
      cloud = [
        vehicleInspectionToRow(_full(),
            tenantId: 't', updatedAt: DateTime.utc(2026, 11, 9)),
      ];
      expect(await r.refreshFromCloud(), 0);
      expect(await r.listAll(), isEmpty);
    });

    test('refresh never throws', () async {
      final bad = VehicleInspectionRepository(
        box: box,
        syncBox: sync,
        fetch: ({vehicleId}) async => throw StateError('offline'),
        tenantId: () => 't',
        upsert: (a, b, c) async {},
      );
      expect(await bad.refreshFromCloud(), 0);
    });
  });
}
