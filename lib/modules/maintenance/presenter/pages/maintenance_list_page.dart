import 'package:flutter/material.dart';
import '../../../auth/presenter/sign_off_access.dart';
import '../utils/maintenance_pdf_actions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../schedule/presenter/pages/schedule_task_page.dart';
import '../../../schedule/presenter/widgets/dialogs/schedule_dialog.dart';
import '../../domain/maintenance_list_filter.dart';
import '../../infra/datasources/maintenance_remote_datasource.dart';
import '../../infra/mappers/maintenance_supabase_mapper.dart' show kMaintenanceRecordsTable;
import '../../../../shared/widgets/pending_upload_badge.dart';
import '../../infra/models/maintenance_record.dart';
import '../../../../core/theme/app_tokens.dart';
import '../controllers/maintenance_list_controller.dart';
import '../controllers/maintenance_list_progress.dart';
import '../controllers/maintenance_providers.dart';
import '../../../../shared/widgets/widgets.dart';

class MaintenanceListPage extends ConsumerWidget {
  const MaintenanceListPage({super.key});

  /// Pulls any maintenance records that are in the cloud but not on this
  /// device (made on another device, or lost to a cache reset). Records
  /// already here are never overwritten.
  Future<void> _restoreFromCloud(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    AppSnackBar.infoOn(messenger, 'Checking the cloud for missing records…');
    try {
      final remote =
          await ref.read(maintenanceRemoteDatasourceProvider).listAll();
      final added =
          await ref.read(maintenanceRepoProvider).restoreMissing(remote);
      await ref.read(maintenanceListControllerProvider.notifier).refresh();
      messenger.hideCurrentSnackBar();
      if (remote.isEmpty) {
        // Row-level security returns an empty list, not an error, when the
        // session is signed out or not a member of the tenant.
        AppSnackBar.warningOn(
          messenger,
          'The cloud returned no records. You may be signed out; sign in '
          'again and retry.',
        );
      } else if (added == 0) {
        AppSnackBar.infoOn(
          messenger,
          'Nothing missing: all ${remote.length} cloud records are already '
          'on this device.',
        );
      } else {
        AppSnackBar.successOn(
          messenger,
          added == 1
              ? 'Restored 1 record (of ${remote.length} in the cloud).'
              : 'Restored $added records (of ${remote.length} in the cloud).',
        );
      }
    } catch (e) {
      messenger.hideCurrentSnackBar();
      AppSnackBar.errorOn(
        messenger,
        'Could not read the cloud: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Use the StateNotifier state instead of an AsyncValue
    final listState = ref.watch(maintenanceListControllerProvider);

    return AppPage(
      title: 'Maintenance',
      actions: [
        IconButton(
          tooltip: 'Restore missing records from the cloud',
          icon: const Icon(Icons.cloud_download_outlined),
          onPressed: () => _restoreFromCloud(context, ref),
        ),
      ],
      body: Builder(
        builder: (context) {
          // 1) Loading with no data yet
          if (listState.isLoading && listState.records.isEmpty) {
            return const LoadingIndicator();
          }

          // 2) Error with no data
          if (listState.error != null && listState.records.isEmpty) {
            final err = listState.error;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load maintenance records.',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$err',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => ref
                          .read(maintenanceListControllerProvider.notifier)
                          .refresh(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          // 3) No records
          final all = listState.records;
          if (all.isEmpty) {
            return const _MaintenanceEmpty();
          }

          // 4) Normal list, narrowed by the status filter
          final filter = ref.watch(maintenanceStatusFilterProvider);
          final list = filterMaintenance(all, filter);
          final counts =
              ref.watch(maintenanceListCountsProvider).asData?.value;
          return Column(
            children: [
              _StatusFilterRow(
                selected: filter,
                onSelected: (f) => ref
                    .read(maintenanceStatusFilterProvider.notifier)
                    .state = f,
              ),
              Expanded(
                child: list.isEmpty
                    ? _NoMatches(filter: filter)
                    : ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final m = list[i]; // m is MaintenanceRecord
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _SwipeToDelete(
                  record: m,
                  child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: colorScheme.outlineVariant),
                  ),
                  child: InkWell(
                    onTap: () =>
                        context.push('/maintenance/detail/${m.id}'),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.build_circle_outlined,
                                  color: colorScheme.onPrimaryContainer,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      crossAxisAlignment:
                                          WrapCrossAlignment.center,
                                      children: [
                                        Text(
                                          m.siteCode.isEmpty
                                              ? 'Maintenance ${m.id}'
                                              : m.siteCode,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (m.completed)
                                          const StatusChip(
                                            label: 'Completed',
                                            tone: StatusTone.success,
                                            icon: Icons.check_circle_outline,
                                          )
                                        else
                                          StatusChip(
                                            label: maintenanceInProgressLabel(
                                                m, counts?[m.id]),
                                            tone: StatusTone.warning,
                                            icon: Icons.timelapse,
                                          ),
                                        PendingUploadBadge(
                                          table: kMaintenanceRecordsTable,
                                          recordId: m.id,
                                        ),
                                      ],
                                    ),
                                    if (_subtitleFor(m).isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        _subtitleFor(m),
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                          color: colorScheme
                                              .onSurfaceVariant,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              // Export PDF button
                              IconButton.filledTonal(
                                icon: const Icon(
                                  Icons.picture_as_pdf_outlined,
                                ),
                                tooltip: 'Export PDF',
                                onPressed: () =>
                                    exportMaintenancePdfWithFeedback(
                                  context,
                                  ref.read(maintenanceRepoProvider),
                                  m,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                icon: const Icon(Icons.print_outlined),
                                tooltip: 'Print saved PDF',
                                onPressed: () => printMaintenancePdfWithFeedback(
                                  context,
                                  ref.read(maintenanceRepoProvider),
                                  m,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // ⭐ NEW: Schedule button
                              IconButton.filledTonal(
                                icon: const Icon(Icons.calendar_today),
                                tooltip: 'Schedule',
                                onPressed: () async {
                                  final scheduled = await showScheduleDialog(
                                    context: context,
                                    taskType: TaskType.maintenance,
                                    siteCode: m.siteCode,
                                    address: m.address,
                                    maintenanceId: m.id,
                                  );

                                  if (scheduled == true && context.mounted) {
                                    AppSnackBar.success(context, 'Maintenance scheduled');
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
                              // Delete button
                              IconButton.filledTonal(
                                icon:
                                const Icon(Icons.delete_outline),
                                tooltip: 'Delete',
                                style: IconButton.styleFrom(
                                  foregroundColor: colorScheme.error,
                                ),
                                onPressed: () async {
                                  final confirm =
                                  await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text(
                                          'Delete maintenance record?'),
                                      content: Text(
                                        m.siteCode.isEmpty
                                            ? 'Are you sure you want to delete this maintenance record? This action cannot be undone.'
                                            : 'Are you sure you want to delete the maintenance record for "${m.siteCode}"? This action cannot be undone.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(ctx)
                                                  .pop(false),
                                          child: const Text('Cancel'),
                                        ),
                                        FilledButton(
                                          onPressed: () =>
                                              Navigator.of(ctx)
                                                  .pop(true),
                                          style: FilledButton.styleFrom(
                                            backgroundColor:
                                            colorScheme.error,
                                          ),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true &&
                                      context.mounted) {
                                    final repo =
                                    ref.read(maintenanceRepoProvider);
                                    await repo.delete(m.id);

                                    // Reload via controller
                                    await ref
                                        .read(
                                        maintenanceListControllerProvider
                                            .notifier)
                                        .refresh();

                                    if (context.mounted) {
                                      AppSnackBar.success(
                                        context,
                                        'Maintenance record deleted',
                                      );
                                    }
                                  }
                                },
                              ),
                            ],
                          ),
                          if (m.address.isNotEmpty ||
                              m.generatorMake.isNotEmpty ||
                              m.dateOfService != null) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (m.address.isNotEmpty)
                                  InfoChip(
                                    filled: true,
                                    icon: Icons.place_outlined,
                                    label: m.address,
                                  ),
                                if (m.generatorMake.isNotEmpty ||
                                    m.generatorModel.isNotEmpty)
                                  InfoChip(
                                    filled: true,
                                    icon: Icons.settings_outlined,
                                    label:
                                    '${m.generatorMake} ${m.generatorModel}'
                                        .trim(),
                                  ),
                                if (m.dateOfService != null)
                                  InfoChip(
                                    filled: true,
                                    icon:
                                    Icons.calendar_today_outlined,
                                    label: m.dateOfService!
                                        .toLocal()
                                        .toString()
                                        .split(' ')
                                        .first,
                                  ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                ),
              );
            },
          ),
              ),
            ],
          );
        },
      ),
      fab: FloatingActionButton.extended(
        onPressed: () async {
          final repo = ref.read(maintenanceRepoProvider);

          // Create a new MaintenanceRecord in Hive
          final rec = repo.createNew();

          // Reload the list via controller
          await ref
              .read(maintenanceListControllerProvider.notifier)
              .refresh();

          // Navigate to the form route with the new id
          if (!context.mounted) return;
          context.push('/maintenance/new?id=${rec.id}');
        },
        icon: const Icon(Icons.add),
        label: const Text('New Maintenance'),
      ),
    );
  }

  // NOTE: uses MaintenanceRecord, not MaintenanceJobEntity
  String _subtitleFor(MaintenanceRecord m) {
    final parts = <String>[];
    if (m.technicianName.isNotEmpty) {
      parts.add('Tech: ${m.technicianName}');
    }
    if (m.engineHours.isNotEmpty) {
      parts.add('${m.engineHours} hrs');
    }
    return parts.join(' • ');
  }
}


class _MaintenanceEmpty extends StatelessWidget {
  const _MaintenanceEmpty();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.build_circle_outlined,
                size: 64,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No maintenance records yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Use the New Maintenance button to create your first record.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// All / In progress / Completed.
class _StatusFilterRow extends StatelessWidget {
  const _StatusFilterRow({required this.selected, required this.onSelected});

  final MaintenanceStatusFilter selected;
  final ValueChanged<MaintenanceStatusFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        0,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final f in MaintenanceStatusFilter.values)
              ChoiceChip(
                label: Text(f.label),
                selected: f == selected,
                onSelected: (_) => onSelected(f),
              ),
          ],
        ),
      ),
    );
  }
}

class _NoMatches extends StatelessWidget {
  const _NoMatches({required this.filter});

