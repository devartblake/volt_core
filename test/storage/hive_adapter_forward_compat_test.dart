import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/modules/fleet/infra/models/vehicle_asset_catalog_item_record.dart';
import 'package:voltcore/modules/fleet/infra/models/vehicle_asset_record.dart';
import 'package:voltcore/modules/fleet/infra/models/vehicle_maintenance_check_record.dart';
import 'package:voltcore/modules/fleet/infra/models/vehicle_record.dart';
import 'package:voltcore/modules/inspections/domain/entities/inspection_entity.dart';
import 'package:voltcore/modules/inspections/infra/models/inspection.dart';
import 'package:voltcore/modules/inspections/infra/models/nameplate_data.dart';
import 'package:voltcore/modules/load_test/infra/models/load_test_record.dart';
import 'package:voltcore/modules/load_test/infra/models/test_interval_record.dart';
import 'package:voltcore/modules/maintenance/infra/models/maintenance_record.dart';
import 'package:voltcore/modules/schedule/infra/models/schedule_task.dart';
import 'package:voltcore/modules/templates/infra/models/form_response_record.dart';
import 'package:voltcore/modules/work_orders/infra/models/work_order_record.dart';

import '../support/hive_adapter_probe.dart';

/// One persisted model and how many fields its adapter writes today.
///
/// [fieldCountAtLastRelease] is the watermark: rows on devices in the field
/// were written by a build with that many fields, so the adapter must still
/// decode a row truncated to it. Today it equals the current count for every
/// model except Inspection, whose address split already added five.
///
/// **When you add a field, bump [currentFieldCount] and leave
/// [fieldCountAtLastRelease] alone.** The gap between them is what gets
/// replayed, and it is what catches a field that cannot tolerate being
/// absent. See HiveAdapterProbe for the two ways to make one that can.
class _AdapterCase<T> {
  const _AdapterCase({
    required this.name,
    required this.adapter,
    required this.sample,
    required this.currentFieldCount,
    required this.fieldCountAtLastRelease,
  });

  final String name;
  final TypeAdapter<T> adapter;
  final T Function() sample;
  final int currentFieldCount;
  final int fieldCountAtLastRelease;

  void run() {
    final probe = HiveAdapterProbe<T>(adapter);

    group(name, () {
      test('declares exactly as many fields as it writes', () {
        final row = probe.encode(sample());

        expect(row.declaredCount, row.fields.length);
        expect(row.declaredCount, currentFieldCount);
        expect(row.fields.map((f) => f.key).toSet(), hasLength(currentFieldCount));
      });

      test('round-trips a full row', () {
        final row = probe.encode(sample());
        final restored = probe.readTruncatedTo(currentFieldCount, sample());

        expect(restored, isA<T>());
        expect(probe.encode(restored).fields.length, row.fields.length);
      });

      for (var size = fieldCountAtLastRelease;
          size < currentFieldCount;
          size++) {
        test('decodes a row written when it had $size fields', () {
          // Not an abstract worry: this is a record sitting on a technician's
          // tablet right now. If this throws, so does their whole list.
          expect(
            () => probe.readTruncatedTo(size, sample()),
            returnsNormally,
            reason: 'Field $size cannot tolerate being absent. Give it '
                '@HiveField($size, defaultValue: ...) or a nullable '
                'constructor parameter — see HiveAdapterProbe.',
          );
        });
      }
    });
  }
}

