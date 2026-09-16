import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/entities/vehicle_entity.dart';
import '../fleet_providers.dart';

/// The fleet, or the one vehicle a technician is stationed to.
class VehicleListPage extends ConsumerWidget {
  const VehicleListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(fleetVisibleVehiclesProvider);
    final isManager = ref.watch(fleetManagerProvider);
    final attention = ref.watch(fleetAttentionProvider);

    return AppPage(
      title: isManager ? 'Fleet' : 'My Vehicle',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: () {
            ref.invalidate(fleetVisibleVehiclesProvider);
            ref.invalidate(fleetAttentionProvider);
          },
        ),
      ],
      fab: isManager
          ? FloatingActionButton.extended(
              onPressed: () => context.push(RoutePaths.fleetNew),
              icon: const Icon(Icons.add),
              label: const Text('Add vehicle'),
            )
          : null,
      body: vehicles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState.error(
          message: '$error',
          action: FilledButton.tonal(
            onPressed: () => ref.invalidate(fleetVisibleVehiclesProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.local_shipping_outlined,
              title: isManager ? 'No vehicles yet' : 'No vehicle assigned',
              message: isManager
                  ? 'Add the first van or truck to start tracking it.'
                  : 'Dispatch has not stationed you to a vehicle yet. Speak to '
                      'them if you are driving today.',
            );
          }

          final flags = attention.asData?.value ?? FleetAttention.empty;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(fleetVisibleVehiclesProvider);
              ref.invalidate(fleetAttentionProvider);
            },
            child: Column(
              children: [
                if (isManager && !flags.isQuiet)
                  _FleetAttentionBanner(attention: flags),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _VehicleTile(
                      vehicle: list[index],
                      missing: flags.missingFor(list[index].id),
                      nmc: flags.nmcFor(list[index].id),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The in-app half of "a missing tool raises a notification".
///
/// There is no push infrastructure in this app — NotificationService is
/// flutter_local_notifications, which only reaches the device that scheduled
/// the reminder. So the signal dispatch actually gets is this: a banner and a
/// per-vehicle badge that appear as soon as the signed receipt syncs.
class _FleetAttentionBanner extends StatelessWidget {
  const _FleetAttentionBanner({required this.attention});

  final FleetAttention attention;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = <String>[
      if (attention.totalMissing > 0)
        attention.totalMissing == 1
            ? '1 tool missing'
            : '${attention.totalMissing} tools missing',
      if (attention.awaitingCountersign > 0)
        attention.awaitingCountersign == 1
            ? '1 receipt awaiting verification'
            : '${attention.awaitingCountersign} receipts awaiting verification',
    ];

    return Container(
      width: double.infinity,
      color: theme.colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            Icons.notifications_active_outlined,
            size: 20,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              parts.join('  ·  '),
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleTile extends StatelessWidget {
  const _VehicleTile({
    required this.vehicle,
    this.missing = 0,
    this.nmc = 0,
  });

  final VehicleEntity vehicle;

  /// Tools this van is carrying that its last receipt reported missing, and
  /// tools reported present but unserviceable.
  final int missing;
  final int nmc;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => context.push(
          RoutePaths.fleetDetail.replaceFirst(':id', vehicle.id),
        ),
        leading: CircleAvatar(
          backgroundColor: scheme.primaryContainer,
          child: Icon(
            _iconFor(vehicle.vehicleType),
            color: scheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          vehicle.displayTitle,
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (vehicle.makeModel.isNotEmpty) Text(vehicle.makeModel),
            Text(
              [
                if (vehicle.licensePlate.trim().isNotEmpty)
                  vehicle.licensePlate.trim(),
                '${_thousands(vehicle.odometer)} mi',
              ].join('  ·  '),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (missing > 0 || nmc > 0) ...[
              Tooltip(
                message: [
                  if (missing > 0) '$missing missing',
                  if (nmc > 0) '$nmc not mission capable',
                ].join(', '),
                child: Badge(
                  backgroundColor: scheme.error,
                  label: Text('${missing + nmc}'),
                  child: Icon(Icons.handyman_outlined, color: scheme.error),
                ),
              ),
              const SizedBox(width: 12),
            ],
            _StatusChip(status: vehicle.status),
          ],
        ),
        isThreeLine: vehicle.makeModel.isNotEmpty,
      ),
    );
  }

  static IconData _iconFor(VehicleType type) => switch (type) {
        VehicleType.van => Icons.airport_shuttle_outlined,
        VehicleType.truck => Icons.local_shipping_outlined,
        VehicleType.other => Icons.directions_car_outlined,
      };
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final VehicleStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final color = switch (status) {
      VehicleStatus.active => theme.status.success,
      VehicleStatus.maintenance => theme.status.warning,
      VehicleStatus.outOfService => scheme.error,
      VehicleStatus.retired => scheme.onSurfaceVariant,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.label,
        style: theme.textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// 55779 -> "55,779". An odometer without separators is genuinely hard to read
/// at a glance, and this number is compared against the last service reading.
String _thousands(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}
