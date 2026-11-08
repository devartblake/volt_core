import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/action_runner.dart';
import '../../../../shared/widgets/lazy_head_list.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/presenter/controllers/auth_controller.dart';
import '../../domain/readiness_export_data.dart';
import '../../domain/readiness_models.dart';
import '../../domain/readiness_rules.dart';
import '../../domain/readiness_summary.dart';
import '../readiness_providers.dart';
import '../readiness_services.dart';
import '../widgets/readiness_bulk.dart';
import '../widgets/readiness_filters.dart';
import '../widgets/readiness_notices.dart';
import '../widgets/readiness_overview.dart';
import '../widgets/readiness_segments.dart';
import '../widgets/readiness_settings_sheet.dart';
import '../widgets/readiness_unit_card.dart';
import '../widgets/readiness_unit_detail.dart';

/// Fleet readiness: every generator, whether it is ready, due soon, needs
/// attention or is not ready, and why. See docs/fleet_readiness.md.
class ReadinessPage extends ConsumerStatefulWidget {
  const ReadinessPage({super.key, this.initialStatus});

  /// A [ReadinessStatus] name from the route (`?status=notReady`).
  final String? initialStatus;

  @override
  ConsumerState<ReadinessPage> createState() => _ReadinessPageState();
}

class _ReadinessPageState extends ConsumerState<ReadinessPage> {
  ReadinessSegment _segment = ReadinessSegment.units;
  bool _selecting = false;
  final Set<String> _selected = {};
  String? _openKey;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _applyInitialStatus();
  }

  @override
  void didUpdateWidget(ReadinessPage old) {
    super.didUpdateWidget(old);
    if (old.initialStatus != widget.initialStatus) _applyInitialStatus();
  }

  void _applyInitialStatus() {
    final name = widget.initialStatus;
    if (name == null) return;
    final match = ReadinessStatus.values.where((s) => s.name == name);
    if (match.isEmpty) return;
    // After the first frame: providers must not change while building.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(readinessFilterProvider.notifier).state =
          ReadinessFilter(statuses: {match.first});
    });
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    // Maintenance is read straight from Hive and is not observed.
    ref.invalidate(readinessInputsProvider);
    try {
      await ref.read(readinessReportProvider.future);
    } catch (_) {
      // The error banner shows it.
    }
    if (mounted) setState(() => _refreshing = false);
  }

  void _toggleStatus(ReadinessStatus st) {
    final f = ref.read(readinessFilterProvider);
    final next = {...f.statuses};
    next.contains(st) ? next.remove(st) : next.add(st);
    ref.read(readinessFilterProvider.notifier).state = f.copyWith(statuses: next);
  }

  void _seeAllNotReady() {
    final f = ref.read(readinessFilterProvider);
    ref.read(readinessFilterProvider.notifier).state =
        f.copyWith(statuses: {ReadinessStatus.notReady});
    setState(() => _segment = ReadinessSegment.units);
  }

  void _selectWeek(DateTime? week) {
    final f = ref.read(readinessFilterProvider);
    final notifier = ref.read(readinessFilterProvider.notifier);
    if (week == null) {
      final on = f.dueWindow == ReadinessDueWindow.overdue;
      notifier.state = on
          ? f.copyWith(clearDueWindow: true)
          : f.copyWith(dueWindow: ReadinessDueWindow.overdue, clearDueWeek: true);
    } else {
      final on = f.dueWeekStart == week;
      notifier.state = on
          ? f.copyWith(clearDueWeek: true)
          : f.copyWith(dueWeekStart: week, clearDueWindow: true);
    }
    setState(() => _segment = ReadinessSegment.units);
  }

  void _open(ReadinessUnit u, DateTime now, {required bool pane}) {
    if (_selecting) return _toggleSelected(u);
    if (pane) {
      setState(() => _openKey = u.key);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 720),
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.92,
        child: ReadinessUnitDetail(
          unit: u,
          now: now,
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }

  void _toggleSelected(ReadinessUnit u) => setState(() {
        _selected.contains(u.key) ? _selected.remove(u.key) : _selected.add(u.key);
      });

  void _endSelection() => setState(() {
        _selecting = false;
        _selected.clear();
      });

  List<ReadinessUnit> _selectedUnits(List<ReadinessUnit> all) =>
      [for (final u in all) if (_selected.contains(u.key)) u];

  Future<void> _exportCsv(List<ReadinessUnit> units) {
    final exporter = ref.read(readinessExporterProvider);
    return runUserAction(
      context,
      label: 'export the CSV',
      action: () => exporter.shareCsv(units),
    );
  }

  Future<void> _exportPdf(ReadinessExportData data) {
    final exporter = ref.read(readinessExporterProvider);
    return runUserAction(
      context,
      label: 'create the PDF report',
      busyMessage: 'Building the report...',
      successMessage: 'Report saved in Documents',
      action: () => exporter.sharePdf(data),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authStateProvider).currentRole;
    final canSchedule = canScheduleReadiness(role);
    final report = ref.watch(readinessReportProvider);
    final filtered = ref.watch(filteredReadinessUnitsProvider).value ?? const [];
    final filter = ref.watch(readinessFilterProvider);

    final data = report.value;
    final all = data?.units ?? const <ReadinessUnit>[];
    final now = data?.now ?? DateTime.now();
    final summary = data == null ? ReadinessSummary.empty : summarizeReadiness(all, now);
    final exportUnits = _selecting && _selected.isNotEmpty ? _selectedUnits(all) : filtered;
    final exportData = ReadinessExportData(
      units: exportUnits,
      summary: summary,
      asOf: now,
      filtered: exportUnits.length != all.length,
    );
    final wideScreen = MediaQuery.sizeOf(context).width >= AppBreakpoints.expanded;

    return AppPage(
      title: 'Generator Fleet Readiness',
      maxContentWidth: wideScreen ? 1400 : kDefaultMaxContentWidth,
      actions: [
        if (data != null && all.isNotEmpty) ...[
          IconButton(
            key: const Key('select-button'),
            tooltip: _selecting ? 'Stop selecting' : 'Select units',
            icon: Icon(_selecting ? Icons.close : Icons.checklist),
            onPressed: () => _selecting
                ? _endSelection()
                : setState(() => _selecting = true),
          ),
          PopupMenuButton<String>(
            key: const Key('export-menu'),
            tooltip: 'Export',
            icon: const Icon(Icons.ios_share),
            onSelected: (v) => v == 'csv' ? _exportCsv(exportData.units) : _exportPdf(exportData),
            itemBuilder: (_) {
              final n = exportData.units.length;
              final noun = n == 1 ? 'unit' : 'units';
              return [
                PopupMenuItem(value: 'csv', child: Text('Export CSV ($n $noun)')),
                PopupMenuItem(value: 'pdf', child: Text('Export PDF report ($n $noun)')),
              ];
            },
          ),
        ],
        if (canEditReadinessConfig(role))
          IconButton(
            key: const Key('readiness-settings'),
            tooltip: 'Generator fleet readiness settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => showReadinessSettingsSheet(context),
          ),
      ],
      bottomBar: _selecting
          ? ReadinessSelectionBar(
              count: _selected.length,
              canSchedule: canSchedule,
              onSchedule: () => runBulkSchedule(context, ref, _selectedUnits(all), now),
              onExport: () => _exportCsv(_selectedUnits(all)),
              onSelectOverdue: () => setState(() {
                _selected
                  ..clear()
                  ..addAll([for (final u in all) if (u.isOverdue) u.key]);
              }),
              onDone: _endSelection,
            )
          : null,
      body: _body(report, all, filtered, summary, now, filter, wideScreen),
    );
  }

  Widget _body(
    AsyncValue<ReadinessReport> report,
    List<ReadinessUnit> all,
    List<ReadinessUnit> filtered,
    ReadinessSummary summary,
    DateTime now,
    ReadinessFilter filter,
    bool wideScreen,
  ) {
    final data = report.value;
    if (data == null) {
      if (report.hasError) {
        return EmptyState.error(
          title: 'Could not load generator fleet readiness',
          message: 'Check your connection and try again.',
          action: FilledButton(onPressed: _refresh, child: const Text('Retry')),
        );
      }
      return const SkeletonList(count: 6, itemHeight: 120);
    }
    if (all.isEmpty) {
      return ListView(children: [
        if (report.hasError) ReadinessErrorBanner(onRetry: _refresh),
        const EmptyState(
          icon: Icons.electrical_services_outlined,
          title: 'No generators yet',
          message: 'Generator fleet readiness is worked out from inspections and '
              'registered generators. Inspect a generator, or add one under '
              'Equipment, and it will show up here.',
        ),
      ]);
    }

    return LayoutBuilder(builder: (context, c) {
      final pane = c.maxWidth >= AppBreakpoints.expanded;
      final list = _list(report, all, filtered, summary, now, filter, pane, c.maxWidth);
      if (!pane) return list;
      final open = _openKey == null
          ? null
          : all.where((u) => u.key == _openKey).firstOrNull;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: list),
          VerticalDivider(width: 1, color: Theme.of(context).colorScheme.outlineVariant),
          SizedBox(
            width: 440,
            child: open == null
                ? const EmptyState(
                    icon: Icons.touch_app_outlined,
                    title: 'Select a generator',
                    message: 'Pick a unit to see why it has its status, its '
                        'history and what you can do about it.',
                  )
                : ReadinessUnitDetail(key: ValueKey(open.key), unit: open, now: now),
          ),
        ],
      );
    });
  }

  Widget _list(
    AsyncValue<ReadinessReport> report,
    List<ReadinessUnit> all,
    List<ReadinessUnit> filtered,
    ReadinessSummary summary,
    DateTime now,
    ReadinessFilter filter,
    bool pane,
    double width,
  ) {
    final compact = width < AppBreakpoints.medium;
    final followUps = filtered.where((u) => u.hasFollowUps).length;
    final parts = filtered.where((u) => u.partsShortCount > 0).length;

    Widget card(ReadinessUnit u) => ReadinessUnitCard(
          key: ValueKey('unit-${u.key}'),
          unit: u,
          now: now,
          selecting: _selecting,
          selected: _selected.contains(u.key),
          highlighted: pane && _openKey == u.key,
          onTap: () => _open(u, now, pane: pane),
          onLongPress: () => setState(() {
            _selecting = true;
            _selected.add(u.key);
          }),
        );

    final rows = switch (_segment) {
      ReadinessSegment.units => <ReadinessRow>[for (final u in filtered) (_) => card(u)],
      ReadinessSegment.calendar => calendarRows(filtered, now, card),
      ReadinessSegment.followUps =>
        followUpRows(filtered, now, (u) => _open(u, now, pane: pane)),
      ReadinessSegment.parts => partsRows(filtered, (u) => _open(u, now, pane: pane)),
    };

    final gutter = AppSpacing.gutter(AppBreakpoints.of(width));
    return RefreshIndicator(
      onRefresh: _refresh,
      child: LazyHeadList(
        padding: EdgeInsets.fromLTRB(gutter, AppSpacing.sm, gutter, AppSpacing.huge * 2),
        head: [
          if (report.hasError) ReadinessErrorBanner(onRetry: _refresh),
          ReadinessUnmatchedNote(unmatched: report.requireValue.unmatched),
          ReadinessOverview(
            summary: summary,
            now: now,
            filter: filter,
            refreshing: _refreshing || report.isLoading,
            onRefresh: _refresh,
            onToggleStatus: _toggleStatus,
            units: all,
            dueSoonDays: report.requireValue.config.dueSoonDays,
            onSeeAllNotReady: _seeAllNotReady,
            onSelectWeek: _selectWeek,
            onOpenUnit: (u) => _open(u, now, pane: pane),
          ),
          const SizedBox(height: AppSpacing.md),
          ReadinessFilterBar(units: all, compact: compact),
          const SizedBox(height: AppSpacing.sm),
          ReadinessSegmentSelector(
            selected: _segment,
            onChanged: (s) => setState(() => _segment = s),
            followUpUnits: followUps,
            partsUnits: parts,
            compact: compact,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              filtered.length == all.length
                  ? '${all.length} ${all.length == 1 ? 'unit' : 'units'}'
                  : 'Showing ${filtered.length} of ${all.length} units',
              key: const Key('result-count'),
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        ],
        rowCount: rows.isEmpty ? 1 : rows.length,
        rowBuilder: (context, i) {
          if (rows.isEmpty) return _noRows(filter, filtered.isEmpty);
          return rows[i](context);
        },
      ),
    );
  }

  Widget _noRows(ReadinessFilter filter, bool nothingMatches) {
    if (nothingMatches) {
      return EmptyState(
        icon: Icons.filter_alt_off_outlined,
        title: 'No units match these filters',
        message: 'Try removing a filter or searching for something else.',
        compact: true,
        action: FilledButton(
          key: const Key('empty-clear-filters'),
          onPressed: () =>
              ref.read(readinessFilterProvider.notifier).state = const ReadinessFilter(),
          child: const Text('Clear filters'),
        ),
      );
    }
    return switch (_segment) {
      ReadinessSegment.followUps => const EmptyState(
          icon: Icons.task_alt_outlined,
          title: 'No open follow-ups',
          message: 'Maintenance records that ask for a follow-up appear here.',
          compact: true,
        ),
      ReadinessSegment.parts => const EmptyState(
          icon: Icons.inventory_2_outlined,
          title: 'No parts short',
          message: 'Every unit has the parts its next job needs.',
          compact: true,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}
