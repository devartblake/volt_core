import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../inspections/domain/entities/inspection_entity.dart';
import '../../../inspections/infra/repositories/inspection_repository.dart';
import '../../../inspections/infra/repositories/inspection_repository_impl.dart';
import '../../../schedule/domain/entities/task_schedule_entity.dart';
import '../../../schedule/infra/mappers/inspection_schedule_mapper.dart';
import '../../../schedule/infra/repositories/schedule_repository.dart';
import '../../infra/repositories/schedule_repository_from_inspections.dart';

final createInspectionUseCaseProvider =
Provider<CreateInspectionUseCase>((ref) {
  final inspectionRepo = ref.watch(inspectionRepositoryProvider);
  final scheduleRepo = ref.watch(scheduleRepositoryProvider);

  return CreateInspectionUseCase(
    inspectionRepository: inspectionRepo,
    scheduleRepository: scheduleRepo,
  );
});

class CreateInspectionUseCase {
  final InspectionRepository inspectionRepository;
  final ScheduleRepository scheduleRepository;

  CreateInspectionUseCase({
    required this.inspectionRepository,
    required this.scheduleRepository,
  });

  /// Creates a new inspection, triggers PDF generation/email via the
  /// InspectionRepository, and then creates a corresponding schedule entry.
  Future<InspectionEntity> call(InspectionEntity entity) async {
    // 1) Persist + export PDF as before
    final saved = await inspectionRepository.createAndExport(entity);

    // 2) Derive a schedule entry from the saved inspection
    final TaskScheduleEntity schedule =
    InspectionScheduleMapper.fromInspection(saved);

    // 3) Save schedule (currently a no-op until schedule_tasks exists)
    await scheduleRepository.saveTask(schedule);

    return saved;
  }
}
