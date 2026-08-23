import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../../core/services/notifications/notification_service.dart';
import '../../../../core/services/sync/sync_service.dart';
import '../../domain/entities/task_schedule_entity.dart';
import '../../external/datasources/schedule_remote_datasource.dart'
    show scheduleRemoteDatasourceProvider;
import '../datasources/schedule_remote_datasource.dart';
import '../datasources/scheduled_tasks_box.dart';
import '../mappers/schedule_supabase_mapper.dart';
import '../models/schedule_task.dart';
import 'schedule_repository.dart';

class ScheduleRepositoryImpl implements ScheduleRepository {
  /// Only set when a box is injected (tests). Otherwise resolved per use: a
  /// box captured at construction is dead after HiveService.reset closes and
  /// reopens everything, and this repository outlives that.
  final Box<ScheduledTask>? _injectedBox;

  Box<ScheduledTask> get _box => _injectedBox ?? ScheduledTasksBox.box;

  /// Optional cloud source. When provided, [loadSchedule] merges server rows
  /// into the local box so tasks created on another device show up here.
  final ScheduleRemoteDatasource? _remote;

  ScheduleRepositoryImpl({
    Box<ScheduledTask>? box,
    ScheduleRemoteDatasource? remote,
  }) : _injectedBox = box,
       _remote = remote;

  // ---------------------------
  // Mapping
  // ---------------------------

  TaskScheduleEntity _toEntity(ScheduledTask m) {
    return TaskScheduleEntity(
      id: m.id,
      tenantId: m.tenantId,
      title: m.title,
      scheduledDate: m.scheduledDate,
      scheduledAt: m.scheduledAt,
      status: m.status,
      sourceType: m.sourceType,
      sourceId: m.sourceId,
      assignedToUserId: m.assignedToUserId,
      siteCode: m.siteCode,
      siteGrade: m.siteGrade,
      address: m.address,
      description: m.description,
      inspectionId: m.inspectionId,
      notes: m.notes,
      createdAt: m.createdAt,
      updatedAt: m.updatedAt,
    );
  }

  ScheduledTask _toModel(TaskScheduleEntity e) {
    return ScheduledTask(
      id: e.id,
      tenantId: e.tenantId,
      title: e.title,
      scheduledAt: e.scheduledAt,
      scheduledDate: e.scheduledDate,
      status: e.status,
      sourceType: e.sourceType,
      sourceId: e.sourceId,
      assignedToUserId: e.assignedToUserId,
      siteCode: e.siteCode,
      siteGrade: e.siteGrade,
      address: e.address,
      description: e.description,
      inspectionId: e.inspectionId,
      notes: e.notes,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
    );
  }

  // ---------------------------
  // Repository
  // ---------------------------

  /// Queue a cloud upsert for [task]. Offline-first: the local save has already
  /// happened, so this only records intent — [SyncService] pushes it to Supabase
  /// when connectivity allows and never blocks the caller.
  Future<void> _queueUpsert(TaskScheduleEntity task) {
    if (!hasValidScheduleTaskTenant(task)) {
      if (kDebugMode) {
        debugPrint(
          '[Schedule] Skipped cloud sync: no valid tenant is available for '
          'task ${task.id}.',
        );
      }
      return Future.value();
    }

    return SyncService.instance.enqueueUpsert(
      table: kScheduleTasksTable,
      id: task.id,
      payload: scheduleTaskToSupabaseJson(task),
    );
  }

  /// Pull server-side tasks into the local box so work scheduled on another
  /// device appears here. Best-effort: any failure leaves local data untouched.
  ///
  /// Local wins on conflict — a row still waiting in the sync queue must not be
  /// overwritten by the older server copy it is about to replace.
  Future<void> _hydrateFromRemote({DateTime? from, DateTime? to}) async {
    final remote = _remote;
    if (remote == null) return;

    try {
      final remoteTasks = await remote.list(from: from, to: to);
      for (final task in remoteTasks) {
        final local = _box.get(task.id);
        if (local == null || task.updatedAt.isAfter(local.updatedAt)) {
          await _box.put(task.id, _toModel(task));
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Schedule] remote hydrate failed (using local only): $e');
      }
    }
  }

  @override
  Future<List<TaskScheduleEntity>> loadSchedule({
    required DateTime? from,
    required DateTime? to,
  }) async {
    await _hydrateFromRemote(from: from, to: to);

    final items = _box.values.where((m) {
      if (from != null && m.scheduledAt.isBefore(from)) return false;
      if (to != null && m.scheduledAt.isAfter(to)) return false;
      return true;
    }).toList()..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return items.map(_toEntity).toList(growable: false);
  }

  @override
  Future<TaskScheduleEntity> saveTask(TaskScheduleEntity task) async {
    final updated = task.copyWith(updatedAt: DateTime.now());
    await _box.put(updated.id, _toModel(updated));
    await _queueUpsert(updated);

    // Keep the local reminder in sync with the task's state.
    final isActive =
        updated.status == 'scheduled' || updated.status == 'overdue';
    if (isActive) {
      await NotificationService.instance.scheduleTaskReminder(
        taskId: updated.id,
        title: 'Upcoming: ${updated.title}',
        body: updated.address.isNotEmpty
            ? '${updated.sourceType} at ${updated.address}'
            : 'Scheduled ${updated.sourceType}',
        scheduledAt: updated.scheduledAt,
      );
    } else {
      // completed / cancelled → drop the reminder
      await NotificationService.instance.cancelTaskReminder(updated.id);
    }

    return updated;
  }

  @override
  Future<void> deleteTask(String id) async {
    await _box.delete(id);
    await SyncService.instance.enqueueDelete(
      table: kScheduleTasksTable,
      id: id,
    );
    await NotificationService.instance.cancelTaskReminder(id);
  }

  @override
  Future<TaskScheduleEntity?> getById(String id) async {
    final m = _box.get(id);
    if (m == null) return null;
    return _toEntity(m);
  }

  @override
  Future<TaskScheduleEntity> create(TaskScheduleEntity task) => saveTask(task);

  @override
  Future<TaskScheduleEntity> update(TaskScheduleEntity task) => saveTask(task);

  @override
  Future<TaskScheduleEntity> upsert(TaskScheduleEntity task) => saveTask(task);
}

/// Provider used by your controller/use-cases.
///
/// Wired to the Supabase datasource so schedule changes reach the cloud and
/// remote tasks are pulled in on load.
final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepositoryImpl(
    remote: ref.watch(scheduleRemoteDatasourceProvider),
  );
});
