import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/modules/maintenance/infra/datasources/hive_boxes_maintenance.dart';
import 'package:voltcore/modules/maintenance/infra/models/maintenance_record.dart';
import 'package:voltcore/modules/settings/selection_options_service.dart';
import 'package:voltcore/modules/work_orders/infra/datasources/work_orders_box.dart';
import 'package:voltcore/modules/work_orders/infra/models/work_order_record.dart';

/// Reproduces what the debug menu's "clear data" does to a running app:
/// every box is closed and reopened as a *new* instance. Anything holding the
/// old handle throws `HiveError: Box has already been closed` — with nothing in
/// the message pointing at the reset as the cause.
Future<void> _closeAndReopenEverything(String boxName) async {
  await Hive.close();
  await Hive.openBox<MaintenanceRecord>(boxName);
}

void main() {
  late Directory tempDir;

  setUpAll(() {
    if (!Hive.isAdapterRegistered(40)) {
      Hive.registerAdapter(MaintenanceRecordAdapter());
    }
    final workOrderAdapter = WorkOrderRecordAdapter();
    if (!Hive.isAdapterRegistered(workOrderAdapter.typeId)) {
      Hive.registerAdapter(workOrderAdapter);
    }
  });

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('voltcore_reset_test');
    Hive.init(tempDir.path);
  });

  tearDown(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('MaintenanceBoxes re-resolves after everything is closed and reopened',
      () async {
    await MaintenanceBoxes.init();
    expect(MaintenanceBoxes.maintenance.isOpen, isTrue);

    await _closeAndReopenEverything(MaintenanceBoxes.maintenanceBoxName);

    // Before the fix this returned the closed instance, because the getter
    // trusted its own `_initialized` flag and never checked isOpen. Writing
    // through it is what crashed /maintenance/new.
    final box = MaintenanceBoxes.maintenance;
    expect(box.isOpen, isTrue);
    await box.put('id-1', MaintenanceRecord(id: 'id-1'));
    expect(box.get('id-1')?.id, 'id-1');
  });

  test('invalidate forces a fresh handle', () async {
    await MaintenanceBoxes.init();
    MaintenanceBoxes.invalidate();
    expect(MaintenanceBoxes.isInitialized, isFalse);

    // Still resolvable, because the box itself is open.
    expect(MaintenanceBoxes.maintenance.isOpen, isTrue);
  });

  test('SelectionOptionsService reads after a close/reopen cycle', () async {
    final service = SelectionOptionsService();
    await service.init();
    await service.addTech('Alex Rivera');
    expect(service.techs, ['Alex Rivera']);

    await Hive.close();
    await Hive.openBox('selection_options');

    // Before the fix `_box` stayed non-null while pointing at a closed box, so
    // the null-guard passed and the read threw — which is what crashed the
    // inspection form's Site Info section.
    expect(service.techs, ['Alex Rivera']);
  });

  test('SelectionOptionsService reports not-ready when the box is gone',
      () async {
    final service = SelectionOptionsService();
    await service.init();
    expect(service.isReady, isTrue);

    await Hive.close();

    // Honest about the state rather than claiming ready and throwing on read.
    expect(service.isReady, isFalse);
    expect(service.techs, isEmpty);
  });

  test('WorkOrdersBox re-resolves after a close/reopen cycle', () async {
    // Work orders arrived after this class of bug was fixed elsewhere and
    // shipped with the same shape: a cached handle and a plain non-null check.
    await WorkOrdersBox.init();
    expect(WorkOrdersBox.box.isOpen, isTrue);

    await Hive.close();
    await Hive.openBox<WorkOrderRecord>(WorkOrdersBox.boxName);

    expect(WorkOrdersBox.box.isOpen, isTrue);
  });
}
