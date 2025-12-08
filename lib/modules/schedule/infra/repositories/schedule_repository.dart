import '../../domain/entities/task_schedule_entity.dart';

/// Abstraction for schedule operations.
///
/// Can be backed by remote (Supabase) only for now; you can add local cache later.
abstract class ScheduleRepository {
  Future<List<TaskScheduleEntity>> loadSchedule({
    DateTime? from,
    DateTime? to,
  });

  Future<TaskScheduleEntity> saveTask(TaskScheduleEntity task);

  Future<void> deleteTask(String id);
}
