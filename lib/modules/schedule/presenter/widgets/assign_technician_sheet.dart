import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../dashboard/presenter/dashboard_providers.dart';
import '../../domain/entities/task_schedule_entity.dart';
import '../../domain/schedule_view_logic.dart';
import '../controllers/schedule_assignment.dart';

/// Value the sheet pops when "Unassigned" is chosen.
const String kUnassignChoice = '__unassign__';

/// Lets a dispatcher pick a technician for [task] and saves the choice.
///
/// Returns the saved task, or null when the sheet was dismissed or saving
/// failed (an error snackbar has been shown in that case).
Future<TaskScheduleEntity?> showAssignTechnicianSheet(
  BuildContext context,
  WidgetRef ref,
  TaskScheduleEntity task,
) async {
  final techId = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => AssignTechnicianSheet(task: task),
  );
  if (techId == null || !context.mounted) return null;
  final unassign = techId == kUnassignChoice;
  try {
    final saved = await assignScheduleTask(ref, task, unassign ? null : techId);
    if (context.mounted) {
      final names = ref.read(dashboardTechniciansProvider).value?.names ??
          const <String, String>{};
      AppSnackBar.success(
          context,
          unassign
              ? 'Task unassigned.'
              : 'Assigned to ${technicianLabel(techId, names)}.');
    }
    return saved;
  } catch (error) {
    if (context.mounted) {
      AppSnackBar.error(context, 'Could not assign task: $error');
    }
    return null;
  }
}

/// Bottom sheet body: active technicians, current assignee ticked.
class AssignTechnicianSheet extends ConsumerWidget {
  const AssignTechnicianSheet({super.key, required this.task});

  final TaskScheduleEntity task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final techs = ref.watch(dashboardTechniciansProvider);
    final current = task.assignedToUserId?.trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Assign technician', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            task.title.isEmpty ? 'Scheduled task' : task.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            key: const Key('assign_none'),
            contentPadding: EdgeInsets.zero,
            leading: const CircleAvatar(child: Icon(Icons.person_off_outlined)),
            title: const Text('Unassigned'),
            trailing: (current == null || current.isEmpty)
                ? Icon(Icons.check_circle, color: theme.colorScheme.primary)
                : null,
            onTap: () => Navigator.of(context).pop(kUnassignChoice),
          ),
          Flexible(
            child: techs.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) =>
                  const _SheetMessage('Could not load technicians.'),
              data: (data) {
                if (data.roster.isEmpty) {
                  return const _SheetMessage(
                      'No technicians available. Check your connection and try again.');
                }
                final ids = [...data.roster]..sort((a, b) =>
                    technicianLabel(a, data.names)
                        .toLowerCase()
                        .compareTo(
                            technicianLabel(b, data.names).toLowerCase()));
                return ListView(
                  shrinkWrap: true,
                  children: [
                    for (final id in ids)
                      ListTile(
                        key: Key('assign_$id'),
                        contentPadding: EdgeInsets.zero,
                        leading: const CircleAvatar(
                            child: Icon(Icons.person_outline)),
                        title: Text(technicianLabel(id, data.names),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        trailing: id == current
                            ? Icon(Icons.check_circle,
                                color: theme.colorScheme.primary)
                            : null,
                        onTap: () => Navigator.of(context).pop(id),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl),
        child: Text(text, textAlign: TextAlign.center),
      );
}