  final MaintenanceStatusFilter filter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.huge),
        child: Text(
          'No ${filter.label.toLowerCase()} maintenance records.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Swipe a card left to delete it. There is no confirm dialog because the
/// snackbar offers Undo, which puts the exact record back.
class _SwipeToDelete extends ConsumerWidget {
  const _SwipeToDelete({required this.record, required this.child});

  final MaintenanceRecord record;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey('maintenance-${record.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xxl),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Icon(Icons.delete_outline, color: colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) async {
        if (ref.read(canDeleteRecordsProvider)) return true;
        showSignOffBlocked(context);
        return false;
      },
      onDismissed: (_) async {
        final messenger = ScaffoldMessenger.of(context);
        final controller =
            ref.read(maintenanceListControllerProvider.notifier);
        final label = record.siteCode.isEmpty ? 'Record' : record.siteCode;
        try {
          await controller.delete(record);
        } catch (e) {
          AppSnackBar.errorOn(messenger, 'Could not delete: $e');
          return;
        }
        AppSnackBar.infoOn(
          messenger,
          '$label deleted',
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              try {
                await controller.restore(record);
              } catch (e) {
                AppSnackBar.errorOn(messenger, 'Could not restore: $e');
              }
            },
          ),
        );
      },
      child: child,
    );
  }
}
