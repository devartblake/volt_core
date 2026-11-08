import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_roles.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/domain/user_role.dart';
import '../../../auth/presenter/controllers/auth_controller.dart';
import '../../../fleet/infra/repositories/vehicle_inspection_repository.dart';
import '../../../inspections/presenter/controllers/app_badges_controller.dart';
import '../../../inventory/presenter/movement_providers.dart' show jobsShortOfPartsProvider;
import '../../../inspections/presenter/controllers/inspection_list_controller.dart';
import '../../../readiness/domain/readiness_models.dart' show ReadinessStatus;
import '../../../readiness/domain/readiness_summary.dart' show ReadinessSummary;
import '../../../readiness/presenter/readiness_providers.dart';
import '../../../schedule/domain/entities/task_schedule_entity.dart';
import '../../../schedule/domain/schedule_view_logic.dart' show unassignedFilter;
import '../../../schedule/presenter/controllers/schedule_controller.dart';
import '../../../search/presenter/global_search.dart';
import '../../../work_orders/presenter/work_order_providers.dart';
import '../../../work_orders/presenter/work_order_workload.dart';
import '../../domain/dashboard_summary.dart';
import '../../domain/inspection_trend.dart';
import '../../domain/technician_day.dart';
import '../dashboard_providers.dart';
import '../widgets/dashboard_sections.dart';
import '../widgets/trend_sparkline.dart';

