import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../permissions/domain/permission.dart';
import '../../../permissions/presenter/permission_providers.dart';
import '../../domain/entities/task_schedule_entity.dart';
import '../../infra/repositories/schedule_repository_impl.dart';
import 'schedule_controller.dart';

/// Dispatchers, supervisors and admins can hand a task to a technician;
/// technicians and apprentices cannot (permission `assign_schedule`, with any
/// per-person override applied).
final canAssignScheduleProvider = Provider<bool>(
  (ref) => ref.watch(hasPermissionProvider(Permission.assignSchedule)),
);

/// Saves [task] with [technicianId] as its assignee through the schedule
/// repository (which queues the cloud sync), then refreshes the list and the
/// task detail. Returns the saved task. Pass a null [technicianId] to unassign.
Future<TaskScheduleEntity> assignScheduleTask(
  WidgetRef ref,
  TaskScheduleEntity task,
  String? technicianId,
) async {
  // A null technicianId removes the assignee ("Unassign").
  final saved = await ref.read(scheduleRepositoryProvider).update(
        technicianId == null
            ? task.copyWith(clearAssignee: true)
            : task.copyWith(assignToUserId: technicianId),
      );
  ref.invalidate(scheduleTaskProvider(task.id));
  await ref.read(scheduleControllerProvider.notifier).load();
  return saved;
}
