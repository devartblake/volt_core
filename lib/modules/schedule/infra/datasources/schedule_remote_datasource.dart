import '../../domain/entities/task_schedule_entity.dart';

abstract class ScheduleRemoteDatasource {
  Future<List<TaskScheduleEntity>> list({DateTime? from, DateTime? to});
  Future<TaskScheduleEntity?> getById(String id);
  Future<TaskScheduleEntity> upsert(TaskScheduleEntity entity);
  Future<void> delete(String id);
}
