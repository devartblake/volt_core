import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_entity.dart';
import 'package:voltcore/modules/fleet/infra/mappers/vehicle_supabase_mapper.dart';
import 'package:voltcore/modules/fleet/infra/models/vehicle_record.dart';
import 'package:voltcore/modules/fleet/infra/repositories/vehicle_repository_impl.dart';

const String _tenant = 'tenant-1';
const String _otherTenant = 'tenant-2';

void main() {
  late Box<VehicleRecord> box;
  late List<VehicleEntity> queued;
  late VehicleRepositoryImpl repository;

  setUpAll(() {
    Hive.init('.dart_tool/fleet_test_hive');
    if (!Hive.isAdapterRegistered(kVehicleRecordTypeId)) {
      Hive.registerAdapter(VehicleRecordAdapter());
    }
  });

  setUp(() async {
    box = await Hive.openBox<VehicleRecord>(
      'vehicles_${DateTime.now().microsecondsSinceEpoch}',
    );
    queued = [];
    repository = VehicleRepositoryImpl(
      box: box,
      tenantIdReader: () => _tenant,
      queueWriter: (vehicle) async => queued.add(vehicle),
      // No remote: hydration is best-effort and not what these assert.
    );
  });

  tearDown(() async => box.deleteFromDisk());

  VehicleEntity draft({
    String designation = 'Truck A',
    String tenantId = _tenant,
  }) =>
      VehicleEntity.newDraft(tenantId: tenantId).copyWith(
        designation: designation,
      );

  group('save', () {
    test('persists locally and enqueues for sync', () async {
      final saved = await repository.save(draft());

      expect(box.get(saved.id), isNotNull);
      expect(queued, hasLength(1));
      expect(queued.single.id, saved.id);
    });

    test('the queued payload carries tenant_id', () async {
      // Without it the sync queue's tenant re-stamp skips the row entirely —
      // retagQueuedRow only touches payloads that already have the column — so
      // a stale tenant could never be healed and the row would 42501 forever.
      await repository.save(draft());
      final row = vehicleToSupabaseJson(queued.single);

      expect(row['tenant_id'], _tenant);
    });

    test('trims and upper-cases the VIN on the way in', () async {
      final saved = await repository.save(
        draft().copyWith(vin: ' 1ftnr1zm7fkb20115 '),
      );
      expect(saved.vin, '1FTNR1ZM7FKB20115');
    });

    test('stores a blank VIN as null, not empty string', () async {
      // The unique index on (tenant_id, vin) is partial — `where vin is not
      // null`. Storing '' would make every un-VINed vehicle collide with every
      // other one.
      final saved = await repository.save(draft().copyWith(vin: '   '));
      expect(saved.vin, isNull);
      expect(vehicleToSupabaseJson(saved)['vin'], isNull);
    });

    test('refuses a blank designation', () async {
      expect(
        () => repository.save(draft(designation: '  ')),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('refuses a malformed VIN before it reaches the server', () async {
      expect(
        () => repository.save(draft().copyWith(vin: 'TOO-SHORT')),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('refuses a duplicate designation', () async {
      // Caught here rather than surfacing as an opaque 23505 from the partial
      // unique index seconds later, once the technician has moved on.
      await repository.save(draft());
      expect(
        () => repository.save(draft()),
        throwsA(
          isA<StateError>().having((e) => e.message, 'message', contains('Truck A')),
        ),
      );
    });

    test('allows reusing the designation of a retired vehicle', () async {
      final old = await repository.save(draft());
      await repository.save(old.copyWith(status: VehicleStatus.retired));

      // A replacement van inherits the name off the board.
      await repository.save(draft());
      final all = await repository.list();
      expect(all.where((v) => v.designation == 'Truck A'), hasLength(2));
    });

    test('refuses a duplicate VIN and names the other vehicle', () async {
      await repository.save(draft().copyWith(vin: '1FTNR1ZM7FKB20115'));
      expect(
        () => repository.save(
          draft(designation: 'Van B').copyWith(vin: '1ftnr1zm7fkb20115'),
        ),
        throwsA(
          isA<StateError>()
              .having((e) => e.message, 'message', contains('Truck A')),
        ),
      );
    });

    test('refuses to save into another tenant', () async {
      expect(
        () => repository.save(draft(tenantId: _otherTenant)),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('list', () {
    test('excludes other tenants', () async {
      await repository.save(draft());
      await box.put(
        'foreign',
        VehicleRecord(
          id: 'foreign',
          tenantId: _otherTenant,
          designation: 'Not ours',
          createdAt: DateTime.now().toUtc(),
          updatedAt: DateTime.now().toUtc(),
        ),
      );

      final all = await repository.list();
      expect(all, hasLength(1));
      expect(all.single.designation, 'Truck A');
    });

    test('narrows to one technician when asked', () async {
      // This is the local mirror of the RLS rule that lets a tech see only the
      // vehicle they are stationed to.
      final mine = await repository.save(draft(designation: 'Truck A'));
      await repository.assign(mine.id, 'user-9');
      await repository.save(draft(designation: 'Van B'));

      final scoped = await repository.list(assignedToUserId: 'user-9');
      expect(scoped, hasLength(1));
      expect(scoped.single.designation, 'Truck A');

      expect(await repository.list(), hasLength(2));
    });

    test('sorts by designation, retired last', () async {
      await repository.save(draft(designation: 'Van C'));
      await repository.save(draft(designation: 'Truck A'));
      final retired = await repository.save(draft(designation: 'Alpha Van'));
      await repository.save(retired.copyWith(status: VehicleStatus.retired));

      final all = await repository.list();
      expect(
        all.map((v) => v.designation),
        ['Truck A', 'Van C', 'Alpha Van'],
      );
    });
  });

  group('assign', () {
    test('sets and clears the stationed technician', () async {
      final vehicle = await repository.save(draft());

      final assigned = await repository.assign(vehicle.id, 'user-9');
      expect(assigned.assignedToUserId, 'user-9');

      final cleared = await repository.assign(vehicle.id, null);
      expect(cleared.assignedToUserId, isNull);
      // Taking the vehicle off a technician has to reach the server, or their
      // device keeps showing it.
      expect(vehicleToSupabaseJson(cleared)['assigned_to_user_id'], isNull);
    });

    test('treats blank as unassigned', () async {
      final vehicle = await repository.save(draft());
      await repository.assign(vehicle.id, 'user-9');

      final cleared = await repository.assign(vehicle.id, '   ');
      expect(cleared.assignedToUserId, isNull);
    });

    test('throws for an unknown vehicle', () async {
      expect(
        () => repository.assign('nope', 'user-9'),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('supabase mapper', () {
    test('round-trips a vehicle', () {
      final original = draft().copyWith(
        vin: '1FTNR1ZM7FKB20115',
        licensePlate: 'ABC-1234',
        make: 'Ford',
        model: 'Transit',
        modelYear: 2021,
        odometer: 55779,
        status: VehicleStatus.outOfService,
        vehicleType: VehicleType.truck,
        assignedToUserId: 'user-9',
        notes: 'Rear door sticks',
      );

      final restored = vehicleFromSupabaseJson(vehicleToSupabaseJson(original));

      expect(restored.designation, original.designation);
      expect(restored.vin, original.vin);
      expect(restored.licensePlate, original.licensePlate);
      expect(restored.makeModel, 'Ford Transit');
      expect(restored.modelYear, 2021);
      expect(restored.odometer, 55779);
      expect(restored.status, VehicleStatus.outOfService);
      expect(restored.vehicleType, VehicleType.truck);
      expect(restored.assignedToUserId, 'user-9');
      expect(restored.notes, 'Rear door sticks');
    });

    test('sends the status the check constraint accepts', () {
      final row = vehicleToSupabaseJson(
        draft().copyWith(status: VehicleStatus.outOfService),
      );
      expect(row['status'], 'out_of_service');
      expect(row['status'], isNot('outOfService'));
    });
  });
}
