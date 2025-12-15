import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../inspections/domain/entities/inspection_entity.dart';
import '../../../inspections/infra/repositories/inspection_repository.dart';
import '../../../inspections/infra/repositories/inspection_repository_impl.dart';
import '../../infra/repositories/schedule_repository.dart';
import '../../infra/repositories/schedule_repository_impl.dart';
import '../entities/task_schedule_entity.dart';

class CreateInspectionUseCase {
  final InspectionRepository _inspectionRepo;
  final ScheduleRepository _scheduleRepo;

  const CreateInspectionUseCase(this._inspectionRepo, this._scheduleRepo);

  Future<InspectionEntity> call(InspectionEntity inspection) async {
    final created = await _inspectionRepo.create(inspection);

    // Optional: also upsert a schedule task representing the inspection due date
    if (created.nextDueAt != null) {
      final task = TaskScheduleEntity(
        id: 'insp_${created.id}',
        tenantId: created.tenantId,
        title: 'Inspection: ${created.siteCode}',
        scheduledAt: created.nextDueAt!,
        status: 'scheduled',
        sourceType: 'inspection',
        sourceId: created.id,
        assignedToUserId: created.assignedTechnicianUserId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        scheduledDate: DateTime.now(),
      );
      await _scheduleRepo.upsert(task);
    }

    return created;
  }
}

final createInspectionUseCaseProvider = Provider<CreateInspectionUseCase>((ref) {
  final inspectionRepo = ref.watch(inspectionRepositoryProvider);
  final scheduleRepo = ref.watch(scheduleRepositoryProvider); // from schedule_repository_impl.dart
  return CreateInspectionUseCase(inspectionRepo, scheduleRepo);
});
