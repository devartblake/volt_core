import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/task_schedule_entity.dart';
import '../../external/datasources/schedule_remote_datasource.dart';
import 'schedule_repository.dart';

final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  final remote = ref.watch(scheduleRemoteDatasourceProvider);
  return ScheduleRepositoryImpl(remote: remote);
});

class ScheduleRepositoryImpl implements ScheduleRepository {
  final ScheduleRemoteDatasource remote;

  ScheduleRepositoryImpl({required this.remote});

  @override
  Future<List<TaskScheduleEntity>> loadSchedule({
    DateTime? from,
    DateTime? to,
  }) async {
    final all = await remote.fetchSchedule();

    if (from == null && to == null) return all;

    return all.where((task) {
      final d = task.scheduledDate;
      if (from != null && d.isBefore(from)) return false;
      if (to != null && d.isAfter(to)) return false;
      return true;
    }).toList();
  }

  @override
  Future<TaskScheduleEntity> saveTask(TaskScheduleEntity task) {
    return remote.upsertTask(task);
  }

  @override
  Future<void> deleteTask(String id) {
    return remote.deleteTask(id);
  }
}
