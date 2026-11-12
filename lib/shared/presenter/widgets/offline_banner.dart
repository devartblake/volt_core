import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/services/sync/sync_service.dart';
import '../../../core/theme/app_tokens.dart';

/// Shown under the app bar while the device is offline and changes are waiting.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.status});

  /// Override for tests; defaults to the live [SyncService] status.
  final ValueListenable<SyncStatus>? status;

  static const String message =
      'Changes are saved on this device and will upload when you are back online';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncStatus>(
      valueListenable: status ?? SyncService.instance.status,
      builder: (context, s, _) {
        if (s.state != SyncState.offline || !s.hasPendingWork) {
          return const SizedBox.shrink();
        }
        final scheme = Theme.of(context).colorScheme;
        return Semantics(
          liveRegion: true,
          container: true,
          child: Material(
            color: scheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(children: [
                Icon(Icons.cloud_off,
                    size: 18, color: scheme.onSecondaryContainer),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                  ),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}
