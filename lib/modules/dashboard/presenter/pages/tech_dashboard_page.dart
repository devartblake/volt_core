import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:voltcore/modules/dashboard/domain/entities/dashboard_stats_entity.dart';
import 'package:voltcore/modules/dashboard/domain/usecases/load_dashboard_stats_usecase.dart';
import 'package:voltcore/modules/dashboard/infra/repositories/dashboard_repository_impl.dart';

import '../../../auth/presenter/controllers/auth_controller.dart';

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
/// You can either:
///  - Route to this directly for techs, or
///  - Embed its content inside your main DashboardPage later.
class TechDashboardPage extends ConsumerStatefulWidget {
  const TechDashboardPage({super.key});

  @override
  ConsumerState<TechDashboardPage> createState() =>
      _TechDashboardPageState();
}

class _TechDashboardPageState extends ConsumerState<TechDashboardPage> {
  bool _loadedOnce = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loadedOnce) {
      _loadedOnce = true;

      final auth = ref.read(authStateProvider);
      final userId = auth.userId ?? 'local-tech';

      ref
          .read(techDashboardControllerProvider.notifier)
          .loadForUser(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(techDashboardControllerProvider);
    final theme = Theme.of(context);
    final color = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tech Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : state.error != null
            ? Center(
          child: Text(
            'Error: ${state.error}',
            style: TextStyle(color: color.error),
          ),
        )
            : _buildContent(context, state.stats ?? const DashboardStatsEntity.empty()),
      ),
    );
  }

  Widget _buildContent(BuildContext context, DashboardStatsEntity stats) {
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
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _StatCard(
              label: 'Open Inspections',
              value: stats.myOpenInspections.toString(),
              icon: Icons.assignment_late_outlined,
              color: colorScheme.primary,
            ),
            _StatCard(
              label: 'Completed Inspections',
              value: stats.myCompletedInspections.toString(),
              icon: Icons.fact_check_outlined,
              color: colorScheme.tertiary,
            ),
            _StatCard(
              label: 'Open Maintenance Jobs',
              value: stats.myOpenMaintenanceJobs.toString(),
              icon: Icons.build_outlined,
              color: colorScheme.secondary,
            ),
            _StatCard(
              label: 'Completed Jobs',
              value: stats.myCompletedMaintenanceJobs.toString(),
              icon: Icons.task_alt_outlined,
              color: colorScheme.primaryContainer,
            ),
            _StatCard(
              label: 'Upcoming Tasks',
              value: stats.upcomingTasks.toString(),
              icon: Icons.calendar_today_outlined,
              color: colorScheme.secondaryContainer,
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: 260,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