void main() {
  final now = DateTime.utc(2026, 1, 1);

  final cases = <_AdapterCase>[
    _AdapterCase<Inspection>(
      name: 'InspectionAdapter',
      adapter: InspectionAdapter(),
      sample: () => inspectionFromEntity(
        InspectionEntity.newDraft().copyWith(address: 'Legacy row'),
      ),
      currentFieldCount: 66,
      // The release before the address split.
      fieldCountAtLastRelease: 61,
    ),
    _AdapterCase<NameplateData>(
      name: 'NameplateDataAdapter',
      adapter: NameplateDataAdapter(),
      sample: () => NameplateData(id: 'n1', inspectionId: 'i1'),
      currentFieldCount: 32,
      fieldCountAtLastRelease: 32,
    ),
    _AdapterCase<LoadTestRecord>(
      name: 'LoadTestRecordAdapter',
      adapter: LoadTestRecordAdapter(),
      sample: () => LoadTestRecord(id: 'l1', inspectionId: 'i1', stepIndex: 0),
      currentFieldCount: 13,
      fieldCountAtLastRelease: 13,
    ),
    _AdapterCase<TestIntervalRecord>(
      name: 'TestIntervalRecordAdapter',
      adapter: TestIntervalRecordAdapter(),
      sample: () => TestIntervalRecord(id: 't1', inspectionId: 'i1', index: 0),
      currentFieldCount: 18,
      fieldCountAtLastRelease: 18,
    ),
    _AdapterCase<MaintenanceRecord>(
      name: 'MaintenanceRecordAdapter',
      adapter: MaintenanceRecordAdapter(),
      sample: () => MaintenanceRecord(id: 'm1'),
      currentFieldCount: 117,
      fieldCountAtLastRelease: 117,
    ),
    _AdapterCase<ScheduledTask>(
      name: 'ScheduledTaskAdapter',
      adapter: ScheduledTaskAdapter(),
      sample: () => ScheduledTask(
        id: 's1',
        tenantId: 'tenant-1',
        title: 'Task',
        scheduledAt: now,
        scheduledDate: now,
        status: 'pending',
        sourceType: 'manual',
        createdAt: now,
        updatedAt: now,
      ),
      currentFieldCount: 17,
      fieldCountAtLastRelease: 17,
    ),
    _AdapterCase<WorkOrderRecord>(
      name: 'WorkOrderRecordAdapter',
      adapter: WorkOrderRecordAdapter(),
      sample: () => WorkOrderRecord(
        id: 'w1',
        tenantId: 'tenant-1',
        title: 'Work order',
        status: 'open',
        priority: 'normal',
        createdAt: now,
        updatedAt: now,
      ),
      currentFieldCount: 13,
      fieldCountAtLastRelease: 13,
    ),
    _AdapterCase<VehicleRecord>(
      name: 'VehicleRecordAdapter',
      adapter: VehicleRecordAdapter(),
      sample: () => VehicleRecord(
        id: 'v1',
        tenantId: 'tenant-1',
        designation: 'Truck A',
        createdAt: now,
        updatedAt: now,
      ),
      // Phase 2 added last_check_at as field 15.
      currentFieldCount: 16,
      fieldCountAtLastRelease: 15,
    ),
    _AdapterCase<VehicleMaintenanceCheckRecord>(
      name: 'VehicleMaintenanceCheckRecordAdapter',
      adapter: VehicleMaintenanceCheckRecordAdapter(),
      sample: () => VehicleMaintenanceCheckRecord(
        id: 'c1',
        tenantId: 'tenant-1',
        vehicleId: 'v1',
        checkedAt: now,
        createdAt: now,
        updatedAt: now,
      ),
      currentFieldCount: 14,
      fieldCountAtLastRelease: 14,
    ),
    _AdapterCase<VehicleAssetCatalogItemRecord>(
      name: 'VehicleAssetCatalogItemRecordAdapter',
      adapter: VehicleAssetCatalogItemRecordAdapter(),
      sample: () => VehicleAssetCatalogItemRecord(
        id: 'k1',
        tenantId: 'tenant-1',
        name: 'IDEAL 1/2" EMT BENDER',
        createdAt: now,
        updatedAt: now,
      ),
      currentFieldCount: 9,
      fieldCountAtLastRelease: 9,
    ),
    _AdapterCase<VehicleAssetRecord>(
      name: 'VehicleAssetRecordAdapter',
      adapter: VehicleAssetRecordAdapter(),
      sample: () => VehicleAssetRecord(
        id: 'a1',
        tenantId: 'tenant-1',
        vehicleId: 'v1',
        catalogId: 'k1',
        assignedAt: now,
        createdAt: now,
        updatedAt: now,
      ),
      currentFieldCount: 12,
      fieldCountAtLastRelease: 12,
    ),
    _AdapterCase<FormResponseRecord>(
      name: 'FormResponseRecordAdapter',
      adapter: FormResponseRecordAdapter(),
      sample: () => FormResponseRecord(
        id: 'f1',
        tenantId: 'tenant-1',
        templateId: 'tmpl-1',
        templateRevisionId: 'rev-1',
        status: 'draft',
        subjectType: 'inspection',
        values: const <String, dynamic>{},
        createdAt: now,
        updatedAt: now,
      ),
      currentFieldCount: 18,
      fieldCountAtLastRelease: 18,
    ),
  ];

  test('every registered Hive adapter is covered', () {
    // hive_adapters.dart registers twelve. A thirteenth added without a case
    // here would get no forward-compatibility guard at all.
    expect(cases, hasLength(12));
    expect(cases.map((c) => c.name).toSet(), hasLength(12));
  });

  for (final adapterCase in cases) {
    adapterCase.run();
  }
}
