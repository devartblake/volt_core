import 'package:flutter/material.dart';

import '../../domain/entities/task_schedule_entity.dart';

/// Compact Assign / Reassign action for calendar task cards.
///
/// Icon-only with a tooltip (read out by screen readers) and a 48 dp target.
class TaskAssignButton extends StatelessWidget {
  const TaskAssignButton({super.key, required this.task, required this.onAssign});

  final TaskScheduleEntity task;
  final ValueChanged<TaskScheduleEntity> onAssign;

  @override
  Widget build(BuildContext context) {
    final unassigned = (task.assignedToUserId ?? '').trim().isEmpty;
    return IconButton(
      key: Key('assign_task_${task.id}'),
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      tooltip: unassigned ? 'Assign' : 'Reassign',
      icon: Icon(unassigned ? Icons.person_add_alt_1 : Icons.swap_horiz),
      onPressed: () => onAssign(task),
    );
  }
}
