import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../domain/entities/task_schedule_entity.dart';
import '../datasources/scheduled_tasks_box.dart';
import '../models/schedule_task.dart';
import 'schedule_repository.dart';

class ScheduleRepositoryImpl implements ScheduleRepository {
  final Box<ScheduledTask> _box;

  ScheduleRepositoryImpl({Box<ScheduledTask>? box})
      : _box = box ?? ScheduledTasksBox.box;

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

  @override
  Future<List<TaskScheduleEntity>> loadSchedule({
    required DateTime? from,
    required DateTime? to,
  }) async {
    final items = _box.values.where((m) {
      if (from != null && m.scheduledAt.isBefore(from)) return false;
      if (to != null && m.scheduledAt.isAfter(to)) return false;
      return true;
    }).toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));

    return items.map(_toEntity).toList(growable: false);
  }

  @override
  Future<TaskScheduleEntity> saveTask(TaskScheduleEntity task) async {
    final updated = task.copyWith(updatedAt: DateTime.now());
    await _box.put(updated.id, _toModel(updated));
    return updated;
  }

  @override
  Future<void> deleteTask(String id) async {
    await _box.delete(id);
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
final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepositoryImpl();
});
