import 'package:flutter/material.dart';

import '../../../../core/theme/status_colors.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/readiness_models.dart';

/// Colours, icons and tones for the readiness statuses, reasons and grades,
/// all resolved from the theme so light and dark both read well.
class ReadinessVisuals {
  const ReadinessVisuals._();

  static Color statusColor(ThemeData theme, ReadinessStatus s) => switch (s) {
        ReadinessStatus.ready => theme.status.success,
        ReadinessStatus.dueSoon => theme.status.info,
        ReadinessStatus.attention => theme.status.warning,
        ReadinessStatus.notReady => theme.colorScheme.error,
      };

  static StatusTone statusTone(ReadinessStatus s) => switch (s) {
        ReadinessStatus.ready => StatusTone.success,
        ReadinessStatus.dueSoon => StatusTone.info,
        ReadinessStatus.attention => StatusTone.warning,
        ReadinessStatus.notReady => StatusTone.danger,
      };

  static IconData statusIcon(ReadinessStatus s) => switch (s) {
        ReadinessStatus.ready => Icons.check_circle_outline,
        ReadinessStatus.dueSoon => Icons.schedule,
        ReadinessStatus.attention => Icons.warning_amber_rounded,
        ReadinessStatus.notReady => Icons.error_outline,
      };

  static IconData reasonIcon(ReadinessReasonKind k) => switch (k) {
        ReadinessReasonKind.neverInspected => Icons.help_outline,
        ReadinessReasonKind.redGrade => Icons.flag,
        ReadinessReasonKind.amberGrade => Icons.flag_outlined,
        ReadinessReasonKind.overdue => Icons.event_busy_outlined,
        ReadinessReasonKind.dueSoon => Icons.event_outlined,
        ReadinessReasonKind.estimatedDueDate => Icons.edit_calendar_outlined,
        ReadinessReasonKind.followUps => Icons.assignment_late_outlined,
        ReadinessReasonKind.partsShort => Icons.inventory_2_outlined,
        ReadinessReasonKind.visitScheduled => Icons.event_available_outlined,
        ReadinessReasonKind.visitMissed => Icons.event_repeat_outlined,
      };

  static Color severityColor(ThemeData theme, ReadinessSeverity s) =>
      switch (s) {
        ReadinessSeverity.critical => theme.colorScheme.error,
        ReadinessSeverity.warning => theme.status.warning,
        ReadinessSeverity.info => theme.colorScheme.onSurfaceVariant,
      };

  static Color gradeColor(ThemeData theme, ReadinessGrade g) => switch (g) {
        ReadinessGrade.green => theme.status.success,
        ReadinessGrade.amber => theme.status.warning,
        ReadinessGrade.red => theme.colorScheme.error,
        ReadinessGrade.none => theme.colorScheme.outline,
      };
}

/// A small coloured pill with a grade's name.
class GradeChip extends StatelessWidget {
  const GradeChip({super.key, required this.grade});

  final ReadinessGrade grade;

  @override
  Widget build(BuildContext context) => StatusChip.colored(
        label: grade.label,
        foreground: ReadinessVisuals.gradeColor(Theme.of(context), grade),
      );
}
