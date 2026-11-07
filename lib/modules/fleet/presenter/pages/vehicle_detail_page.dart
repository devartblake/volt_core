import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../shared/widgets/pending_upload_badge.dart';
import '../../infra/mappers/vehicle_inspection_supabase_mapper.dart' show kVehicleInspectionsTable;
import '../../../../core/services/photos/photo_attachment.dart';
import '../../../../shared/presenter/widgets/photo_attachments_section.dart';
import '../../domain/entities/vehicle_entity.dart';
import '../../domain/entities/vehicle_inspection.dart';
import '../../infra/repositories/vehicle_inspection_repository.dart';
import '../../infra/repositories/vehicle_repository_impl.dart';
import '../../domain/entities/vehicle_maintenance_check.dart';
import '../../../auth/presenter/controllers/auth_controller.dart';
import '../../../documents/presenter/document_actions_provider.dart';
import '../../domain/daily_check_status.dart';
import '../fleet_providers.dart';
import '../vehicle_pdf_actions.dart';
import '../widgets/vehicle_inspection_detail_sheet.dart';
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

    return DefaultTabController(
      length: _VehicleTab.values.length,
      child: AppPage(
        title: vehicle.asData?.value?.displayTitle ?? 'Vehicle',
        actions: [
          if (vehicle.asData?.value != null)
            IconButton(
              tooltip: 'Generate PDF',
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: () async {
                await generateVehiclePdfWithFeedback(
                  context,
                  ref,
                  vehicle.asData!.value!,
                );
                ref.invalidate(vehicleDocumentsProvider(id));
              },
            ),
          if (isManager)
            IconButton(
              tooltip: 'Edit vehicle',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.push(RoutePaths.fleetEdit.replaceFirst(':id', id)),
            ),
        ],
        appBarBottom: _VehicleTabBar(vehicleId: id),
        body: vehicle.when(
          loading: () => const LoadingIndicator(),
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
      ),
    );
  }
}

/// The tabs of a vehicle. Details that used to be one long scroll are grouped
/// by what the person came to do.
enum _VehicleTab {
  overview('Overview', Icons.info_outline),
  inspections('Inspections', Icons.fact_check_outlined),
  maintenance('Maintenance', Icons.build_circle_outlined),
  media('Media', Icons.photo_library_outlined),
  tools('Tools', Icons.handyman_outlined),
  documents('Documents', Icons.picture_as_pdf_outlined);

  const _VehicleTab(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Tab bar with a count on the tabs that hold a list.
class _VehicleTabBar extends ConsumerWidget implements PreferredSizeWidget {
  const _VehicleTabBar({required this.vehicleId});

  final String vehicleId;

  @override
  Size get preferredSize => const Size.fromHeight(kTextTabBarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inspections =
        ref.watch(vehicleInspectionsProvider(vehicleId)).asData?.value.length;
    final checks =
        ref.watch(vehicleChecksProvider(vehicleId)).asData?.value.length;

    final documents =
        ref.watch(vehicleDocumentsProvider(vehicleId)).asData?.value.length;

    String label(_VehicleTab tab) {
      final count = switch (tab) {
        _VehicleTab.inspections => inspections,
        _VehicleTab.maintenance => checks,
        _VehicleTab.documents => documents,
        _ => null,
      };
      return count == null || count == 0 ? tab.label : '${tab.label} ($count)';
    }

    return TabBar(
      isScrollable: true,
      tabAlignment: TabAlignment.start,
      tabs: [
        for (final tab in _VehicleTab.values)
          Tab(icon: Icon(tab.icon, size: 20), text: label(tab), height: 56),
      ],
    );
  }
}

class _VehicleBody extends ConsumerWidget {
  const _VehicleBody({required this.vehicle});

  final VehicleEntity vehicle;

  /// Each tab scrolls on its own, so the summary stays put above them.
  Widget _tab(List<Widget> children) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: children,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      children: [
        _VehicleSummary(vehicle: vehicle),
        Expanded(
          child: TabBarView(
            children: [
              // Overview
              _tab([
                _DailyInspectionBanner(vehicle: vehicle),
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
              ]),
              // Inspections
              _tab([_InspectionsCard(vehicle: vehicle)]),
              // Maintenance
              _tab([_MaintenanceHistory(vehicle: vehicle)]),
              // Media
              _tab([
                PhotoAttachmentsSection(
                  ownerType: PhotoAttachment.ownerVehicle,
                  ownerId: vehicle.id,
                  title: 'Photos & videos',
                  allowVideo: true,
                ),
              ]),
              // Tools
              _tab([_AssetsCard(vehicle: vehicle)]),
              // Documents
              _tab([_DocumentsCard(vehicle: vehicle)]),
            ],
          ),
        ),
      ],
    );
  }
}

/// The vehicle at a glance, above the tabs: status, plate and mileage, who has
/// it, and whether today's daily check is done.
class _VehicleSummary extends ConsumerWidget {
  const _VehicleSummary({required this.vehicle});

