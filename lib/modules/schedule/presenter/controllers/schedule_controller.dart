import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../domain/entities/task_schedule_entity.dart';
import '../../domain/usecases/load_schedule_usecase.dart';
import '../../infra/repositories/schedule_repository_impl.dart';

/// Wire the usecase from the repository
final loadScheduleUseCaseProvider = Provider<LoadScheduleUseCase>((ref) {
  final repo = ref.watch(scheduleRepositoryProvider);
  return LoadScheduleUseCase(repo);
});

/// Controller state is simply AsyncValue<List<TaskScheduleEntity>>
class ScheduleController
    extends StateNotifier<AsyncValue<List<TaskScheduleEntity>>> {
  final LoadScheduleUseCase _loadSchedule;

  ScheduleController(this._loadSchedule)
      : super(const AsyncValue.loading()) {
    // initial load
    load();
  }

  Future<void> load({DateTime? from, DateTime? to}) async {
    state = const AsyncValue.loading();
    try {
      final items =
      await _loadSchedule(LoadScheduleParams(from: from, to: to));
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Convenience: read-only getter for data, returns [] when loading/error.
  List<TaskScheduleEntity> get items =>
      state.maybeWhen(data: (list) => list, orElse: () => const []);
}

/// Riverpod provider for ScheduleController.
final scheduleControllerProvider = StateNotifierProvider<ScheduleController,
    AsyncValue<List<TaskScheduleEntity>>>((ref) {
  final usecase = ref.watch(loadScheduleUseCaseProvider);
  return ScheduleController(usecase);
});
