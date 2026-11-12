import 'package:flutter/material.dart';

import '../../../../core/theme/status_colors.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:voltcore/modules/dashboard/domain/entities/dashboard_stats_entity.dart';
import 'package:voltcore/modules/dashboard/domain/usecases/load_dashboard_stats_usecase.dart';
import 'package:voltcore/modules/dashboard/infra/repositories/dashboard_repository_impl.dart';

import '../../../../core/constants/feature_flags.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/presenter/controllers/auth_controller.dart';
import '../../../templates/presenter/widgets/generator_pilot_drafts_panel.dart';
import '../../../templates/presenter/widgets/generator_pilot_launch_panel.dart';

/// Provide the usecase from the repository.
final loadDashboardStatsUsecaseProvider =
    Provider<LoadDashboardStatsUsecase>((ref) {
  final repo = ref.watch(dashboardRepositoryProvider);
  return LoadDashboardStatsUsecase(repo);
});

/// Simple UI state for the tech dashboard.
class TechDashboardState {
  final bool isLoading;
  final DashboardStatsEntity? stats;
  final String? error;

  const TechDashboardState({
    required this.isLoading,
    this.stats,
    this.error,
  });

  const TechDashboardState.initial()
      : isLoading = false,
        stats = null,
        error = null;

  TechDashboardState copyWith({
    bool? isLoading,
    DashboardStatsEntity? stats,
    String? error,
  }) {
    return TechDashboardState(
      isLoading: isLoading ?? this.isLoading,
      stats: stats ?? this.stats,
      error: error,
    );
  }
}

/// Controller that loads stats for the current tech.
class TechDashboardController extends StateNotifier<TechDashboardState> {
  final LoadDashboardStatsUsecase _usecase;

  TechDashboardController(this._usecase)
      : super(const TechDashboardState.initial());

  Future<void> loadForUser(String technicianId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final stats = await _usecase(technicianId: technicianId);
      state = state.copyWith(isLoading: false, stats: stats);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

/// Provider for the tech dashboard controller.
final techDashboardControllerProvider =
    StateNotifierProvider<TechDashboardController, TechDashboardState>((ref) {
  final usecase = ref.watch(loadDashboardStatsUsecaseProvider);
  return TechDashboardController(usecase);
});

/// Technician-focused dashboard page.
///
/// The controlled generator pilot controls remain available when the build flag
/// is enabled even if remote workload statistics cannot load while offline.
class TechDashboardPage extends ConsumerStatefulWidget {
  const TechDashboardPage({super.key});

  @override
  ConsumerState<TechDashboardPage> createState() =>
      _TechDashboardPageState();
}

class _TechDashboardPageState extends ConsumerState<TechDashboardPage> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = ref.read(authStateProvider);
      final userId = auth.userId ?? 'local-tech';

      ref
          .read(techDashboardControllerProvider.notifier)
          .loadForUser(userId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(techDashboardControllerProvider);
    final pilotEnabled = FeatureFlags.generatorTemplatePilotEnabled;

    return AppPage(
      title: 'Tech Dashboard',
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: pilotEnabled
            ? _buildContent(
                context,
                state.stats ?? const DashboardStatsEntity.empty(),
                workloadLoading: state.isLoading,
                workloadError: state.error,
              )
            : state.isLoading
                ? const LoadingIndicator()
                : state.error != null
                    ? Center(
                        child: Text(
                          'Error: ${state.error}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      )
                    : _buildContent(
                        context,
                        state.stats ?? const DashboardStatsEntity.empty(),
                      ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    DashboardStatsEntity stats, {
    bool workloadLoading = false,
    String? workloadError,
  }) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      children: [
        Text(
          'Today\'s Overview',
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Quick summary of your inspections and maintenance workload.',
          style: textTheme.bodyMedium,
        ),
        const SizedBox(height: 24),
        if (FeatureFlags.generatorTemplatePilotEnabled) ...[
          const GeneratorPilotLaunchPanel(),
          const SizedBox(height: 16),
          const GeneratorPilotDraftsPanel(),
          const SizedBox(height: 24),
        ],
        if (workloadLoading)
          const _WorkloadStatusCard(
            icon: Icons.sync,
            message: 'Loading workload statistics…',
          )
        else if (workloadError != null)
          _WorkloadStatusCard(
            icon: Icons.cloud_off_outlined,
            message:
                'Workload statistics are unavailable right now. Pilot drafts '
                'remain local and can still be resumed offline.\n$workloadError',
            isError: true,
          )
        else
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              SizedBox(width: 260, child: StatCard(
                horizontal: true,
                label: 'Open Inspections',
                value: stats.myOpenInspections.toString(),
                icon: Icons.assignment_late_outlined,
                color: colorScheme.primary,
              )),
              SizedBox(width: 260, child: StatCard(
                horizontal: true,
                label: 'Completed Inspections',
                value: stats.myCompletedInspections.toString(),
                icon: Icons.fact_check_outlined,
                color: colorScheme.tertiary,
              )),
              SizedBox(width: 260, child: StatCard(
                horizontal: true,
                label: 'Open Maintenance Jobs',
                value: stats.myOpenMaintenanceJobs.toString(),
                icon: Icons.build_outlined,
                color: colorScheme.secondary,
              )),
              SizedBox(width: 260, child: StatCard(
                horizontal: true,
                label: 'Completed Jobs',
                value: stats.myCompletedMaintenanceJobs.toString(),
                icon: Icons.task_alt_outlined,
                color: Theme.of(context).status.success,
              )),
              SizedBox(width: 260, child: StatCard(
                horizontal: true,
                label: 'Upcoming Tasks',
                value: stats.upcomingTasks.toString(),
                icon: Icons.calendar_today_outlined,
                color: Theme.of(context).status.info,
              )),
            ],
          ),
      ],
    );
  }
}

class _WorkloadStatusCard extends StatelessWidget {
  const _WorkloadStatusCard({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isError
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

