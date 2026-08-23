import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/sync/sync_context.dart';
import '../../../../core/services/sync/sync_service.dart';
import '../../domain/entities/work_order_entity.dart';
import '../datasources/work_orders_box.dart';
import '../datasources/work_order_remote_datasource.dart';
import '../mappers/work_order_supabase_mapper.dart';
import '../models/work_order_record.dart';
import 'work_order_repository.dart';

typedef WorkOrderQueueWriter = Future<void> Function(WorkOrderEntity order);
typedef TenantIdReader = String? Function();

/// Hive-backed work orders, with writes handed to the durable sync outbox.
class WorkOrderRepositoryImpl implements WorkOrderRepository {
  WorkOrderRepositoryImpl({
    Box<WorkOrderRecord>? box,
    WorkOrderQueueWriter? queueWriter,
    TenantIdReader? tenantIdReader,
    WorkOrderRemoteDatasource? remote,
  }) : _injectedBox = box,
       _queueWriter = queueWriter ?? _enqueueToSync,
       _tenantIdReader = tenantIdReader ?? _readActiveTenantId,
       _remote = remote;

  /// Only set when a box is injected (tests). Otherwise resolved per use, so a
  /// HiveService reset cannot leave this repository holding a closed one.
  final Box<WorkOrderRecord>? _injectedBox;

  Box<WorkOrderRecord> get _box => _injectedBox ?? WorkOrdersBox.box;
  final WorkOrderQueueWriter _queueWriter;
  final TenantIdReader _tenantIdReader;
  final WorkOrderRemoteDatasource? _remote;

  static String? _readActiveTenantId() => SyncContext.tenantId;

  static Future<void> _enqueueToSync(WorkOrderEntity order) {
    return SyncService.instance.enqueueUpsert(
      table: kWorkOrdersTable,
      id: order.id,
      payload: workOrderToSupabaseJson(order),
    );
  }

  WorkOrderEntity _toEntity(WorkOrderRecord value) => WorkOrderEntity(
    id: value.id,
    tenantId: value.tenantId,
    title: value.title,
    status: WorkOrderStatus.values.byName(value.status),
    priority: WorkOrderPriority.values.byName(value.priority),
    customerId: value.customerId,
    siteId: value.siteId,
    assetId: value.assetId,
    assignedToUserId: value.assignedToUserId,
    scheduledFor: value.scheduledFor,
    description: value.description,
    createdAt: value.createdAt,
    updatedAt: value.updatedAt,
  );

  WorkOrderRecord _toRecord(WorkOrderEntity value) => WorkOrderRecord(
    id: value.id,
    tenantId: value.tenantId,
    title: value.title,
    status: value.status.name,
    priority: value.priority.name,
    customerId: value.customerId,
    siteId: value.siteId,
    assetId: value.assetId,
    assignedToUserId: value.assignedToUserId,
    scheduledFor: value.scheduledFor,
    description: value.description,
    createdAt: value.createdAt,
    updatedAt: value.updatedAt,
  );

  /// Pull server work before returning the local list. This is deliberately
  /// best-effort: a technician can keep working from Hive while offline, and a
  /// locally newer row is never replaced by an older remote copy.
  Future<void> _hydrateFromRemote() async {
    final remote = _remote;
    if (remote == null) return;

    try {
      for (final order in await remote.list()) {
        final local = _box.get(order.id);
        if (local == null || order.updatedAt.isAfter(local.updatedAt)) {
          await _box.put(order.id, _toRecord(order));
        }
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          '[WorkOrders] remote hydrate failed (using local only): $error',
        );
      }
    }
  }

  @override
  Future<List<WorkOrderEntity>> list() async {
    await _hydrateFromRemote();
    final tenantId = _tenantIdReader();
    final orders = _box.values
        .map(_toEntity)
        .where((order) => tenantId == null || order.tenantId == tenantId)
        .toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return orders;
  }

  @override
  Future<WorkOrderEntity?> getById(String id) async {
    final value = _box.get(id);
    if (value == null || value.tenantId != _tenantIdReader()) return null;
    return _toEntity(value);
  }

  @override
  Future<WorkOrderEntity> create({
    required String title,
    WorkOrderPriority priority = WorkOrderPriority.normal,
    String? customerId,
    String? siteId,
    String? assetId,
    String? assignedToUserId,
    DateTime? scheduledFor,
    String description = '',
  }) {
    final tenantId = _tenantIdReader();
    final normalizedTitle = title.trim();
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('Select an active tenant before creating a work order.');
    }
    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(
        title,
        'title',
        'Work-order title cannot be blank.',
      );
    }
    final now = DateTime.now().toUtc();
    return save(
      WorkOrderEntity(
        id: const Uuid().v4(),
        tenantId: tenantId,
        title: normalizedTitle,
        status: scheduledFor == null
            ? WorkOrderStatus.draft
            : WorkOrderStatus.scheduled,
        priority: priority,
        customerId: customerId,
        siteId: siteId,
        assetId: assetId,
        assignedToUserId: assignedToUserId,
        scheduledFor: scheduledFor,
        description: description.trim(),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  @override
  Future<WorkOrderEntity> save(WorkOrderEntity order) async {
    if (order.tenantId != _tenantIdReader()) {
      throw StateError('Work orders can only be saved in the active tenant.');
    }
    final existing = _box.get(order.id);
    if (existing != null) {
      final previous = _toEntity(existing);
      if (previous.status != order.status &&
          !previous.canTransitionTo(order.status)) {
        throw StateError('Invalid work-order lifecycle transition.');
      }
      if (previous.status != order.status &&
          order.status == WorkOrderStatus.scheduled &&
          order.scheduledFor == null) {
        throw StateError('A work order needs a scheduled date before dispatch.');
      }
    }
    final updated = order.copyWith(updatedAt: DateTime.now().toUtc());
    await _box.put(updated.id, _toRecord(updated));
    await _queueWriter(updated);
    return updated;
  }

  @override
  Future<WorkOrderEntity> transition(String id, WorkOrderStatus status) async {
    final existing = await getById(id);
    if (existing == null) throw StateError('Work order $id was not found.');
    return save(existing.transitionTo(status));
  }
}

final workOrderRepositoryProvider = Provider<WorkOrderRepository>((ref) {
  return WorkOrderRepositoryImpl(
    remote: ref.watch(workOrderRemoteDatasourceProvider),
  );
});
