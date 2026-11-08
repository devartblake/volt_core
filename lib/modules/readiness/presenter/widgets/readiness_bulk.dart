import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/readiness_models.dart';
import '../../domain/readiness_rules.dart' show readinessDate;
import '../readiness_providers.dart';
import '../readiness_services.dart';

/// Bottom bar while selecting units: what is selected and what can be done.
class ReadinessSelectionBar extends StatelessWidget {
  const ReadinessSelectionBar({
    super.key,
    required this.count,
    required this.canSchedule,
    required this.onSchedule,
    required this.onExport,
    required this.onSelectOverdue,
    required this.onDone,
  });

  final int count;
  final bool canSchedule;
  final VoidCallback onSchedule;
  final VoidCallback onExport;
  final VoidCallback onSelectOverdue;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerHigh,
      elevation: 3,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      count == 0 ? 'Select units' : '$count selected',
                      key: const Key('selection-count'),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  TextButton(
                    key: const Key('selection-done'),
                    onPressed: onDone,
                    child: const Text('Done'),
                  ),
                ],
              ),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  TextButton(
                    key: const Key('select-overdue'),
                    onPressed: onSelectOverdue,
                    child: const Text('Select all overdue'),
                  ),
                  if (canSchedule)
                    FilledButton.icon(
                      key: const Key('bulk-schedule'),
                      onPressed: count == 0 ? null : onSchedule,
                      icon: const Icon(Icons.event_available_outlined),
                      label: const Text('Schedule inspections'),
                    ),
                  OutlinedButton.icon(
                    key: const Key('bulk-export'),
                    onPressed: count == 0 ? null : onExport,
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Export selected'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Asks for one date, then creates a scheduled inspection per unit. Reports
/// "Scheduled 6 inspections", or lists the units that failed. Returns the
/// result, or null when the date picker was dismissed.
Future<BulkScheduleResult?> runBulkSchedule(
  BuildContext context,
  WidgetRef ref,
  List<ReadinessUnit> units,
  DateTime now,
) async {
  final today = DateTime(now.year, now.month, now.day);
  final date = await showDatePicker(
    context: context,
    initialDate: today,
    firstDate: today,
    lastDate: DateTime(today.year + 5),
    helpText: 'Schedule ${units.length} inspections',
  );
  if (date == null || !context.mounted) return null;

  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  final scheduler = ref.read(readinessSchedulerProvider);
  final result = await scheduleInspections(scheduler, units, date);
  try {
    await scheduler.reload();
  } catch (_) {
    // The tasks are saved; the schedule list refreshes next time it opens.
  }
  ref.invalidate(readinessInputsProvider);

  if (!messenger.mounted) return result;
  if (!result.hasFailures) {
    AppSnackBar.successOn(
        messenger, '${result.summary} for ${readinessDate(date, now)}');
  } else if (navigator.mounted) {
    await showDialog<void>(
      context: navigator.context,
      builder: (ctx) => AlertDialog(
        title: Text(result.summary),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('These could not be scheduled. Try them again:'),
              const SizedBox(height: AppSpacing.sm),
              for (final f in result.failures)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text('${f.key} (${f.value})'),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  return result;
}
