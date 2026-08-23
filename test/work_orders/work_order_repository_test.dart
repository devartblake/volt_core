import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/modules/work_orders/domain/entities/work_order_entity.dart';
import 'package:voltcore/modules/work_orders/infra/models/work_order_record.dart';
import 'package:voltcore/modules/work_orders/infra/repositories/work_order_repository_impl.dart';

void main() {
  late Directory directory;
  late Box<WorkOrderRecord> box;
  late WorkOrderRepositoryImpl repository;
  late String tenantId;

  setUpAll(() {
    Hive.registerAdapter(WorkOrderRecordAdapter());
  });

  setUp(() async {
    directory = Directory.systemTemp.createTempSync('voltcore_work_orders_');
    Hive.init(directory.path);
    box = await Hive.openBox<WorkOrderRecord>('work_orders_test');
    tenantId = 'tenant-a';
    repository = WorkOrderRepositoryImpl(
      box: box,
      queueWriter: (_) async {},
      tenantIdReader: () => tenantId,
    );
  });

  tearDown(() async {
    await box.close();
    await directory.delete(recursive: true);
  });

  test('creates a scheduled order with tenant and asset links', () async {
    final order = await repository.create(
      title: 'Service ATS',
      priority: WorkOrderPriority.high,
      assetId: 'asset-1',
      scheduledFor: DateTime.utc(2026, 8, 25),
    );

    expect(order.status, WorkOrderStatus.scheduled);
    expect(order.tenantId, 'tenant-a');
    expect(order.assetId, 'asset-1');
    expect((await repository.list()).single.id, order.id);
  });

  test('rejects a status jump that bypasses the lifecycle', () async {
    final order = await repository.create(title: 'Inspect panel');

    await expectLater(
      repository.save(order.copyWith(status: WorkOrderStatus.completed)),
      throwsStateError,
    );
  });

  test('requires a scheduled date before dispatching a draft', () async {
    final order = await repository.create(title: 'Inspect panel');

    await expectLater(
      repository.transition(order.id, WorkOrderStatus.scheduled),
      throwsStateError,
    );
  });

  test('persists an assigned technician with the work order', () async {
    final order = await repository.create(
      title: 'Test emergency lighting',
      assignedToUserId: 'technician-1',
    );

    expect((await repository.getById(order.id))?.assignedToUserId, 'technician-1');
  });

  test('does not leak another tenant work order', () async {
    await repository.create(title: 'Tenant A order');
    tenantId = 'tenant-b';

    expect(await repository.list(), isEmpty);
  });
}