  final VehicleEntity vehicle;

  StatusTone _tone(VehicleStatus s) => switch (s) {
        VehicleStatus.active => StatusTone.success,
        VehicleStatus.maintenance => StatusTone.warning,
        VehicleStatus.outOfService => StatusTone.danger,
        VehicleStatus.retired => StatusTone.neutral,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final history = ref.watch(vehicleInspectionsProvider(vehicle.id));

    final daily = history.maybeWhen(
      data: (list) => dailyCheckState(list),
      orElse: () => null,
    );

    final plate = vehicle.licensePlate.trim();
    final facts = [
      if (plate.isNotEmpty) plate,
      if (vehicle.makeModel.isNotEmpty) vehicle.makeModel,
      '${vehicle.odometer} mi',
    ].join('  ·  ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StatusChip(label: vehicle.status.label, tone: _tone(vehicle.status)),
          StatusChip(
            label: vehicle.isAssigned ? 'Assigned' : 'Unassigned',
            tone: vehicle.isAssigned ? StatusTone.info : StatusTone.neutral,
            icon: vehicle.isAssigned
                ? Icons.person_outline
                : Icons.person_off_outlined,
          ),
          if (daily != null)
            daily == DailyCheckState.doneToday
                ? const StatusChip(
                    label: 'Daily check done',
                    tone: StatusTone.success,
                    icon: Icons.check_circle_outline,
                  )
                : InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => context.push(
                      '${RoutePaths.fleetInspectionNew.replaceFirst(':id', vehicle.id)}'
                      '?cadence=daily',
                    ),
                    child: const StatusChip(
                      label: 'Daily check due - start',
                      tone: StatusTone.danger,
                      icon: Icons.warning_amber_rounded,
                    ),
                  ),
          Text(
            facts,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Shown to the person the vehicle is assigned to until today's inspection is
/// done: the vehicle should not leave before it is.
class _DailyInspectionBanner extends ConsumerWidget {
  const _DailyInspectionBanner({required this.vehicle});

  final VehicleEntity vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = ref.watch(authStateProvider).userId;
    final assigned = vehicle.isAssigned && vehicle.assignedToUserId == userId;
    if (!assigned) return const SizedBox.shrink();

    final history = ref.watch(vehicleInspectionsProvider(vehicle.id));
    return history.maybeWhen(
      data: (list) {
        final status =
            InspectionStatus.compute(InspectionCadence.daily, list);
        if (status.state == InspectionDueState.ok) {
          return const SizedBox.shrink();
        }
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Card(
            color: theme.colorScheme.errorContainer,
            child: ListTile(
              leading: Icon(Icons.warning_amber_rounded,
                  color: theme.colorScheme.onErrorContainer),
              title: Text(
                'Complete the daily inspection before taking this vehicle',
                style: TextStyle(
                  color: theme.colorScheme.onErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
              trailing: FilledButton(
                onPressed: () => context.push(
                  '${RoutePaths.fleetInspectionNew.replaceFirst(':id', vehicle.id)}'
                  '?cadence=daily',
                ),
                child: const Text('Start'),
              ),
            ),
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
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
        trailing: ref.watch(fleetManagerProvider)
            ? _AssignDriverButton(vehicle: vehicle)
            : null,
      ),
    );
  }
}

/// Add-menu for the stationed driver: pick any active team member, or clear.
class _AssignDriverButton extends ConsumerWidget {
  const _AssignDriverButton({required this.vehicle});

  final VehicleEntity vehicle;

  static const String _clear = '__unassign__';

  Future<void> _assign(
    BuildContext context,
    WidgetRef ref,
    String selection,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(vehicleRepositoryProvider)
          .assign(vehicle.id, selection == _clear ? null : selection);
      ref.invalidate(vehicleProvider(vehicle.id));
      ref.invalidate(fleetVisibleVehiclesProvider);
      AppSnackBar.successOn(
        messenger,
        selection == _clear ? 'Driver removed' : 'Driver assigned',
      );
    } catch (e) {
      AppSnackBar.errorOn(messenger, 'Could not assign: $e');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(fleetAssignableMembersProvider);

    return members.when(
      loading: () => const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => IconButton(
        tooltip: 'Retry loading team members',
        icon: const Icon(Icons.refresh),
        onPressed: () => ref.invalidate(fleetAssignableMembersProvider),
      ),
      data: (list) => PopupMenuButton<String>(
        tooltip: 'Assign driver',
        icon: const Icon(Icons.person_add_alt_1_outlined),
        onSelected: (value) => _assign(context, ref, value),
        itemBuilder: (_) => [
          for (final member in list)
            CheckedPopupMenuItem<String>(
              value: member.userId,
              checked: member.userId == vehicle.assignedToUserId,
              child: Text(member.displayName),
            ),
          if (vehicle.isAssigned) ...[
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: _clear,
              child: Text('Unassign driver'),
            ),
          ],
          if (list.isEmpty)
            const PopupMenuItem<String>(
              enabled: false,
              value: '',
              child: Text('No active team members'),
            ),
        ],
      ),
    );
  }
}

/// Weekly and monthly walk-arounds: what is due, start one, recent history.
class _InspectionsCard extends ConsumerWidget {
  const _InspectionsCard({required this.vehicle});

  final VehicleEntity vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final history = ref.watch(vehicleInspectionsProvider(vehicle.id));

    Widget cadenceRow(
      InspectionCadence cadence,
      List<VehicleInspection> list,
    ) {
      final status = InspectionStatus.compute(cadence, list);
      final daily = cadence == InspectionCadence.daily;
      final (text, color) = switch (status.state) {
        InspectionDueState.never => ('Not done yet', theme.colorScheme.error),
        InspectionDueState.overdue when daily => (
            'Not done today - required before taking the vehicle',
            theme.colorScheme.error
          ),
        InspectionDueState.ok when daily => (
            'Done today',
            theme.colorScheme.onSurfaceVariant
          ),
        InspectionDueState.overdue => (
            'Overdue – was due ${formatShortDate(status.dueAt!)}',
            theme.colorScheme.error
          ),
        InspectionDueState.dueSoon => (
            'Due ${formatShortDate(status.dueAt!)}',
            theme.colorScheme.tertiary
          ),
        InspectionDueState.ok => (
            'Next due ${formatShortDate(status.dueAt!)}',
            theme.colorScheme.onSurfaceVariant
          ),
      };
      return ListTile(
        dense: true,
        title: Text('${cadence.label} inspection'),
        subtitle: Text(text, style: TextStyle(color: color)),
        trailing: FilledButton.tonal(
          onPressed: () => context.push(
            '${RoutePaths.fleetInspectionNew.replaceFirst(':id', vehicle.id)}'
            '?cadence=${cadence.name}',
          ),
          child: const Text('Start'),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Icon(Icons.fact_check_outlined,
                color: theme.colorScheme.onSurfaceVariant),
            title: Text('Vehicle inspections', style: theme.textTheme.titleSmall),
          ),
          history.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(minHeight: 2),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text('Could not load inspections. $e',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.error)),
            ),
            data: (list) => Column(
              children: [
                cadenceRow(InspectionCadence.daily, list),
                cadenceRow(InspectionCadence.weekly, list),
                cadenceRow(InspectionCadence.monthly, list),
                if (list.isNotEmpty) const Divider(height: 1),
                for (final i in list.take(5))
                  ListTile(
                    dense: true,
                    onTap: () => showVehicleInspectionDetail(context, i),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        PendingUploadBadge(
                            table: kVehicleInspectionsTable, recordId: i.id),
                        const Icon(Icons.chevron_right, size: 18),
                      ],
                    ),
                    leading: Icon(
                      i.hasIssues
                          ? Icons.warning_amber_outlined
                          : Icons.check_circle_outline,
                      size: 20,
                      color: i.hasIssues
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    title: Text(
                      '${i.cadence.label} · ${formatShortDate(i.inspectedAt)}',
                    ),
                    subtitle: Text(
                      [
                        if (i.inspectorName.isNotEmpty) i.inspectorName,
                        if (i.odometer > 0) '${i.odometer} mi',
                        i.hasIssues ? '${i.issueCount} flagged' : 'No issues',
                      ].join('  ·  '),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ],
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
                  : 'Last checked ${formatShortDate(vehicle.lastCheckAt!.toLocal())}',
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
                'Could not load history. $error',
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
          '${check.odometer} mi',
          if (since != null) '$since mi since service',
          if (check.brakeStatus.needsFollowUp)
            'Brakes: ${check.brakeStatus.label}',
          if (check.batteryStatus.needsFollowUp)
            'Battery: ${check.batteryStatus.label}',
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



/// Saved PDF reports for this vehicle. Open and share reuse the document
/// library's actions.
class _DocumentsCard extends ConsumerWidget {
  const _DocumentsCard({required this.vehicle});

  final VehicleEntity vehicle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final docs = ref.watch(vehicleDocumentsProvider(vehicle.id));
    final theme = Theme.of(context);

    return docs.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => EmptyState.error(
        message: 'Could not load documents: $error',
        action: FilledButton.tonal(
          onPressed: () => ref.invalidate(vehicleDocumentsProvider(vehicle.id)),
          child: const Text('Retry'),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return const EmptyState(
            icon: Icons.folder_open,
            title: 'No saved PDFs',
            message: 'Use Generate PDF at the top of this page. Saved vehicle '
                'reports appear here.',
          );
        }
        return Column(
          children: [
            for (final doc in list)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: Text(
                    doc.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${doc.sizeLabel}  ·  ${formatShortDate(doc.modified)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  onTap: () => ref.read(documentActionsProvider).open(context, doc),
                  trailing: IconButton(
                    tooltip: 'Share',
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () async {
                      final ok = await ref.read(documentActionsProvider).share(context, doc);
                      if (!ok) ref.invalidate(vehicleDocumentsProvider(vehicle.id));
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
