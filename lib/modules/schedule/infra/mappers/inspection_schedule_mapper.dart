import '../../../inspections/domain/entities/inspection_entity.dart';
import '../../domain/entities/task_schedule_entity.dart';

/// Helper that derives schedule entries directly from InspectionEntity.
///
/// This lets you show a schedule even if you don't yet have a real
/// schedule_tasks table in Supabase.
class InspectionScheduleMapper {
  /// Map a single InspectionEntity to TaskScheduleEntity.
  static TaskScheduleEntity fromInspection(InspectionEntity ins) {
    final now = DateTime.now();
    final scheduled = ins.serviceDate;

    // Derive a simple status from the date for now.
    final status =
    scheduled.isBefore(now) ? 'completed' : 'pending'; // or 'upcoming'

    return TaskScheduleEntity(
      id: 'sched_${ins.id}', // derived ID (no real schedule row yet)
      createdAt: ins.createdAt,
      scheduledDate: ins.serviceDate,
      title: ins.address.isNotEmpty
          ? ins.address
          : (ins.siteCode.isNotEmpty ? 'Site ${ins.siteCode}' : 'Inspection'),
      description: ins.notes,
      inspectionId: ins.id,
      siteCode: ins.siteCode,
      siteGrade: ins.siteGrade,
      address: ins.address,
      status: status,
      tenantId: '',
    );
  }

  /// Map a list of inspections to a list of schedule entries.
  static List<TaskScheduleEntity> fromList(List<InspectionEntity> items) {
    return items.map(fromInspection).toList();
  }
}