/// Role-aware home screen.
///
/// One screen that changes with who is signed in: a technician sees "their
/// day" (own jobs, own vehicle's daily check), a dispatcher sees what needs
/// assigning, a supervisor sees what needs review, an admin sees the whole
/// picture. Every block is built from the same few providers and tolerates any
/// of them being slow or failing.
class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  DateTime? _updatedAt;

  @override
  void initState() {
    super.initState();
    // Stamp "Updated" whenever the schedule finishes loading, including the
    // load that is already done by the time this page opens.
    ref.listenManual<AsyncValue<List<TaskScheduleEntity>>>(
      scheduleControllerProvider,
      (_, next) {
        if (next.hasValue && mounted) {
          setState(() => _updatedAt = DateTime.now());
        }
      },
      fireImmediately: true,
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(workOrderListProvider);
    ref.invalidate(allVehicleInspectionsProvider);
    ref.invalidate(dailyChecksDueProvider);
    ref.invalidate(dashboardWorkloadProvider);
    ref.read(inspectionListControllerProvider.notifier).loadInspections();
    await ref.read(scheduleControllerProvider.notifier).load();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final role = auth.currentRole;
    final audience = DashboardAudience.of(role);
    final schedule = ref.watch(scheduleControllerProvider);
    final tasks = schedule.hasValue ? schedule.requireValue : null;

    return AppPage(
      title: 'Dashboard',
      // The page has its own search bar.
      showSearch: false,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: _refresh,
        ),
      ],
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final gutter = AppSpacing.gutter(
              AppBreakpoints.of(constraints.maxWidth),
            );
            return ListView(
              // Always scrollable so pull-to-refresh works on short content.
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(gutter, 16, gutter, 32),
              children: [
                _Header(
                  name: auth.displayName,
                  audience: audience,
                  updatedAt: _updatedAt,
                ),
                const SizedBox(height: 16),
                DashboardSearchBar(onTap: () => showGlobalSearch(context)),
                const SizedBox(height: 20),
                if (tasks == null && schedule.isLoading)
                  const DashboardSkeleton()
                else ...[
                  if (schedule.hasError && tasks == null)
                    _LoadError(onRetry: _refresh),
                  _Body(
                    wide: wide,
                    audience: audience,
                    role: role,
                    tasks: tasks ?? const [],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.wide,
    required this.audience,
    required this.role,
    required this.tasks,
  });

  final bool wide;
  final DashboardAudience audience;
  final UserRole? role;
  final List<TaskScheduleEntity> tasks;

  bool _can(String routeName) =>
      role != null && RouteRoles.isAllowedByName(name: routeName, role: role!);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = DashboardSummary.fromTasks(tasks, now: DateTime.now());
    final workload = ref.watch(dashboardWorkloadProvider).asData?.value;
    final dailyDue = ref.watch(dailyChecksDueProvider).asData?.value;
    final badges = ref.watch(appBadgesProvider);
    // Technicians are not shown the fleet totals; skip the work for them.
    final readiness = audience == DashboardAudience.field
        ? null
        : ref.watch(readinessSummaryProvider).value;

    final attention = buildAttention(AttentionInputs(
      audience: audience,
      summary: summary,
      workload: workload,
      redGradeSites: badges.redGradeInspections,
      vehiclesNeedingDailyCheck: dailyDue,
      // Technicians are not told; skip the work of checking stock for them.
      jobsShortOfParts: audience == DashboardAudience.field
          ? 0
          : ref.watch(jobsShortOfPartsProvider).asData?.value ?? 0,
      generatorsNotReady: readiness?.count(ReadinessStatus.notReady) ?? 0,
      routes: AttentionRoutes(
        readinessNotReady: '${RoutePaths.readiness}?status=notReady',
        schedule: RoutePaths.schedule,
        jobs: RoutePaths.workOrders,
        inspections: RoutePaths.inspections,
        fleetLog: RoutePaths.fleetInspectionLog,
        shortages: RoutePaths.inventoryShortages,
      ),
    ));

    final stats = _stats(
      context,
      audience: audience,
      summary: summary,
      workload: workload,
      dailyDue: dailyDue,
      badges: badges,
      readiness: readiness,
      inspectionTrend: dailyCounts(
        ref.watch(inspectionListControllerProvider).items.map((i) => i.serviceDate),
        now: DateTime.now(),
      ),
    );
    final actions =
        _actionsFor(audience).where((a) => _can(a.routeName)).toList();

    void go(String route) => context.go(route);

    final showTeam = audience == DashboardAudience.dispatch ||
        audience == DashboardAudience.admin;
    Widget? teamCard;
    if (showTeam) {
      final techs = ref.watch(dashboardTechniciansProvider).asData?.value;
      teamCard = TechnicianDaysCard(
        days: buildTechnicianDays(
          tasks,
          now: DateTime.now(),
          names: techs?.names ?? const {},
          roster: techs?.roster ?? const [],
        ),
        onOpen: (d) => go(Uri(
          path: RoutePaths.schedule,
          queryParameters: {'technician': d.userId ?? unassignedFilter},
        ).toString()),
      );
    }

    final attentionCard = AttentionCard(items: attention, onOpen: go);
    final todayCard = TodayCard(
      summary: summary,
      onOpenSchedule: () => go(RoutePaths.schedule),
      onOpenTask: (t) => context.push('${RoutePaths.schedule}/detail/${t.id}'),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatGrid(stats: stats, onOpen: go),
        const SizedBox(height: 20),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: todayCard),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: attentionCard),
            ],
          )
        else ...[
          // Urgent first on a phone: what needs attention, then the day.
          attentionCard,
          const SizedBox(height: 16),
          todayCard,
        ],
        if (teamCard != null) ...[
          const SizedBox(height: 16),
          teamCard,
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Quick actions',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          QuickActionsGrid(actions: actions, onOpen: (a) => go(a.route)),
        ],
      ],
    );
  }
}

// ----------------------------------------------------------------- stats

class _Stat {
  const _Stat(
    this.label,
    this.value,
    this.icon,
    this.color,
    this.route, {
    this.subtitle,
    this.trend,
  });

  /// Daily counts for a sparkline under the label (oldest first).
  final List<int>? trend;

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String route;
  final String? subtitle;
}

