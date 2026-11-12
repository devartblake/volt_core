import '../../../../core/theme/status_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../shared/widgets/pending_upload_badge.dart';
import '../../infra/mappers/vehicle_inspection_supabase_mapper.dart' show kVehicleInspectionsTable;
import '../../../inspections/presenter/inspection_date_filter.dart';
import '../../../inspections/presenter/widgets/inspection_date_filter_bar.dart';
import '../../domain/entities/vehicle_entity.dart';
import '../../domain/entities/vehicle_inspection.dart';
import '../../infra/repositories/vehicle_inspection_repository.dart';
import '../fleet_providers.dart';
import '../widgets/vehicle_inspection_detail_sheet.dart';

/// Every vehicle's inspections in one place, each vehicle with its own log.
///
/// Uses the same date filter as the All Inspections screen (All, Today, This
/// week, This month, a picked date, stepping by day, week or month) and adds a
/// filter for daily, weekly or monthly. Only the vehicles the signed-in person
/// may see are listed, so a technician sees their own vehicle's log.
class VehicleInspectionLogPage extends ConsumerStatefulWidget {
  const VehicleInspectionLogPage({super.key});

  @override
  ConsumerState<VehicleInspectionLogPage> createState() =>
      _VehicleInspectionLogPageState();
}

class _VehicleInspectionLogPageState
    extends ConsumerState<VehicleInspectionLogPage> {
  InspectionDateFilter _filter = const InspectionDateFilter.all();
  InspectionCadence? _cadence;

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(fleetVisibleVehiclesProvider);
    final inspections = ref.watch(allVehicleInspectionsProvider);

    return AppPage(
      title: 'Inspection Log',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: () {
            ref.invalidate(fleetVisibleVehiclesProvider);
            ref.invalidate(allVehicleInspectionsProvider);
          },
        ),
      ],
      body: vehicles.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState.error(
          message: '$e',
          action: FilledButton.tonal(
            onPressed: () => ref.invalidate(fleetVisibleVehiclesProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (vehicleList) => inspections.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState.error(
            message: '$e',
            action: FilledButton.tonal(
              onPressed: () => ref.invalidate(allVehicleInspectionsProvider),
              child: const Text('Retry'),
            ),
          ),
          data: (all) => _buildBody(context, vehicleList, all),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    List<VehicleEntity> vehicles,
    List<VehicleInspection> all,
  ) {
    if (vehicles.isEmpty) {
      return const EmptyState(
        icon: Icons.local_shipping_outlined,
        title: 'No vehicles',
        message: 'Vehicles you can see will each get an inspection log here.',
      );
    }

    final visibleIds = {for (final v in vehicles) v.id};
    final mine = all.where((i) => visibleIds.contains(i.vehicleId)).toList();

    // The log for each vehicle, after the date and type filters.
    final logs = <String, List<VehicleInspection>>{
      for (final v in vehicles)
        v.id: _filter.applyBy<VehicleInspection>(
          mine.where((i) =>
              i.vehicleId == v.id && (_cadence == null || i.cadence == _cadence)),
          (i) => i.inspectedAt,
        ),
    };
    final shown = logs.values.fold<int>(0, (sum, l) => sum + l.length);
    final total = _cadence == null
        ? mine.length
        : mine.where((i) => i.cadence == _cadence).length;

    return Column(
      children: [
        InspectionDateFilterBar(
          filter: _filter,
          shown: shown,
          total: total,
          onChanged: (f) => setState(() => _filter = f),
        ),
        _buildCadenceFilter(context),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
            children: [
              for (final v in vehicles)
                _VehicleLog(
                  key: ValueKey('${v.id}|${_filter.label}|${_cadence?.name}'),
                  vehicle: v,
                  entries: logs[v.id]!,
                  allForVehicle: mine.where((i) => i.vehicleId == v.id).toList(),
                  filter: _filter,
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCadenceFilter(BuildContext context) {
    final theme = Theme.of(context);

    Widget chip(String label, InspectionCadence? value) => ChoiceChip(
          label: Text(
            label,
            style: TextStyle(
              color: _cadence == value
                  ? theme.colorScheme.onSecondaryContainer
                  : theme.colorScheme.onSurface,
              fontWeight:
                  _cadence == value ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          selected: _cadence == value,
          onSelected: (_) => setState(() => _cadence = value),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text('Type', style: theme.textTheme.labelMedium),
          chip('All', null),
          for (final c in InspectionCadence.values) chip(c.label, c),
        ],
      ),
    );
  }
}

/// One vehicle's own log: a header with its status, then its inspections
/// under a heading for each day.
class _VehicleLog extends StatelessWidget {
  const _VehicleLog({
    super.key,
    required this.vehicle,
    required this.entries,
    required this.allForVehicle,
    required this.filter,
  });

  final VehicleEntity vehicle;

  /// Entries that pass the current filters, newest first.
  final List<VehicleInspection> entries;

  /// Everything recorded for this vehicle, for the "today" status.
  final List<VehicleInspection> allForVehicle;

  final InspectionDateFilter filter;

  static String _time(DateTime d) {
    final local = d.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groups = filter.groupByDay<VehicleInspection>(
      entries,
      (i) => i.inspectedAt,
    );
    final flagged = entries.where((i) => i.hasIssues).length;
    final dailyStatus = InspectionStatus.compute(
      InspectionCadence.daily,
      allForVehicle,
    );
    final dailyDone = dailyStatus.state == InspectionDueState.ok;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        // No divider lines around the tile's own edges.
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: entries.isNotEmpty,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.only(bottom: 8),
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(Icons.local_shipping_outlined,
                color: theme.colorScheme.onPrimaryContainer),
          ),
          title: Text(
            vehicle.displayTitle,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _Pill(
                  entries.length == 1 ? '1 inspection' : '${entries.length} inspections',
                  theme.colorScheme.secondaryContainer,
                  theme.colorScheme.onSecondaryContainer,
                ),
                if (flagged > 0)
                  _Pill('$flagged flagged', theme.colorScheme.errorContainer,
                      theme.colorScheme.onErrorContainer),
                _Pill(
                  dailyDone ? 'Daily done today' : 'Daily not done today',
                  dailyDone
                      ? theme.status.successContainer
                      : theme.colorScheme.errorContainer,
                  dailyDone
                      ? theme.status.success
                      : theme.colorScheme.onErrorContainer,
                ),
              ],
            ),
          ),
          trailing: IconButton(
            tooltip: 'Open vehicle',
            icon: const Icon(Icons.open_in_new),
            onPressed: () => context.push(
              RoutePaths.fleetDetail.replaceFirst(':id', vehicle.id),
            ),
          ),
          children: [
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'No inspections for ${filter.label.toLowerCase()}.',
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              )
            else
              for (final group in groups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          group.title,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${group.items.length}',
                          style: theme.textTheme.bodySmall),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Divider(color: theme.colorScheme.outlineVariant),
                      ),
                    ],
                  ),
                ),
                for (final i in group.items) _entry(context, theme, i),
              ],
          ],
        ),
      ),
    );
  }

  Widget _entry(BuildContext context, ThemeData theme, VehicleInspection i) {
    final people = [
      if (i.driverName.isNotEmpty) 'Driver: ${i.driverName}',
      if (i.dispatcherName.isNotEmpty) 'Dispatcher: ${i.dispatcherName}',
      if (i.driverName.isEmpty && i.dispatcherName.isEmpty && i.inspectorName.isNotEmpty)
        i.inspectorName,
    ].join('  |  ');

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      onTap: () => showVehicleInspectionDetail(context, i),
      leading: Icon(
        i.hasIssues
            ? Icons.warning_amber_outlined
            : Icons.check_circle_outline,
        color: i.hasIssues ? theme.colorScheme.error : theme.status.success,
      ),
      title: Row(
        children: [
          _Pill(
            i.cadence.label,
            theme.colorScheme.tertiaryContainer,
            theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 8),
          Text(_time(i.inspectedAt),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          if (i.odometer > 0) ...[
            const SizedBox(width: 8),
            Text('${i.odometer} mi', style: theme.textTheme.bodySmall),
          ],
        ],
      ),
      subtitle: Text(
        [
          if (people.isNotEmpty) people,
          i.hasIssues ? '${i.issueCount} flagged' : 'No issues',
        ].join('  |  '),
        style: theme.textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PendingUploadBadge(
              table: kVehicleInspectionsTable, recordId: i.id),
          if (i.isSigned)
            Tooltip(
              message: 'Signed by both',
              child: Icon(Icons.verified_outlined,
                  size: 18, color: theme.colorScheme.primary),
            ),
          const Icon(Icons.chevron_right, size: 18),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text, this.background, this.foreground);

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
      ),
    );
  }
}
