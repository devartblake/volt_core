import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/entities/vehicle_entity.dart';
import '../../domain/entities/vehicle_maintenance_check.dart';
import '../fleet_providers.dart';
import 'vehicle_maintenance_form_page.dart' show formatShortDate;

/// One vehicle.
///
/// Phase 3 adds the tool manifest. The signed receipt for it arrives with
/// phase 4.
class VehicleDetailPage extends ConsumerWidget {
  const VehicleDetailPage({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicle = ref.watch(vehicleProvider(id));
    final isManager = ref.watch(fleetManagerProvider);

    return AppPage(
      title: vehicle.asData?.value?.displayTitle ?? 'Vehicle',
      actions: [
        if (isManager)
          IconButton(
            tooltip: 'Edit vehicle',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                context.push(RoutePaths.fleetEdit.replaceFirst(':id', id)),
          ),
      ],
      body: vehicle.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState.error(
          message: '$error',
          action: FilledButton.tonal(
            onPressed: () => ref.invalidate(vehicleProvider(id)),
            child: const Text('Retry'),
          ),
        ),
        data: (found) {
          if (found == null) {
            return const EmptyState(
              icon: Icons.no_transfer_outlined,
              title: 'Vehicle not found',
              message: 'It may have been removed, or it belongs to another '
                  'tenant.',
            );
          }
          return _VehicleBody(vehicle: found);
        },
      ),
    );
  }
}

class _VehicleBody extends ConsumerWidget {
  const _VehicleBody({required this.vehicle});

  final VehicleEntity vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _Facts(vehicle: vehicle),
        const SizedBox(height: 16),
        _AssignmentCard(vehicle: vehicle),
        if (vehicle.notes.trim().isNotEmpty) ...[
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notes', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Text(vehicle.notes.trim()),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _MaintenanceHistory(vehicle: vehicle),
        const SizedBox(height: 8),
        _AssetsCard(vehicle: vehicle),
      ],
    );
  }
}

class _Facts extends StatelessWidget {
  const _Facts({required this.vehicle});

  final VehicleEntity vehicle;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Designation', vehicle.designation),
      ('Type', vehicle.vehicleType.label),
      if (vehicle.makeModel.isNotEmpty) ('Make / Model', vehicle.makeModel),
      if (vehicle.modelYear != null) ('Year', '${vehicle.modelYear}'),
      // Never blank a row out to '': an empty value reads as "we checked and
      // there is nothing", which is different from "nobody has recorded it".
      ('VIN', vehicle.vin ?? 'Not recorded'),
      (
        'License plate',
        vehicle.licensePlate.trim().isEmpty
            ? 'Not recorded'
            : vehicle.licensePlate.trim()
      ),
      ('Odometer', '${vehicle.odometer} mi'),
      ('Status', vehicle.status.label),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          children: [
            for (final (label, value) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color:
                                  Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        value,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Who is stationed to the vehicle, and what that means.
class _AssignmentCard extends ConsumerWidget {
  const _AssignmentCard({required this.vehicle});

  final VehicleEntity vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final members = ref.watch(fleetAssignableMembersProvider);

    final name = members.maybeWhen(
      data: (list) {
        for (final member in list) {
          if (member.userId == vehicle.assignedToUserId) {
            return member.displayName;
          }
        }
        return vehicle.isAssigned ? 'Former member' : null;
      },
      orElse: () => vehicle.isAssigned ? 'Assigned' : null,
    );

    return Card(
      child: ListTile(
        leading: Icon(
          vehicle.isAssigned ? Icons.person_outline : Icons.person_off_outlined,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        title: Text(name ?? 'Unassigned'),
        subtitle: Text(
          vehicle.isAssigned
              ? 'Responsible for this vehicle and its assets, and signs for it '
                  'when it is dispatched.'
              : 'Nobody is stationed to this vehicle, so no technician can see '
                  'it.',
          style: theme.textTheme.bodySmall,
        ),
        isThreeLine: true,
      ),
    );
  }
}

/// Completed maintenance checks, newest first.
class _MaintenanceHistory extends ConsumerWidget {
  const _MaintenanceHistory({required this.vehicle});

  final VehicleEntity vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final checks = ref.watch(vehicleChecksProvider(vehicle.id));
    final isManager = ref.watch(fleetManagerProvider);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Icon(
              Icons.build_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            title: Text('Maintenance history', style: theme.textTheme.titleSmall),
            subtitle: Text(
              vehicle.lastCheckAt == null
                  ? 'No check recorded yet'
                  : 'Last checked \${formatShortDate(vehicle.lastCheckAt!.toLocal())}',
              style: theme.textTheme.bodySmall,
            ),
            trailing: isManager
                ? IconButton(
                    tooltip: 'Record a check',
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => context.push(
                      RoutePaths.fleetMaintenanceNew
                          .replaceFirst(':id', vehicle.id),
                    ),
                  )
                : null,
          ),
          checks.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(minHeight: 2),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                'Could not load history. \$error',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ),
            data: (list) {
              if (list.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(
                    isManager
                        ? 'Record the first check to start tracking service '
                            'intervals.'
                        : 'Nothing recorded for this vehicle yet.',
                    style: theme.textTheme.bodySmall,
                  ),
                );
              }
              return Column(
                children: [
                  for (final check in list) _CheckTile(check: check),
                  const SizedBox(height: 8),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CheckTile extends StatelessWidget {
  const _CheckTile({required this.check});

  final VehicleMaintenanceCheck check;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final since = check.milesSinceService;

    return ListTile(
      dense: true,
      leading: Icon(
        check.needsFollowUp ? Icons.warning_amber_outlined : Icons.check_circle_outline,
        // A failed brake check has to be visible without reading the row.
        color: check.needsFollowUp
            ? theme.colorScheme.error
            : theme.colorScheme.onSurfaceVariant,
        size: 20,
      ),
      title: Text(formatShortDate(check.checkedAt.toLocal())),
      subtitle: Text(
        [
          '\${check.odometer} mi',
          if (since != null) '\$since mi since service',
          if (check.brakeStatus.needsFollowUp)
            'Brakes: \${check.brakeStatus.label}',
          if (check.batteryStatus.needsFollowUp)
            'Battery: \${check.batteryStatus.label}',
        ].join('  ·  '),
        style: theme.textTheme.bodySmall,
      ),
      isThreeLine: check.notes.trim().isNotEmpty,
    );
  }
}

/// The tools this vehicle carries, summarised, linking to the full list.
class _AssetsCard extends ConsumerWidget {
  const _AssetsCard({required this.vehicle});

  final VehicleEntity vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final assets = ref.watch(vehicleAssetsProvider(vehicle.id));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: () => context.push(
          RoutePaths.fleetVehicleAssets.replaceFirst(':id', vehicle.id),
        ),
        leading: Icon(
          Icons.handyman_outlined,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        title: Text('Vehicle assets', style: theme.textTheme.titleSmall),
        subtitle: Text(
          assets.when(
            loading: () => 'Loading…',
            error: (_, __) => 'Could not load the tool list',
            data: (list) {
              if (list.isEmpty) return 'No tools assigned';
              final needing =
                  list.where((r) => r.asset.needsAttention).length;
              final carried =
                  list.length == 1 ? '1 tool' : '${list.length} tools';
              // Lead with the problem when there is one: a missing ladder is
              // why somebody opened this page.
              return needing == 0
                  ? '$carried · all present and FMC'
                  : '$carried · $needing missing or NMC';
            },
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: assets.asData?.value.any((r) => r.asset.needsAttention) == true
                ? theme.colorScheme.error
                : null,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

