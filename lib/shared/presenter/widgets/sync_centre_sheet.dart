import 'package:flutter/material.dart';

import '../../../core/services/sync/sync_operation.dart';
import '../../../core/services/sync/sync_service.dart';
import '../../../core/services/sync/sync_summary.dart';
import '../../../core/theme/app_tokens.dart';
import '../../widgets/app_snack_bar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_chip.dart';

/// Opens the sync centre. [status], [loadQueue] and [actions] exist for tests.
Future<void> showSyncCentre(
  BuildContext context, {
  ValueNotifier<SyncStatus>? status,
  Future<List<SyncOperation>> Function()? loadQueue,
  SyncCentreActions? actions,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 680),
    builder: (_) => SyncCentreSheet(
      status: status ?? SyncService.instance.status,
      loadQueue: loadQueue ?? SyncService.instance.queuedOperations,
      actions: actions ?? SyncCentreActions.live(),
    ),
  );
}

/// What the sheet's buttons do.
class SyncCentreActions {
  const SyncCentreActions({
    required this.syncNow,
    required this.retryAll,
    required this.retryOne,
  });

  factory SyncCentreActions.live() => SyncCentreActions(
        syncNow: SyncService.instance.sync,
        retryAll: SyncService.instance.retryFailed,
        retryOne: SyncService.instance.retryOperation,
      );

  final Future<void> Function() syncNow;
  final Future<void> Function() retryAll;
  final Future<void> Function(String opId) retryOne;
}

String formatSyncTime(DateTime? t, {DateTime? now}) {
  if (t == null) return 'Not yet this session';
  final n = now ?? DateTime.now();
  final d = n.difference(t);
  if (d.inSeconds < 60) return 'Just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');
  if (t.year == n.year && t.month == n.month && t.day == n.day) {
    return 'Today at $hh:$mm';
  }
  return '${t.year}-${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')} $hh:$mm';
}

class SyncCentreSheet extends StatefulWidget {
  const SyncCentreSheet({
    super.key,
    required this.status,
    required this.loadQueue,
    required this.actions,
  });

  final ValueNotifier<SyncStatus> status;
  final Future<List<SyncOperation>> Function() loadQueue;
  final SyncCentreActions actions;

  @override
  State<SyncCentreSheet> createState() => _SyncCentreSheetState();
}

class _SyncCentreSheetState extends State<SyncCentreSheet> {
  SyncSummary _summary = const SyncSummary(pending: [], failed: []);
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.status.addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    widget.status.removeListener(_reload);
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final ops = await widget.loadQueue();
      if (!mounted) return;
      setState(() {
        _summary = summarizeQueue(ops);
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (messenger != null) AppSnackBar.errorOn(messenger, 'Sync failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
      await _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: widget.status,
      builder: (context, status, _) {
        final offline = status.state == SyncState.offline;
        final syncing = status.state == SyncState.syncing;
        return ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          children: [
            Text('Sync', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Last synced: ${formatSyncTime(status.lastSyncedAt)}',
              style: theme.textTheme.bodyMedium,
            ),
            if (offline || syncing) ...[
              const SizedBox(height: AppSpacing.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: offline
                    ? const StatusChip(
                        label: 'Offline',
                        tone: StatusTone.warning,
                        icon: Icons.cloud_off,
                      )
                    : const StatusChip(
                        label: 'Syncing',
                        tone: StatusTone.info,
                        icon: Icons.sync,
                      ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              onPressed:
                  _busy || syncing ? null : () => _run(widget.actions.syncNow),
              icon: const Icon(Icons.sync),
              label: const Text('Sync now'),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (!_loaded)
              const Center(child: CircularProgressIndicator())
            else if (_summary.isEmpty)
              const EmptyState(
                icon: Icons.cloud_done_outlined,
                title: 'Everything is uploaded',
                message: 'No changes are waiting on this device.',
                compact: true,
              )
            else ...[
              if (_summary.pending.isNotEmpty) ...[
                Text(
                  'Waiting to upload (${_summary.pendingCount})',
                  style: theme.textTheme.titleSmall,
                ),
                for (final g in _summary.pending)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(g.label),
                    trailing: Text(
                      '${g.count}',
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
              ],
              if (_summary.failed.isNotEmpty) ...[
                Row(children: [
                  Expanded(
                    child: Text(
                      'Failed (${_summary.failed.length})',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                  ),
                  TextButton(
                    onPressed:
                        _busy ? null : () => _run(widget.actions.retryAll),
                    child: const Text('Retry all'),
                  ),
                ]),
                for (final op in _summary.failed)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(groupLabelFor(op)),
                    subtitle: Text(
                      shortError(op.lastError),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: TextButton(
                      onPressed: _busy
                          ? null
                          : () => _run(() => widget.actions.retryOne(op.id)),
                      child: const Text('Retry'),
                    ),
                  ),
              ],
            ],
          ],
        );
      },
    );
  }
}
