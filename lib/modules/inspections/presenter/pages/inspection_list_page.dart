import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/inspection_entity.dart';
import '../controllers/inspection_list_controller.dart';
import '../controllers/app_badges_controller.dart';
import '../controllers/user_profile_controller.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../schedule/presenter/pages/schedule_task_page.dart';
import '../../../schedule/presenter/widgets/dialogs/schedule_dialog.dart';

class InspectionListPage extends ConsumerStatefulWidget {
  final String? filterStatus;
  const InspectionListPage({super.key, this.filterStatus});

  @override
  ConsumerState<InspectionListPage> createState() =>
      _InspectionListPageState();
}

class _InspectionListPageState
    extends ConsumerState<InspectionListPage> {
  @override
  void initState() {
    super.initState();
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
    final items = widget.filterStatus != null
        ? allItems.where((i) {
            final status = widget.filterStatus!.toLowerCase();
            // 'pending' = inspections that need attention (Amber/Red grade)
            if (status == 'pending') {
              final grade = i.siteGrade.toLowerCase();
              return grade == 'amber' || grade == 'red';
            }
            return i.siteGrade.toLowerCase() == status;
          }).toList()
        : allItems;

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
          if (items.isNotEmpty)
            _buildStatsSection(context, theme, badges),

          if (state.isLoading && items.isEmpty)
            const Expanded(
              child: LoadingIndicator(),
            )
          else if (items.isEmpty)
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
          else
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                    vertical: 8),
                itemCount: items.length,
                itemBuilder: (_, i) =>
                    _modernTile(context, theme, items[i]),
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
            child: _StatCard(
              icon: Icons.list_alt,
              label: 'Total',
              count: badges.totalInspections,
              color: theme.colorScheme.primary,
              theme: theme,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.pending_actions,
              label: 'Pending',
              count: badges.pendingInspections,
              color: Colors.blue,
              theme: theme,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.warning_amber_rounded,
              label: 'Amber',
              count: badges.amberGradeInspections,
              color: theme.status.warning,
              theme: theme,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.error_outline,
              label: 'Red',
              count: badges.redGradeInspections,
              color: theme.colorScheme.error,
              theme: theme,
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

    return Card(
      margin: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 6),
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
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
              const SizedBox(width: 16),
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
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _InfoChip(
                          icon: Icons.calendar_today,
                          label: dateStr,
                          theme: theme,
                        ),
                        if (siteCode.isNotEmpty)
                          _InfoChip(
                            icon: Icons
                                .location_on_outlined,
                            label: siteCode,
                            theme: theme,
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
                      ],
                    ),
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
                      _scheduleMaintenance(ctx, ins);
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

  Future<void> _scheduleMaintenance(
    BuildContext context,
    InspectionEntity inspection,
  ) async {
    final scheduled = await showScheduleDialog(
      context: context,
      taskType: TaskType.maintenance,
      siteCode: inspection.siteCode,
      address: inspection.address,
      inspectionId: inspection.id,
      siteGrade: inspection.siteGrade,
    );
    if (scheduled == true && context.mounted) {
      AppSnackBar.success(context, 'Maintenance scheduled');
    }
  }

}

enum _InspectionAction { edit, scheduleMaintenance }

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ThemeData theme;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color:
            theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Modern stat card for displaying metrics
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final ThemeData theme;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$count',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme
                  .colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
