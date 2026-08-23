import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/entities/task_schedule_entity.dart';
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
              onPressed: () => _openSource(context, item),
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
    (item.sourceType == 'maintenance' && (item.sourceId?.isNotEmpty ?? false));

bool _canComplete(String status) => status == 'scheduled' || status == 'in_progress';
bool _canCancel(String status) => status == 'scheduled' || status == 'in_progress' || status == 'pending';

void _openSource(BuildContext context, TaskScheduleEntity item) {
  if (item.inspectionId?.isNotEmpty ?? false) {
    context.pushNamed(
      RouteNames.inspectionDetail,
      pathParameters: {'id': item.inspectionId!},
    );
  } else if (item.sourceType == 'maintenance' && (item.sourceId?.isNotEmpty ?? false)) {
    context.pushNamed(
      RouteNames.maintenanceDetail,
      pathParameters: {'id': item.sourceId!},
    );
  }
}

String _labelFor(String value) => value
    .split('_')
    .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');

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
