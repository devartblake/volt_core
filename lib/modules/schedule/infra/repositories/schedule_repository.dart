import '../../domain/entities/task_schedule_entity.dart';

/// Abstraction for schedule operations.
///
/// Can be backed by remote (Supabase) only for now; you can add local cache later.
abstract class ScheduleRepository {
  Future<List<TaskScheduleEntity>> loadSchedule({
    required DateTime? from,
    required DateTime? to,
  });

  /// Primary persistence call (insert or update).
  Future<TaskScheduleEntity> saveTask(TaskScheduleEntity task);

  Future<void> deleteTask(String id);

  Future<TaskScheduleEntity?> getById(String id);

  /// Aliases (keeps older call-sites compiling).
  Future<TaskScheduleEntity> create(TaskScheduleEntity task) => saveTask(task);
  Future<TaskScheduleEntity> update(TaskScheduleEntity task) => saveTask(task);
  Future<TaskScheduleEntity> upsert(TaskScheduleEntity task) => saveTask(task);

}
