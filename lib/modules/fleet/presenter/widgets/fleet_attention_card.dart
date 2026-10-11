import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_paths.dart';
import '../fleet_providers.dart';

/// The dashboard's fleet alert.
///
/// This is where a missing tool actually reaches dispatch. The app has no push
/// notifications — NotificationService is flutter_local_notifications, which
/// only ever reaches the device that scheduled the reminder — so the signal is
/// a card that appears here the moment a signed receipt syncs, and stays until
/// the tool is found or written off.
///
/// **Renders nothing when there is nothing to say.** A permanently visible
/// "0 tools missing" panel is how people learn to stop looking at a spot on the
/// screen, which would defeat the entire point of it.
class FleetAttentionCard extends ConsumerWidget {
  const FleetAttentionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(fleetManagerProvider)) return const SizedBox.shrink();

    final attention = ref.watch(fleetAttentionProvider);
    final flags = attention.asData?.value;
    if (flags == null || flags.isQuiet) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      color: scheme.errorContainer,
      child: InkWell(
        onTap: () => context.push(RoutePaths.fleet),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                color: scheme.onErrorContainer,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fleet needs attention',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: scheme.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (flags.totalMissing > 0)
                          flags.vehiclesWithMissing == 1
                              ? '${flags.totalMissing} tool(s) missing on 1 '
                                  'vehicle'
                              : '${flags.totalMissing} tools missing across '
                                  '${flags.vehiclesWithMissing} vehicles',
                        if (flags.awaitingCountersign > 0)
                          flags.awaitingCountersign == 1
                              ? '1 receipt awaiting verification'
                              : '${flags.awaitingCountersign} receipts '
                                  'awaiting verification',
                      ].join('  ·  '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onErrorContainer),
            ],
          ),
        ),
      ),
    );
  }
}