List<_Stat> _stats(
  BuildContext context, {
  required DashboardAudience audience,
  required DashboardSummary summary,
  required WorkOrderWorkload? workload,
  required int? dailyDue,
  required AppBadges badges,
  ReadinessSummary? readiness,
  List<int>? inspectionTrend,
}) {
  final theme = Theme.of(context);
  final status = theme.status;
  final scheme = theme.colorScheme;

  // The tile's number is the sum of the sparkline's seven daily buckets, so the
  // two always agree (the older elapsed-time rule counted an extra edge day).
  final inspections7 = inspectionTrend == null
      ? badges.pendingInspections
      : inspectionTrend.fold<int>(0, (a, b) => a + b);

  final today = _Stat(
    'Today',
    '${summary.todayOpen}',
    Icons.today_outlined,
    scheme.primary,
    RoutePaths.schedule,
    subtitle: summary.todayDone > 0 ? '${summary.todayDone} done' : null,
  );
  final overdue = _Stat(
    'Overdue',
    '${summary.overdue.length}',
    Icons.warning_amber_rounded,
    summary.overdue.isEmpty ? status.success : scheme.error,
    RoutePaths.schedule,
  );
  final jobs = workload == null
      ? null
      : _Stat(
          audience == DashboardAudience.field ? 'My open jobs' : 'Open jobs',
          '${workload.open}',
          Icons.work_outline,
          status.info,
          RoutePaths.workOrders,
        );

  final fleet = readiness == null
      ? null
      : _Stat(
          'Fleet readiness',
          fleetReadinessValue(readiness.percentReady, readiness.total),
          Icons.verified_outlined,
          readiness.total == 0
              ? scheme.outline
              : readiness.percentReady >= 80
                  ? status.success
                  : readiness.percentReady >= 50
                      ? status.warning
                      : scheme.error,
          RoutePaths.readiness,
        );

  switch (audience) {
    case DashboardAudience.field:
      return [
        today,
        overdue,
        if (jobs != null) jobs,
        if (dailyDue != null)
          _Stat(
            'Daily check',
            dailyDue == 0 ? 'Done' : 'Due',
            Icons.local_shipping_outlined,
            dailyDue == 0 ? status.success : status.warning,
            RoutePaths.fleet,
          ),
      ];
    case DashboardAudience.dispatch:
      return [
        today,
        overdue,
        if (jobs != null) jobs,
        if (workload != null)
          _Stat(
            'Unassigned',
            '${workload.unassigned}',
            Icons.person_off_outlined,
            workload.unassigned == 0 ? status.success : status.warning,
            RoutePaths.workOrders,
          ),
        if (fleet != null) fleet,
      ];
    case DashboardAudience.review:
      return [
        today,
        overdue,
        _Stat('Red-grade sites', '${badges.redGradeInspections}',
            Icons.error_outline, scheme.error, RoutePaths.inspections),
        _Stat('Inspections, 7 days', '$inspections7',
            Icons.fact_check_outlined, status.info, RoutePaths.inspections,
            trend: inspectionTrend),
        if (fleet != null) fleet,
      ];
    case DashboardAudience.admin:
      return [
        today,
        overdue,
        if (jobs != null) jobs,
        _Stat('Inspections, 7 days', '$inspections7',
            Icons.fact_check_outlined, scheme.tertiary, RoutePaths.inspections,
            trend: inspectionTrend),
        if (fleet != null) fleet,
      ];
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats, required this.onOpen});

  final List<_Stat> stats;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns =
            constraints.maxWidth >= 700 ? stats.length.clamp(1, 4) : 2;
        final scale = MediaQuery.textScalerOf(context).scale(1.0);
        final extent = 136.0 * scale.clamp(1.0, 1.6) +
            (stats.any((s) => s.trend != null)
                ? TrendSparkline.extraHeight
                : 0);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: stats.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: extent,
          ),
          itemBuilder: (context, i) {
            final s = stats[i];
            return StatCard(
              compact: true,
              icon: s.icon,
              label:
                  s.subtitle == null ? s.label : '${s.label} - ${s.subtitle}',
              value: s.value,
              color: s.color,
              footerSemantics: s.trend == null
                  ? null
                  : trendSemanticLabel('Inspections', s.trend!),
              footer: s.trend == null
                  ? null
                  : TrendSparkline.inspections(counts: s.trend!, color: s.color),
              onTap: () => onOpen(s.route),
            );
          },
        );
      },
    );
  }
}

// --------------------------------------------------------------- actions

