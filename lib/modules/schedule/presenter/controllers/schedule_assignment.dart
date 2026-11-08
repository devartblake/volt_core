import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/domain/user_role.dart';
import '../../../auth/presenter/controllers/auth_controller.dart';
import '../../domain/entities/task_schedule_entity.dart';
import '../../infra/repositories/schedule_repository_impl.dart';
import 'schedule_controller.dart';

/// Dispatchers, supervisors and admins can hand a task to a technician;
/// technicians and apprentices cannot.
final canAssignScheduleProvider = Provider<bool>((ref) {
  final role = ref.watch(authStateProvider).currentRole;
  return role != null && !role.isFieldWorker;
});

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
