import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../inspections/domain/entities/inspection_entity.dart';
import '../../../inspections/infra/repositories/inspection_repository.dart';
import '../../../inspections/infra/repositories/inspection_repository_impl.dart';
import '../../infra/repositories/schedule_repository_from_inspections.dart';
import '../../../schedule/domain/entities/task_schedule_entity.dart';
import '../../../schedule/infra/mappers/inspection_schedule_mapper.dart';
import '../../../schedule/infra/repositories/schedule_repository.dart';

final updateInspectionUseCaseProvider =
Provider<UpdateInspectionUseCase>((ref) {
  final inspectionRepo = ref.watch(inspectionRepositoryProvider);
  final scheduleRepo = ref.watch(scheduleRepositoryProvider);

  return UpdateInspectionUseCase(
    inspectionRepository: inspectionRepo,
    scheduleRepository: scheduleRepo,
  );
});

class UpdateInspectionUseCase {
  final InspectionRepository inspectionRepository;
  final ScheduleRepository scheduleRepository;

  UpdateInspectionUseCase({
    required this.inspectionRepository,
    required this.scheduleRepository,
  });

  /// Updates an existing inspection, re-triggers PDF generation/email,
  /// and keeps the schedule entry in sync (date, address, grade, etc.).
  Future<InspectionEntity> call(InspectionEntity entity) async {
    // 1) Persist changes + re-export PDF
    final updated = await inspectionRepository.updateAndExport(entity);

    // 2) Derive the updated schedule entry
    final TaskScheduleEntity schedule =
    InspectionScheduleMapper.fromInspection(updated);

    // 3) Save schedule (no-op now, real persistence later)
    await scheduleRepository.saveTask(schedule);

    return updated;
  }
}
