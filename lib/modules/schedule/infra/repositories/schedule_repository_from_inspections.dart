import 'package:voltcore/modules/schedule/infra/repositories/schedule_repository.dart';

import '../../../inspections/infra/repositories/inspection_repository_impl.dart';
import '../../domain/entities/task_schedule_entity.dart';
import '../mappers/inspection_schedule_mapper.dart';

/// A schedule repository that derives schedule items from inspections.
/// Useful as a fallback or for auto-populating a calendar from inspection due dates.
class ScheduleRepositoryFromInspections implements ScheduleRepository {
  final InspectionRepositoryImpl _inspectionRepo;

  ScheduleRepositoryFromInspections(this._inspectionRepo);

  Future<List<TaskScheduleEntity>> _loadAll({
    DateTime? start,
    DateTime? end,
  }) async {
    final inspections = await _inspectionRepo.listInspections();

    final mapped = inspections
        .map((i) => InspectionScheduleMapper.fromInspection(i))
        .toList();

    final filtered = mapped.where((t) {
      final due = t.scheduledAt;
      if (start != null && due.isBefore(start)) return false;
      if (end != null && due.isAfter(end)) return false;
      return true;
    }).toList();

    filtered.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return filtered;
  }

  @override
  Future<List<TaskScheduleEntity>> loadSchedule({
    required DateTime? from,
    required DateTime? to,
  }) {
    return _loadAll(start: from, end: to);
  }

  @override
  Future<TaskScheduleEntity?> getById(String id) async {
    final all = await _loadAll();
    try {
      return all.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<TaskScheduleEntity> saveTask(TaskScheduleEntity task) async {
    // Derived repo can't persist (by design). Return as-is.
    return task;
  }

  @override
  Future<void> deleteTask(String id) async {
    // Derived repo can't delete (by design).
  }

  @override
  Future<TaskScheduleEntity> create(TaskScheduleEntity task) => saveTask(task);

  @override
  Future<TaskScheduleEntity> update(TaskScheduleEntity task) => saveTask(task);

  @override
  Future<TaskScheduleEntity> upsert(TaskScheduleEntity task) => saveTask(task);
}
