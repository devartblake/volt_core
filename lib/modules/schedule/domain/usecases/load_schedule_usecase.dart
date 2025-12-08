import '../entities/task_schedule_entity.dart';
import '../../infra/repositories/schedule_repository.dart';

/// Params for loading schedule entries. You can extend this later.
class LoadScheduleParams {
  final DateTime? from;
  final DateTime? to;

  const LoadScheduleParams({this.from, this.to});
}

/// Usecase that loads the schedule (list of TaskScheduleEntity).
class LoadScheduleUseCase {
  final ScheduleRepository _repository;

  LoadScheduleUseCase(this._repository);

  Future<List<TaskScheduleEntity>> call(LoadScheduleParams params) {
    return _repository.loadSchedule(from: params.from, to: params.to);
  }
}
