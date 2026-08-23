import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/entities/task_schedule_entity.dart';
import '../../../maintenance/presenter/controllers/maintenance_providers.dart';
import '../../../maintenance/infra/datasources/maintenance_remote_datasource.dart';
import '../controllers/schedule_controller.dart';
import '../../infra/repositories/schedule_repository_impl.dart';

/// Detail and status controls for a task selected from the schedule.
class ScheduleTaskDetailPage extends ConsumerWidget {
  const ScheduleTaskDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final task = ref.watch(scheduleTaskProvider(id));
    return task.when(
      loading: () => const AppPage(title: 'Scheduled task', body: LoadingIndicator()),
      error: (error, _) => AppPage(
        title: 'Scheduled task',
        body: EmptyState.error(message: '$error'),
      ),
      data: (item) {
        if (item == null) {
          return const AppPage(
            title: 'Scheduled task',
            body: EmptyState(
              icon: Icons.event_busy_outlined,
              title: 'Scheduled task not found',
            ),
          );
        }
        return _TaskDetail(item: item);
      },
    );
  }
}

class _TaskDetail extends ConsumerWidget {
  const _TaskDetail({required this.item});

  final TaskScheduleEntity item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return AppPage(
      title: 'Scheduled task',
      leading: IconButton(
        tooltip: 'Back to schedule',
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            item.title.isEmpty ? 'Scheduled task' : item.title,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          _StatusChip(status: item.status),
          const SizedBox(height: 24),
          _DetailRow(
            icon: Icons.calendar_today_outlined,
            label: 'Scheduled for',
            value: _dateTimeLabel(item.scheduledAt),
          ),
          if (item.address.isNotEmpty)
            _DetailRow(
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: item.address,
            ),
          if (item.siteCode.isNotEmpty)
            _DetailRow(
              icon: Icons.location_city_outlined,
              label: 'Site',
              value: item.siteCode,
            ),
          _DetailRow(
            icon: Icons.category_outlined,
            label: 'Task type',
            value: _labelFor(item.sourceType),
          ),
          if (item.description.isNotEmpty)
            _DetailRow(
              icon: Icons.notes_outlined,
              label: 'Details',
              value: item.description,
            ),
          if (item.assignedToUserId?.isNotEmpty ?? false)
            _DetailRow(
              icon: Icons.person_outline,
              label: 'Assigned user',
              value: item.assignedToUserId!,
            ),
          const SizedBox(height: 24),
          if (_hasSource(item))
            OutlinedButton.icon(
              onPressed: () => _openSource(context, ref, item),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open source record'),
            ),
          if (_canComplete(item.status)) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _setStatus(context, ref, item, 'completed'),
              icon: const Icon(Icons.task_alt_outlined),
              label: const Text('Mark completed'),
            ),
          ],
          if (_canCancel(item.status)) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _setStatus(context, ref, item, 'cancelled'),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel task'),
            ),
          ],
          if (_canReschedule(item.status)) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _reschedule(context, ref, item),
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text('Reschedule task'),
            ),
          ],
          if (_canDelete(item.status)) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => _delete(context, ref, item),
              icon: const Icon(Icons.delete_forever_outlined),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              label: const Text('Delete task permanently'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    TaskScheduleEntity item,
    String status,
  ) async {
    try {
      await ref.read(scheduleRepositoryProvider).update(item.copyWith(status: status));
      ref.invalidate(scheduleTaskProvider(item.id));
      await ref.read(scheduleControllerProvider.notifier).load();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task marked ${_labelFor(status)}.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update task: $error')),
        );
      }
    }
  }

  Future<void> _reschedule(
    BuildContext context,
    WidgetRef ref,
    TaskScheduleEntity item,
  ) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: item.scheduledAt.isBefore(DateTime.now())
          ? DateTime.now()
          : item.scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (selectedDate == null || !context.mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(item.scheduledAt),
    );
    if (selectedTime == null || !context.mounted) return;

    final scheduledAt = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    try {
      await ref.read(scheduleRepositoryProvider).update(
            item.copyWith(
              scheduledDate: selectedDate,
              scheduledAt: scheduledAt,
              status: 'scheduled',
            ),
          );
      ref.invalidate(scheduleTaskProvider(item.id));
      await ref.read(scheduleControllerProvider.notifier).load();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Task rescheduled for ${_dateTimeLabel(scheduledAt)}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not reschedule task: $error')),
        );
      }
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TaskScheduleEntity item,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete scheduled task?'),
        content: const Text(
          'This permanently removes the task from this device and from '
          'Supabase when sync is available. The linked inspection or '
          'maintenance record will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep task'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (shouldDelete != true || !context.mounted) return;

    try {
      await ref.read(scheduleRepositoryProvider).deleteTask(item.id);
      ref.invalidate(scheduleTaskProvider(item.id));
      await ref.read(scheduleControllerProvider.notifier).load();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scheduled task deleted.')),
      );
      context.pop();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete task: $error')),
        );
      }
    }
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 2),
                  Text(value),
                ],
              ),
            ),
          ],
        ),
      );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) => Chip(
        avatar: Icon(_statusIcon(status), size: 18),
        label: Text(_labelFor(status)),
      );
}

