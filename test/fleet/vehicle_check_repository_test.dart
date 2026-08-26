import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_entity.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_maintenance_check.dart';
import 'package:voltcore/modules/fleet/infra/mappers/vehicle_maintenance_check_supabase_mapper.dart';
import 'package:voltcore/modules/fleet/infra/models/vehicle_maintenance_check_record.dart';
import 'package:voltcore/modules/fleet/infra/models/vehicle_record.dart';
import 'package:voltcore/modules/fleet/infra/repositories/vehicle_check_repository.dart';
import 'package:voltcore/modules/fleet/infra/repositories/vehicle_repository_impl.dart';

const String _tenant = 'tenant-1';

void main() {
  late Box<VehicleRecord> vehicleBox;
  late Box<VehicleMaintenanceCheckRecord> checkBox;
  late VehicleRepositoryImpl vehicles;
  late VehicleCheckRepositoryImpl checks;
  late List<VehicleMaintenanceCheck> queued;

  setUpAll(() {
    Hive.init('.dart_tool/fleet_check_test_hive');
    if (!Hive.isAdapterRegistered(kVehicleRecordTypeId)) {
      Hive.registerAdapter(VehicleRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(kVehicleMaintenanceCheckTypeId)) {
      Hive.registerAdapter(VehicleMaintenanceCheckRecordAdapter());
    }
  });

  setUp(() async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    vehicleBox = await Hive.openBox<VehicleRecord>('cv_$stamp');
    checkBox = await Hive.openBox<VehicleMaintenanceCheckRecord>('cc_$stamp');
    queued = [];

    vehicles = VehicleRepositoryImpl(
      box: vehicleBox,
      tenantIdReader: () => _tenant,
      queueWriter: (_) async {},
    );
    checks = VehicleCheckRepositoryImpl(
      vehicles: vehicles,
      box: checkBox,
      tenantIdReader: () => _tenant,
      queueWriter: (check) async => queued.add(check),
      // No Supabase client: hydration is best-effort and not what these assert.
    );
  });

  tearDown(() async {
    await vehicleBox.deleteFromDisk();
    await checkBox.deleteFromDisk();
  });

  Future<VehicleEntity> givenVehicle({int odometer = 50000}) {
    return vehicles.save(
      VehicleEntity.newDraft(tenantId: _tenant)
          .copyWith(designation: 'Truck A', odometer: odometer),
    );
  }

  VehicleMaintenanceCheck draftFor(
    VehicleEntity vehicle, {
    int? odometer,
    DateTime? checkedAt,
  }) {
    final base = VehicleMaintenanceCheck.newDraft(
      tenantId: _tenant,
      vehicleId: vehicle.id,
      odometer: odometer ?? vehicle.odometer,
    );
    return checkedAt == null ? base : base.copyWith(checkedAt: checkedAt);
  }

  group('save', () {
    test('persists, enqueues, and advances the vehicle', () async {
      final vehicle = await givenVehicle(odometer: 50000);
      final saved = await checks.save(draftFor(vehicle, odometer: 55779));

      expect(checkBox.get(saved.id), isNotNull);
      expect(queued, hasLength(1));

      final updated = await vehicles.getById(vehicle.id);
      expect(updated!.odometer, 55779);
      expect(updated.lastCheckAt, isNotNull);
    });

    test('the queued payload carries tenant_id', () async {
      final vehicle = await givenVehicle();
      await checks.save(draftFor(vehicle));

      expect(vehicleCheckToSupabaseJson(queued.single)['tenant_id'], _tenant);
    });

    test('refuses an odometer that went backwards', () async {
      // Overwhelmingly a transposed digit on a six-figure number. Catching it
      // here beats a fleet list that quietly reports the wrong mileage.
      final vehicle = await givenVehicle(odometer: 55779);

      expect(
        () => checks.save(draftFor(vehicle, odometer: 5779)),
        throwsA(
          isA<OdometerWentBackwards>()
              .having((e) => e.recorded, 'recorded', 5779)
              .having((e) => e.previous, 'previous', 55779),
        ),
      );
      expect(queued, isEmpty);
    });

    test('accepts a rollback when explicitly allowed', () async {
      // The legitimate case: the cluster was replaced.
      final vehicle = await givenVehicle(odometer: 55779);
      final saved = await checks.save(
        draftFor(vehicle, odometer: 12),
        allowOdometerRollback: true,
      );

      expect(saved.odometer, 12);
      // The vehicle keeps the higher reading — the check records what the new
      // cluster shows, but the fleet list must not claim the van has done
      // fewer miles than it has.
      final updated = await vehicles.getById(vehicle.id);
      expect(updated!.odometer, 55779);
    });

    test('a backdated check does not drag the vehicle back', () async {
      final vehicle = await givenVehicle(odometer: 50000);
      await checks.save(
        draftFor(vehicle, odometer: 55779, checkedAt: DateTime.utc(2026, 6, 1)),
      );
      final afterRecent = await vehicles.getById(vehicle.id);

      // A check for March, entered in June, must not become "last checked".
      await checks.save(
        draftFor(vehicle, odometer: 55779, checkedAt: DateTime.utc(2026, 3, 1)),
      );
      final afterBackdated = await vehicles.getById(vehicle.id);

      expect(afterBackdated!.lastCheckAt, afterRecent!.lastCheckAt);
      expect(afterBackdated.odometer, 55779);
    });

    test('a backdated check with a higher reading advances only the odometer',
        () async {
      // Checks entered out of order: the June walk-around is typed in first
      // with a low reading, then March's is caught up with a higher one. The
      // odometer must take the higher number, but "last checked" must stay on
      // the later date — otherwise the fleet list reports the van as more
      // recently inspected than it is.
      final vehicle = await givenVehicle(odometer: 40000);

      await checks.save(
        draftFor(vehicle, odometer: 41000, checkedAt: DateTime.utc(2026, 6, 1)),
      );
      await checks.save(
        draftFor(vehicle, odometer: 55779, checkedAt: DateTime.utc(2026, 3, 1)),
      );

      final updated = await vehicles.getById(vehicle.id);
      expect(updated!.odometer, 55779);
      expect(updated.lastCheckAt, DateTime.utc(2026, 6, 1));
    });

    test('refuses a check for an unknown vehicle', () async {
      final orphan = VehicleMaintenanceCheck.newDraft(
        tenantId: _tenant,
        vehicleId: 'nope',
      );
      expect(() => checks.save(orphan), throwsA(isA<StateError>()));
    });

    test('refuses a check in another tenant', () async {
      final vehicle = await givenVehicle();
      final foreign = VehicleMaintenanceCheck.newDraft(
        tenantId: 'tenant-2',
        vehicleId: vehicle.id,
      );
      expect(() => checks.save(foreign), throwsA(isA<StateError>()));
    });
  });

  group('listForVehicle', () {
    test('returns newest first and only for that vehicle', () async {
      final a = await givenVehicle(odometer: 1000);
      final b = await vehicles.save(
        VehicleEntity.newDraft(tenantId: _tenant)
            .copyWith(designation: 'Van B', odometer: 2000),
      );

      await checks.save(
        draftFor(a, odometer: 1100, checkedAt: DateTime.utc(2026, 1, 1)),
      );
      await checks.save(
        draftFor(a, odometer: 1200, checkedAt: DateTime.utc(2026, 5, 1)),
      );
      await checks.save(draftFor(b, odometer: 2100));

      final history = await checks.listForVehicle(a.id);
      expect(history, hasLength(2));
      expect(history.first.checkedAt, DateTime.utc(2026, 5, 1));
      expect(history.last.checkedAt, DateTime.utc(2026, 1, 1));
    });

    test('is empty for a vehicle with no checks', () async {
      final vehicle = await givenVehicle();
      expect(await checks.listForVehicle(vehicle.id), isEmpty);
    });
  });

  group('domain', () {
    test('milesSinceService needs both ends and never goes negative', () {
      final base = VehicleMaintenanceCheck.newDraft(
        tenantId: _tenant,
        vehicleId: 'v1',
        odometer: 55779,
      );

      expect(base.milesSinceService, isNull);
      expect(base.copyWith(odometerAtLastService: 50000).milesSinceService, 5779);
      // A last-service reading above the current one is nonsense, not a
      // negative interval.
      expect(base.copyWith(odometerAtLastService: 60000).milesSinceService, isNull);
    });

    test('needsFollowUp is true when either component is not ok', () {
      final base = VehicleMaintenanceCheck.newDraft(
        tenantId: _tenant,
        vehicleId: 'v1',
      );
      expect(base.needsFollowUp, isFalse);
      expect(base.copyWith(brakeStatus: CheckStatus.attention).needsFollowUp, isTrue);
      expect(base.copyWith(batteryStatus: CheckStatus.fail).needsFollowUp, isTrue);
    });

    test('check statuses round-trip and degrade safely', () {
      for (final status in CheckStatus.values) {
        expect(CheckStatusX.fromWire(status.wire), status);
      }
      expect(CheckStatusX.fromWire('exploded'), CheckStatus.ok);
      expect(CheckStatusX.fromWire(null), CheckStatus.ok);
    });
  });

  group('supabase mapper', () {
    test('sends dates as calendar days, not instants', () {
      // A `date` column round-trips a timestamp back with a time component the
      // user never entered, which renders as a different day either side of
      // midnight.
      final check = VehicleMaintenanceCheck.newDraft(
        tenantId: _tenant,
        vehicleId: 'v1',
      ).copyWith(lastOilChangeAt: DateTime(2026, 6, 5, 23, 30));

      expect(vehicleCheckToSupabaseJson(check)['last_oil_change_at'], '2026-06-05');
    });

    test('round-trips a check', () {
      final original = VehicleMaintenanceCheck.newDraft(
        tenantId: _tenant,
        vehicleId: 'v1',
        odometer: 55779,
      ).copyWith(
        odometerAtLastService: 50000,
        brakeStatus: CheckStatus.attention,
        batteryStatus: CheckStatus.fail,
        notes: 'Pads at 3mm',
      );

      final restored =
          vehicleCheckFromSupabaseJson(vehicleCheckToSupabaseJson(original));

      expect(restored.odometer, 55779);
      expect(restored.odometerAtLastService, 50000);
      expect(restored.brakeStatus, CheckStatus.attention);
      expect(restored.batteryStatus, CheckStatus.fail);
      expect(restored.notes, 'Pads at 3mm');
      expect(restored.milesSinceService, 5779);
    });
  });
}
