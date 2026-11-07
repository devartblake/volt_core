import 'package:flutter/material.dart';

import '../../../../shared/widgets/widgets.dart';

/// "in_progress" -> "In Progress"; "maintenance_record" -> "Maintenance".
String scheduleLabelFor(String value) {
  if (value == 'maintenance_record') return 'Maintenance';
  return value
      .split('_')
      .map((word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

IconData scheduleStatusIcon(String status) => switch (status) {
      'completed' => Icons.task_alt_outlined,
      'cancelled' => Icons.cancel_outlined,
      'in_progress' => Icons.play_circle_outline,
      _ => Icons.schedule_outlined,
    };

StatusTone scheduleStatusTone(String status) => switch (status) {
      'completed' => StatusTone.success,
      'cancelled' || 'overdue' => StatusTone.danger,
      'in_progress' => StatusTone.info,
      _ => StatusTone.neutral,
    };

/// The status pill used on schedule cards and the task detail.
class ScheduleStatusChip extends StatelessWidget {
  const ScheduleStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => StatusChip(
        label: scheduleLabelFor(status),
        icon: scheduleStatusIcon(status),
        tone: scheduleStatusTone(status),
      );
}
