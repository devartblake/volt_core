import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../domain/entities/inspection_entity.dart';
import '../../domain/inspection_filter_preset.dart';
import '../../infra/repositories/inspection_repository.dart';
import '../../infra/repositories/inspection_repository_impl.dart';
import '../controllers/inspection_list_prefs.dart';
import '../widgets/inspection_filter_presets_bar.dart';
import '../widgets/finish_sheet.dart';
import '../controllers/inspection_list_controller.dart';
import '../inspection_date_filter.dart';
import '../widgets/inspection_date_filter_bar.dart';
import '../controllers/app_badges_controller.dart';
import '../controllers/user_profile_controller.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../work_orders/presenter/inspection_maintenance_scheduler.dart';

class InspectionListPage extends ConsumerStatefulWidget {
  final String? filterStatus;
  const InspectionListPage({super.key, this.filterStatus});

  @override
  ConsumerState<InspectionListPage> createState() =>
      _InspectionListPageState();
}

class _InspectionListPageState
    extends ConsumerState<InspectionListPage> {
  /// Dates, grade and text the list is narrowed to. Starts on everything.
  InspectionListFilter _filter = const InspectionListFilter();

  List<InspectionFilterPreset> _saved = const [];
  InspectionDensity _density = InspectionDensity.comfortable;

  /// How long the Undo snackbar (and the pending soft delete) lasts.
  static const _undoWindow = Duration(seconds: 6);

  // Swiped away: hidden now, deleted (and the delete queued for sync) when the
  // undo window ends. Undo just un-hides, so nothing was ever removed or
  // queued and there is nothing to re-queue.
  final Map<String, Timer> _pending = {};

  // Held in a field: `ref` is unsafe to use inside dispose().
  late final InspectionRepository _repo;

  bool get _compact => _density == InspectionDensity.compact;

  @override
  void dispose() {
    // Commit anything still inside its undo window.
    final ids = _pending.keys.toList();
    for (final t in _pending.values) {
      t.cancel();
    }
    _pending.clear();
    for (final id in ids) {
      unawaited(_repo.deleteInspection(id));
    }
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _repo = ref.read(inspectionRepositoryProvider);
    final prefs = ref.read(inspectionListPrefsProvider);
    _saved = prefs.loadPresets();
    _density = prefs.loadDensity();
    // Load inspections once when the page mounts
    Future.microtask(() {
      ref
          .read(inspectionListControllerProvider.notifier)
          .loadInspections();
    });
  }

  @override
  Widget build(BuildContext context) {
    final badges = ref.watch(appBadgesProvider);
    final state = ref.watch(inspectionListControllerProvider);
    final theme = Theme.of(context);

    // Watch providers for reactive updates
    ref.watch(currentTenantProvider);

    // Apply filter if provided
    final allItems = state.items;
    final visibleItems =
        allItems.where((i) => !_pending.containsKey(i.id)).toList();
    final statusItems = widget.filterStatus != null
        ? visibleItems.where((i) {
            final status = widget.filterStatus!.toLowerCase();
            // 'pending' = inspections that need attention (Amber/Red grade)
            if (status == 'pending') {
              final grade = i.siteGrade.toLowerCase();
              return grade == 'amber' || grade == 'red';
            }
            return i.siteGrade.toLowerCase() == status;
          }).toList()
        : visibleItems;

    // Then the date filter: newest first, under month or day headings.
    final items = _filter.apply(statusItems);
    final rows = <Object>[
      for (final group in _filter.date.group(items)) ...[group, ...group.items],
    ];

    final header = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStatsSection(context, theme, badges),
        InspectionFilterPresetsBar(
          filter: _filter,
          onChanged: (f) => setState(() => _filter = f),
          presets: [...InspectionFilterPreset.builtIns, ..._saved],
          onSavePreset: _savePreset,
          onRenamePreset: _renamePreset,
          onDeletePreset: _deletePreset,
          density: _density,
          onDensityChanged: _setDensity,
        ),
        InspectionDateFilterBar(
          filter: _filter.date,
          shown: items.length,
          total: statusItems.length,
          onChanged: (f) =>
              setState(() => _filter = _filter.copyWith(date: f)),
        ),
      ],
    );

    return AppPage(
      title: '',
      titleWidget: Text(widget.filterStatus == 'pending'
            ? 'Pending Inspections'
            : 'Inspections'),
      actions: [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Edit inspection',
          onPressed: items.isEmpty
              ? null
              : () => _selectInspectionToEdit(context, items),
        ),
      ],
      body: Column(
        children: [
          if (state.isLoading && statusItems.isEmpty)
            const Expanded(
              child: LoadingIndicator(),
            )
          else if (statusItems.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment:
                  MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.description_outlined,
                      size: 80,
                      color: theme.colorScheme.primary
                          .withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No inspections yet',
                      style: theme
                          .textTheme.titleLarge
                          ?.copyWith(
                        color: theme
                            .colorScheme.onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the + button to create your first inspection',
                      style: theme
                          .textTheme.bodyMedium
                          ?.copyWith(
                        color: theme
                            .colorScheme.onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (items.isEmpty)
            Expanded(
              child: ListView(
                children: [header, _buildNoResults(theme)],
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                // Row 0 is the stats and filter header, so it scrolls away
                // instead of eating the screen at large text sizes.
                itemCount: rows.length + 1,
                itemBuilder: (_, i) {
                  if (i == 0) return header;
                  final row = rows[i - 1];
                  if (row is InspectionGroup) {
                    return _groupHeader(theme, row);
                  }
                  return _modernTile(context, theme, row as InspectionEntity);
                },
              ),
            ),
        ],
      ),
      fab: FloatingActionButton.extended(
        onPressed: () =>
            context.goNamed('inspection_new'),
        icon: const Icon(Icons.add),
        label: const Text('New Inspection'),
      ),
    );
  }

  // ---------------------------------------------------------------- filter

  Widget _groupHeader(ThemeData theme, InspectionGroup group) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
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
          Text(
            '${group.items.length}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(color: theme.colorScheme.outlineVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.event_busy_outlined,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              _filter.grades.isEmpty && _filter.query.trim().isEmpty
                  ? 'No inspections for ${_filter.date.label}'
                  : 'No inspections match these filters',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () =>
                  setState(() => _filter = const InspectionListFilter()),
              child: const Text('Clear filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection(
      BuildContext context,
      ThemeData theme,
      AppBadges badges,
      ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: StatCard(
              compact: true,
              icon: Icons.list_alt,
              label: 'Total',
              value: '${badges.totalInspections}',
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              compact: true,
              icon: Icons.pending_actions,
              label: 'Pending',
              value: '${badges.pendingInspections}',
              color: theme.status.info,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              compact: true,
              icon: Icons.warning_amber_rounded,
              label: 'Amber',
              value: '${badges.amberGradeInspections}',
              color: theme.status.warning,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: StatCard(
              compact: true,
              icon: Icons.error_outline,
              label: 'Red',
              value: '${badges.redGradeInspections}',
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  Widget _modernTile(
      BuildContext ctx,
      ThemeData theme,
      InspectionEntity ins,
      ) {
    final dateStr = ins.serviceDate
        .toIso8601String()
        .split('T')
        .first;

    final grade = ins.siteGrade;
    final address = ins.displayTitle;
    final siteCode = ins.siteCode;

    final card = Card(
      margin: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: _compact ? AppSpacing.xs : 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => GoRouter.of(ctx).goNamed(
          'inspection_detail',
          pathParameters: {'id': ins.id},
        ),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(_compact ? AppSpacing.sm : AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: _compact ? 36 : 48,
                height: _compact ? 36 : 48,
                decoration: BoxDecoration(
                  color: theme.gradeColor(grade, fallback: theme.colorScheme.primary)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.settings_input_antenna,
                  color: theme.gradeColor(grade, fallback: theme.colorScheme.primary),
                ),
              ),
              SizedBox(width: _compact ? AppSpacing.md : AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      address,
                      style: theme
                          .textTheme.titleMedium
                          ?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_compact)
                      Text(
                        [dateStr, if (siteCode.isNotEmpty) siteCode, if (grade.isNotEmpty) grade]
                            .join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    else ...[
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        InfoChip(
                          icon: Icons.calendar_today,
                          label: dateStr,
                        ),
                        if (siteCode.isNotEmpty)
                          InfoChip(
                            icon: Icons
                                .location_on_outlined,
                            label: siteCode,
                          ),
                        if (grade.isNotEmpty)
                          Container(
                            padding:
                            const EdgeInsets
                                .symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.gradeColor(grade,
                                  fallback: theme.colorScheme.primary)
                                  .withValues(alpha: 0.15),
                              borderRadius:
                              BorderRadius
                                  .circular(8),
                            ),
                            child: Text(
                              grade,
                              style: theme.textTheme
                                  .labelSmall
                                  ?.copyWith(
                                color: theme.gradeColor(grade,
                                    fallback: theme.colorScheme.primary),
                                fontWeight:
                                FontWeight.w600,
                              ),
                            ),
                          ),
                        InspectionFinishChip(inspection: ins),
                      ],
                    ),
                    ],
                  ],
                ),
              ),
              PopupMenuButton<_InspectionAction>(
                tooltip: 'Inspection actions',
                onSelected: (action) {
                  switch (action) {
                    case _InspectionAction.edit:
                      GoRouter.of(ctx).goNamed(
                        RouteNames.inspectionEdit,
                        pathParameters: {'id': ins.id},
                      );
                    case _InspectionAction.scheduleMaintenance:
                      scheduleMaintenanceFromInspection(ctx, ref, ins);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: _InspectionAction.edit,
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit inspection'),
                    ),
                  ),
                  PopupMenuItem(
                    value: _InspectionAction.scheduleMaintenance,
                    child: ListTile(
                      leading: Icon(Icons.build_circle_outlined),
                      title: Text('Schedule maintenance'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    final canDelete = ref.watch(inspectionCanDeleteProvider);
    final scheme = theme.colorScheme;

    Widget swipeBg(Alignment align, Color bg, Color fg, IconData icon,
            String label) =>
        Container(
          alignment: align,
          margin: EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: _compact ? AppSpacing.xs : 6),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.field),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: fg),
              Text(label,
                  style: theme.textTheme.labelSmall?.copyWith(color: fg)),
            ],
          ),
        );

    return Dismissible(
      key: ValueKey('inspection-${ins.id}'),
      direction: canDelete
          ? DismissDirection.horizontal
          : DismissDirection.startToEnd,
      background: swipeBg(Alignment.centerLeft, scheme.secondaryContainer,
          scheme.onSecondaryContainer, Icons.build_circle_outlined,
          'Schedule maintenance'),
      secondaryBackground: swipeBg(Alignment.centerRight,
          scheme.errorContainer, scheme.onErrorContainer,
          Icons.delete_outline, 'Delete'),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Quick action: runs, then the row springs back.
          unawaited(scheduleMaintenanceFromInspection(ctx, ref, ins));
          return false;
        }
        return true;
      },
      onDismissed: (_) => _softDelete(ins),
      child: card,
    );
  }

  // ------------------------------------------------------ presets / density

  void _savePreset(String name) {
    final preset = InspectionFilterPreset.fromFilter(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      filter: _filter,
    );
    _persistPresets([..._saved, preset]);
  }

  void _renamePreset(InspectionFilterPreset p, String name) {
    _persistPresets([
      for (final s in _saved) s.id == p.id ? s.copyWith(name: name) : s,
    ]);
  }

  void _deletePreset(InspectionFilterPreset p) {
    _persistPresets([
      for (final s in _saved)
        if (s.id != p.id) s,
    ]);
  }

  void _persistPresets(List<InspectionFilterPreset> next) {
    setState(() => _saved = next);
    unawaited(ref.read(inspectionListPrefsProvider).savePresets(next));
  }

  void _setDensity(InspectionDensity d) {
    setState(() => _density = d);
    unawaited(ref.read(inspectionListPrefsProvider).saveDensity(d));
  }

  // ----------------------------------------------------------- swipe delete

  /// Hides [ins] now and deletes it for real when the Undo window closes.
  void _softDelete(InspectionEntity ins) {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _pending[ins.id] = Timer(_undoWindow, () => _commitDelete(ins.id));
    });
    AppSnackBar.infoOn(
      messenger,
      '${ins.displayTitle} deleted',
      duration: _undoWindow,
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          _pending.remove(ins.id)?.cancel();
          if (mounted) setState(() {});
        },
      ),
    );
  }

  Future<void> _commitDelete(String id) async {
    if (_pending.remove(id) == null) return;
    try {
      await _repo.deleteInspection(id);
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Could not delete: $e');
    }
    if (mounted) {
      await ref
          .read(inspectionListControllerProvider.notifier)
          .loadInspections();
    }
  }

  Future<void> _selectInspectionToEdit(
    BuildContext context,
    List<InspectionEntity> items,
  ) async {
    final selected = await showModalBottomSheet<InspectionEntity>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Edit inspection'),
              subtitle: Text('Choose an inspection to edit'),
            ),
            for (final inspection in items)
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(inspection.displayTitle),
                subtitle: Text(
                  inspection.siteCode.isEmpty
                      ? inspection.serviceDate.toIso8601String().split('T').first
                      : inspection.siteCode,
                ),
                onTap: () => Navigator.of(sheetContext).pop(inspection),
              ),
          ],
        ),
      ),
    );

    if (selected != null && context.mounted) {
      GoRouter.of(context).goNamed(
        RouteNames.inspectionEdit,
        pathParameters: {'id': selected.id},
      );
    }
  }

}

enum _InspectionAction { edit, scheduleMaintenance }


