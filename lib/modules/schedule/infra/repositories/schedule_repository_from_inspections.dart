import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../inspections/domain/entities/inspection_entity.dart';
import '../../../inspections/infra/repositories/inspection_repository.dart';
import '../../../inspections/infra/repositories/inspection_repository_impl.dart';
import '../../domain/entities/task_schedule_entity.dart';
import '../../infra/mappers/inspection_schedule_mapper.dart';
import 'schedule_repository.dart';

/// ScheduleRepository implementation backed purely by inspections.
///
/// No schedule_tasks table is required:
/// - loadSchedule(): derived from InspectionEntity list
/// - saveTask()/deleteTask(): currently no-op, but kept for future compatibility.
class ScheduleRepositoryFromInspections implements ScheduleRepository {
  final InspectionRepository inspectionRepository;

  ScheduleRepositoryFromInspections({
    required this.inspectionRepository,
  });

  @override
  Future<List<TaskScheduleEntity>> loadSchedule({
    DateTime? from,
    DateTime? to,
  }) async {
    // 1) Load all inspections from your clean inspection repo
    final List<InspectionEntity> inspections =
    await inspectionRepository.listInspections();

    // 2) Convert them to TaskScheduleEntity list
    final all = InspectionScheduleMapper.fromList(inspections);

    // 3) Apply optional date filter
    if (from == null && to == null) return all;

    return all.where((task) {
      final d = task.scheduledDate;
      if (from != null && d.isBefore(from)) return false;
      if (to != null && d.isAfter(to)) return false;
      return true;
    }).toList();
  }

  @override
  Future<TaskScheduleEntity> saveTask(TaskScheduleEntity task) async {
    // For now we don't persist schedule separately.
    // This is a no-op so it's safe to call from use cases.
    //
    // Later, when you add a real schedule_tasks table, your ScheduleRepository
    // implementation can upsert a row there.
    return task;
  }

  @override
  Future<void> deleteTask(String id) async {
    // No-op for now (we're not storing tasks separately yet).
    //
    // In the future, you can delete the schedule row here without impacting
    // the InspectionEntity itself.
    return;
  }
}

/// Wire ScheduleRepository to the from-inspections implementation.
final scheduleRepositoryProvider = Provider<ScheduleRepository>((ref) {
  final inspectionRepo = ref.watch(inspectionRepositoryProvider);
  return ScheduleRepositoryFromInspections(
    inspectionRepository: inspectionRepo,
  );
});
