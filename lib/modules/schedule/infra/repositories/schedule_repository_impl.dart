import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/modules/schedule/infra/repositories/schedule_repository.dart';

import '../../domain/entities/task_schedule_entity.dart';
import '../../domain/repositories/schedule_repository.dart';
import '../datasources/scheduled_tasks_box.dart';
import '../models/schedule_model.dart';

class ScheduleRepositoryImpl implements ScheduleRepository {
  final Box<ScheduleTaskModel> _box;

  ScheduleRepositoryImpl({Box<ScheduleTaskModel>? box})
      : _box = box ?? ScheduledTasksBox.box;

  // ---------------------------
  // Mapping
  // ---------------------------

  TaskScheduleEntity _toEntity(ScheduleTaskModel m) {
    return TaskScheduleEntity(
      id: m.id,
      tenantId: m.tenantId,
      title: m.title,
      scheduledDate: m.scheduledDate,
      status: m.status,
      sourceType: m.sourceType,
      sourceId: m.sourceId,
      assignedToUserId: m.assignedToUserId,
      siteCode: m.siteCode,
      address: m.address,
      notes: m.notes,
      createdAt: m.createdAt,
      updateAt: m.updatedAt,
    );
  }

  ScheduleTaskModel _toModel(TaskScheduleEntity e) {
    return ScheduleTaskModel(
      id: e.id,
      tenantId: e.tenantId,
      title: e.title,
      scheduledAt: e.scheduledAt,
      status: e.status,
      sourceType: e.sourceType,
      sourceId: e.sourceId,
      assignedToUserId: e.assignedToUserId,
      siteCode: e.siteCode,
      address: e.address,
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
    required DateTime from,
    required DateTime to,
  }) async {
    final items = _box.values
        .where((m) =>
    !m.scheduledAt.isBefore(from) && !m.scheduledAt.isAfter(to))
        .toList()
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
}

/// Provider used by your controller/use-cases.
final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  return ScheduleRepositoryImpl();
});