List<DashboardAction> _actionsFor(DashboardAudience audience) {
  const newInspection = DashboardAction(
    label: 'New inspection',
    icon: Icons.add_circle_outline,
    route: RoutePaths.inspectionNew,
    routeName: RouteNames.inspectionNew,
  );
  const newJob = DashboardAction(
    label: 'New job',
    icon: Icons.add_task_outlined,
    route: RoutePaths.workOrderNew,
    routeName: RouteNames.workOrderNew,
  );
  const newMaintenance = DashboardAction(
    label: 'New maintenance',
    icon: Icons.build_circle_outlined,
    route: RoutePaths.maintenanceNew,
    routeName: RouteNames.maintenanceNew,
  );
  const scheduleTask = DashboardAction(
    label: 'Schedule a task',
    icon: Icons.event_outlined,
    route: '${RoutePaths.schedule}/${RoutePaths.scheduleTask}',
    routeName: RouteNames.scheduleTask,
  );
  const vehicles = DashboardAction(
    label: 'Vehicles',
    icon: Icons.local_shipping_outlined,
    route: RoutePaths.fleet,
    routeName: RouteNames.fleet,
  );
  const inspections = DashboardAction(
    label: 'Inspections',
    icon: Icons.fact_check_outlined,
    route: RoutePaths.inspections,
    routeName: RouteNames.inspections,
  );
  const documents = DashboardAction(
    label: 'Documents',
    icon: Icons.folder_open_outlined,
    route: RoutePaths.documents,
    routeName: RouteNames.documents,
  );
  const workload = DashboardAction(
    label: 'My workload',
    icon: Icons.insights_outlined,
    route: RoutePaths.techDashboard,
    routeName: RouteNames.techDashboard,
  );
  const analytics = DashboardAction(
    label: 'Analytics',
    icon: Icons.query_stats_outlined,
    route: RoutePaths.analytics,
    routeName: RouteNames.analytics,
  );
  const admin = DashboardAction(
    label: 'Admin overview',
    icon: Icons.admin_panel_settings_outlined,
    route: RoutePaths.adminDashboard,
    routeName: RouteNames.adminDashboard,
  );

  return switch (audience) {
    DashboardAudience.field => [
        newInspection,
        vehicles,
        newMaintenance,
        workload,
        documents,
      ],
    DashboardAudience.dispatch => [
        newJob,
        scheduleTask,
        vehicles,
        newInspection,
        documents,
      ],
    DashboardAudience.review => [
        inspections,
        newInspection,
        analytics,
        documents,
      ],
    DashboardAudience.admin => [
        newInspection,
        newJob,
        newMaintenance,
        scheduleTask,
        analytics,
        admin,
      ],
  };
}

// ---------------------------------------------------------------- header

class _Header extends StatelessWidget {
  const _Header({
    required this.name,
    required this.audience,
    required this.updatedAt,
  });

  final String? name;
  final DashboardAudience audience;
  final DateTime? updatedAt;

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  String _greeting() {
    final h = DateTime.now().hour;
    final part =
        h < 12 ? 'Good morning' : (h < 17 ? 'Good afternoon' : 'Good evening');
    final n = name?.trim() ?? '';
    return n.isEmpty ? part : '$part, $n';
  }

  String _time(DateTime d) {
    final h = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m ${d.hour >= 12 ? 'PM' : 'AM'}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final date =
        '${_days[now.weekday - 1]}, ${_months[now.month - 1]} ${now.day}';
    final updated =
        updatedAt == null ? '' : '  ·  Updated ${_time(updatedAt!)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _greeting(),
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '$date$updated',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            StatusChip(
              label: audience.headline,
              tone: StatusTone.info,
              icon: Icons.person_outline,
            ),
          ],
        ),
      ],
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 0,
        color: scheme.errorContainer,
        child: ListTile(
          leading: Icon(Icons.cloud_off_outlined, color: scheme.onErrorContainer),
          title: Text(
            "Couldn't load the schedule",
            style: TextStyle(color: scheme.onErrorContainer),
          ),
          subtitle: Text(
            'Showing what is saved on this device.',
            style: TextStyle(color: scheme.onErrorContainer),
          ),
          trailing: TextButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ),
    );
  }
}
