import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voltcore/modules/schedule/infra/repositories/schedule_repository.dart';

import '../../../inspections/infra/repositories/inspection_repository_impl.dart';
import '../../domain/entities/task_schedule_entity.dart';
import '../mappers/inspection_schedule_mapper.dart';

/// A schedule repository that derives schedule items from inspections.
/// Useful as a fallback or for auto-populating a calendar from inspection due dates.
class ScheduleRepositoryFromInspections implements ScheduleRepository {
  final InspectionRepositoryImpl _inspectionRepo;

  ScheduleRepositoryFromInspections(this._inspectionRepo);

  @override
  Future<List<TaskScheduleEntity>> listTasks({
    DateTime? start,
    DateTime? end,
    String? tenantId,
    String? assignedToUserId,
  }) async {
    final inspections = await _inspectionRepo.listAll(); // must exist on inspection repo

    final mapped = inspections
        .map((i) => InspectionScheduleMapper.fromInspection(i))
        .toList();

    // Optional filtering if caller provided start/end
    final filtered = mapped.where((t) {
      final due = t.scheduledAt;
      if (start != null && due.isBefore(start)) return false;
      if (end != null && due.isAfter(end)) return false;
      return true;
    }).toList();

    filtered.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return filtered;
  }

  @override
  Future<TaskScheduleEntity?> getById(String id) async {
    final all = await listTasks();
    try {
      return all.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<TaskScheduleEntity> upsert(TaskScheduleEntity task) async {
    // Derived repo can’t persist (by design). Return as-is.
    return task;
  }

  @override
  Future<void> delete(String id) async {
    // Derived repo can’t delete (by design).
  }
}

/// IMPORTANT: renamed to avoid collision with the real repo provider
final scheduleRepositoryFromInspectionsProvider =
Provider<ScheduleRepository>((ref) {
  final inspectionRepo = ref.watch(inspectionRepositoryProvider);
  return ScheduleRepositoryFromInspections(inspectionRepo);
});