bool _hasSource(TaskScheduleEntity item) =>
    (item.inspectionId?.isNotEmpty ?? false) ||
    (_isMaintenanceRecordSource(item) &&
        (item.sourceId?.isNotEmpty ?? false));

bool _canComplete(String status) =>
    status == 'scheduled' || status == 'in_progress';
bool _canCancel(String status) =>
    status == 'scheduled' || status == 'in_progress' || status == 'pending';
bool _canReschedule(String status) => status == 'cancelled';
bool _canDelete(String status) => status == 'completed' || status == 'cancelled';

Future<void> _openSource(
  BuildContext context,
  WidgetRef ref,
  TaskScheduleEntity item,
) async {
  if (item.inspectionId?.isNotEmpty ?? false) {
    context.pushNamed(
      RouteNames.inspectionDetail,
      pathParameters: {'id': item.inspectionId!},
    );
  } else if (_isMaintenanceRecordSource(item) &&
      (item.sourceId?.isNotEmpty ?? false)) {
    // Schedule rows can outlive the local Hive copy of their source record.
    // This is expected after clearing device storage, and legacy `maintenance`
    // rows may also refer to a source that was later removed. Do not route to
    // an empty detail page and make it look like the scheduled task is broken.
    final repository = ref.read(maintenanceRepoProvider);
    var record = repository.getById(item.sourceId!);
    if (record == null) {
      try {
        record = await ref
            .read(maintenanceRemoteDatasourceProvider)
            .getById(item.sourceId!);
        if (record != null) await repository.cacheRemote(record);
      } catch (_) {
        // The clear message below covers offline, RLS, and missing-row cases
        // without exposing transport details to field technicians.
      }
    }
    if (!context.mounted) return;
    if (record == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The linked maintenance record could not be restored. It may have '
            'been deleted, or this device may be offline or not authorized.',
          ),
        ),
      );
      return;
    }
    context.pushNamed(
      RouteNames.maintenanceDetail,
      pathParameters: {'id': item.sourceId!},
    );
  }
}

bool _isMaintenanceRecordSource(TaskScheduleEntity item) =>
    item.sourceType == 'maintenance_record' || item.sourceType == 'maintenance';

String _labelFor(String value) {
  if (value == 'maintenance_record') return 'Maintenance';
  return value
      .split('_')
      .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

String _dateTimeLabel(DateTime value) {
  final hour = value.hour == 0 ? 12 : (value.hour > 12 ? value.hour - 12 : value.hour);
  final minute = value.minute.toString().padLeft(2, '0');
  final suffix = value.hour >= 12 ? 'PM' : 'AM';
  return '${value.month}/${value.day}/${value.year} $hour:$minute $suffix';
}

IconData _statusIcon(String status) => switch (status) {
      'completed' => Icons.task_alt_outlined,
      'cancelled' => Icons.cancel_outlined,
      'in_progress' => Icons.play_circle_outline,
      _ => Icons.schedule_outlined,
    };
