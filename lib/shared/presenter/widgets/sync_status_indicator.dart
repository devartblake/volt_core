import 'package:flutter/material.dart';

import '../../../core/services/sync/sync_service.dart';

/// Compact sync-state chip for app bars.
///
/// Reflects the live [SyncService] status: offline, syncing, pending uploads,
/// failed uploads, or fully synced. Tapping it triggers a manual drain (and
/// retries any failed operations).
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key, this.compact = true});

  /// When true, shows just the icon (+ a count badge). When false, also shows a
  /// short text label.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: SyncService.instance.status,
      builder: (context, status, _) {
        final visual = _visualFor(status, Theme.of(context).colorScheme);

        return Tooltip(
          message: visual.tooltip,
          // Icon-only status: without this a screen reader announces nothing
          // useful, and the count badge is just a bare number.
          child: Semantics(
            button: true,
            container: true,
            label: 'Sync status: ${visual.tooltip}',
            hint: status.failed > 0 ? 'Retry failed uploads' : 'Sync now',
            child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              if (status.failed > 0) {
                SyncService.instance.retryFailed();
              } else {
                SyncService.instance.sync();
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (status.state == SyncState.syncing)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: visual.color,
                      ),
                    )
                  else
                    Icon(visual.icon, size: 18, color: visual.color),
                  if (!compact) ...[
                    const SizedBox(width: 6),
                    Text(
                      visual.label,
                      style: TextStyle(color: visual.color, fontSize: 12),
                    ),
                  ] else if (status.pending + status.failed > 0) ...[
                    const SizedBox(width: 4),
                    Text(
                      '${status.pending + status.failed}',
                      style: TextStyle(
                        color: visual.color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          ),
        );
      },
    );
  }

  _SyncVisual _visualFor(SyncStatus status, ColorScheme scheme) {
    if (status.state == SyncState.offline) {
      return _SyncVisual(
        icon: Icons.cloud_off,
        color: scheme.outline,
        label: 'Offline',
        tooltip: status.hasPendingWork
            ? 'Offline — ${status.pending + status.failed} change(s) will sync when reconnected'
            : 'Offline',
      );
    }
    if (status.failed > 0) {
      return _SyncVisual(
        icon: Icons.error_outline,
        color: scheme.error,
        label: '${status.failed} failed',
        tooltip: '${status.failed} change(s) failed to sync — tap to retry',
      );
    }
    if (status.state == SyncState.syncing) {
      return _SyncVisual(
        icon: Icons.sync,
        color: scheme.primary,
        label: 'Syncing…',
        tooltip: 'Syncing ${status.pending} change(s)…',
      );
    }
    if (status.pending > 0) {
      return _SyncVisual(
        icon: Icons.cloud_upload_outlined,
        color: scheme.primary,
        label: '${status.pending} pending',
        tooltip: '${status.pending} change(s) waiting to sync — tap to sync now',
      );
    }
    return _SyncVisual(
      icon: Icons.cloud_done_outlined,
      color: scheme.primary,
      label: 'Synced',
      tooltip: status.lastSyncedAt != null
          ? 'All changes synced'
          : 'Up to date',
    );
  }
}

class _SyncVisual {
  _SyncVisual({
    required this.icon,
    required this.color,
    required this.label,
    required this.tooltip,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String tooltip;
}
