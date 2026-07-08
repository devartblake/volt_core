import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voltcore/shared/widgets/responsive_scaffold.dart';
import '../../../auth/domain/user_role.dart';
import '../../../auth/presenter/controllers/auth_controller.dart';
import '../../../schedule/domain/entities/task_schedule_entity.dart';
import '../../../schedule/presenter/controllers/schedule_controller.dart';

/// Enhanced role-aware dashboard with stats overview and quick actions
/// FIXED VERSION: Shows upcoming tasks if no past tasks + debug logging
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final role = auth.currentRole;
    final isAuthed = auth.isAuthenticated;
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final scheduleState = ref.watch(scheduleControllerProvider);

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          if (isAuthed && role != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Chip(
                avatar: Icon(
                  _roleIcon(role),
                  size: 18,
                  color: color.onSecondaryContainer,
                ),
                label: Text(
                  _roleLabel(role),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color.onSecondaryContainer,
                  ),
                ),
                backgroundColor: color.secondaryContainer,
              ),
            ),
        ],
      ),
      body: scheduleState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) {
          if (kDebugMode) {
            debugPrint('=== DASHBOARD ERROR ===');
            debugPrint('Error: $err');
            debugPrint('======================');
          }
          return _buildDashboardContent(
            context,
            theme,
            auth,
            role,
            isAuthed,
            [],
          );
        },
        data: (tasks) {
          // DEBUG: Print task info
          if (kDebugMode) {
            debugPrint('=== DASHBOARD DEBUG ===');
            debugPrint('Total tasks: ${tasks.length}');
            debugPrint('Is authenticated: $isAuthed');

            final now = DateTime.now();
            final pastTasks = tasks.where((t) => t.scheduledDate.isBefore(now)).length;
            final futureTasks = tasks.where((t) => t.scheduledDate.isAfter(now)).length;

            debugPrint('Past tasks: $pastTasks');
            debugPrint('Future tasks: $futureTasks');

            if (tasks.isNotEmpty) {
              debugPrint('Sample task dates:');
              for (var i = 0; i < tasks.length && i < 5; i++) {
                final isPast = tasks[i].scheduledDate.isBefore(now);
                debugPrint('  Task $i: ${tasks[i].scheduledDate} - ${isPast ? "PAST ✓" : "FUTURE →"}');
              }
            }
            debugPrint('======================');
          }

          return _buildDashboardContent(
            context,
            theme,
            auth,
            role,
            isAuthed,
            tasks,
          );
        },
      ),
    );
  }

  Widget _buildDashboardContent(
      BuildContext context,
      ThemeData theme,
      dynamic auth,
      UserRole? role,
      bool isAuthed,
      List<TaskScheduleEntity> tasks,
      ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 900;

        if (isWide) {
          return _buildDesktopLayout(
            context,
            theme,
            auth,
            role,
            isAuthed,
            tasks,
          );
        } else {
          return _buildMobileLayout(
            context,
            theme,
            auth,
            role,
            isAuthed,
            tasks,
          );
        }
      },
    );
  }

  Widget _buildDesktopLayout(
      BuildContext context,
      ThemeData theme,
      dynamic auth,
      UserRole? role,
      bool isAuthed,
      List<TaskScheduleEntity> tasks,
      ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome header
          _buildWelcomeHeader(theme, auth, role),
          const SizedBox(height: 24),

          // Stats overview (if authenticated)
          if (isAuthed) ...[
            _buildStatsGrid(theme, tasks, role),
            const SizedBox(height: 32),
          ],

          // Main content row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left column: Quick actions (tiles)
              Expanded(
                flex: 2,
                child: _buildQuickActions(context, theme, role),
              ),

              const SizedBox(width: 24),

              // Right column: Recent activity + info
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // FIXED: Always show Recent Activity section if authenticated
                    if (isAuthed) ...[
                      _buildRecentActivity(theme, tasks),
                      const SizedBox(height: 24),
                    ],
                    _buildSystemInfo(theme),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout(
      BuildContext context,
      ThemeData theme,
      dynamic auth,
      UserRole? role,
      bool isAuthed,
      List<TaskScheduleEntity> tasks,
      ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome header
          _buildWelcomeHeader(theme, auth, role),
          const SizedBox(height: 20),

          // Stats overview (if authenticated)
          if (isAuthed) ...[
            _buildStatsGrid(theme, tasks, role),
            const SizedBox(height: 24),
          ],

          // Quick actions
          _buildQuickActions(context, theme, role),
          const SizedBox(height: 24),

          // Recent activity (FIXED: always show if authenticated)
          if (isAuthed) ...[
            _buildRecentActivity(theme, tasks),
            const SizedBox(height: 24),
          ],

          // System info
          _buildSystemInfo(theme),
        ],
      ),
    );
  }

  Widget _buildWelcomeHeader(ThemeData theme, dynamic auth, UserRole? role) {
    final hour = DateTime.now().hour;
    String timeGreeting = 'Good morning';
    if (hour >= 12 && hour < 17) timeGreeting = 'Good afternoon';
    if (hour >= 17) timeGreeting = 'Good evening';

    final displayName = auth.displayName;
    final roleLabel = role != null ? _roleLabel(role) : null;

    String mainGreeting;
    if (displayName != null && displayName.isNotEmpty) {
      mainGreeting = '$timeGreeting, $displayName!';
    } else if (roleLabel != null) {
      mainGreeting = '$timeGreeting, $roleLabel!';
    } else {
      mainGreeting = '$timeGreeting!';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          mainGreeting,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _formatDate(DateTime.now()),
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        if (roleLabel != null)
          Text(
            'Voltcore Access • $roleLabel',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  Widget _buildStatsGrid(
      ThemeData theme,
      List<TaskScheduleEntity> tasks,
      UserRole? role,
      ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekEnd = today.add(const Duration(days: 7));

    final todayTasks = tasks.where((t) {
      final taskDate = DateTime(
        t.scheduledDate.year,
        t.scheduledDate.month,
        t.scheduledDate.day,
      );
      return taskDate.isAtSameMomentAs(today);
    }).length;

    final weekTasks = tasks.where((t) {
      final taskDate = DateTime(
        t.scheduledDate.year,
        t.scheduledDate.month,
        t.scheduledDate.day,
      );
      return taskDate.isAfter(today) && taskDate.isBefore(weekEnd);
    }).length;

    final overdueTasks = tasks.where((t) {
      final taskDate = DateTime(
        t.scheduledDate.year,
        t.scheduledDate.month,
        t.scheduledDate.day,
      );
      return taskDate.isBefore(today);
    }).length;

    final completedTasks = tasks.where((t) {
      return t.scheduledDate.isBefore(now);
    }).length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1200
            ? 4
            : (constraints.maxWidth > 600 ? 2 : 1);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overview',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.6,
              children: [
                _StatCard(
                  title: 'Today',
                  value: '$todayTasks',
                  subtitle: 'tasks scheduled',
                  icon: Icons.today_outlined,
                  color: Colors.blue,
                  theme: theme,
                  onTap: () => context.goNamed('schedule'),
                ),
                _StatCard(
                  title: 'This Week',
                  value: '$weekTasks',
                  subtitle: 'upcoming tasks',
                  icon: Icons.calendar_month_outlined,
                  color: Colors.green,
                  theme: theme,
                  onTap: () => context.goNamed('schedule'),
                ),
                _StatCard(
                  title: 'Overdue',
                  value: '$overdueTasks',
                  subtitle: 'need attention',
                  icon: Icons.warning_amber_rounded,
                  color: Colors.red,
                  theme: theme,
                  onTap: () => context.goNamed('schedule'),
                ),
                _StatCard(
                  title: 'Completed',
                  value: '$completedTasks',
                  subtitle: 'past tasks',
                  icon: Icons.check_circle_outline,
                  color: Colors.teal,
                  theme: theme,
                  onTap: () => context.goNamed('schedule'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickActions(
      BuildContext context,
      ThemeData theme,
      UserRole? role,
      ) {
    final tiles = _buildAllTiles(role);

    if (tiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No dashboard items available for your role.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Choose a workflow to get started',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        ...tiles.map((tile) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _DashboardTile(tile: tile),
        )),
      ],
    );
  }

  Widget _buildRecentActivity(ThemeData theme, List<TaskScheduleEntity> tasks) {
    final now = DateTime.now();

    // FIXED: Show both past and upcoming tasks
    final pastTasks = tasks
        .where((t) => t.scheduledDate.isBefore(now))
        .toList()
      ..sort((a, b) => b.scheduledDate.compareTo(a.scheduledDate));

    final upcomingTasks = tasks
        .where((t) => t.scheduledDate.isAfter(now))
        .toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    final displayTasks = <TaskScheduleEntity>[];

    // Prioritize recent completions (up to 3), then fill with upcoming
    displayTasks.addAll(pastTasks.take(3));
    if (displayTasks.length < 5) {
      displayTasks.addAll(upcomingTasks.take(5 - displayTasks.length));
    }

    if (kDebugMode) {
      debugPrint('--- Recent Activity Debug ---');
      debugPrint('Past tasks available: ${pastTasks.length}');
      debugPrint('Upcoming tasks available: ${upcomingTasks.length}');
      debugPrint('Displaying: ${displayTasks.length}');
      debugPrint('---------------------------');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Activity',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant,
            ),
          ),
          child: displayTasks.isEmpty
              ? Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.event_note_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No recent activity',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Schedule your first task to get started',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          )
              : ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: displayTasks.length,
            separatorBuilder: (_, __) => Divider(
              height: 24,
              color: theme.colorScheme.outlineVariant,
            ),
            itemBuilder: (context, index) {
              final task = displayTasks[index];
              final isPast = task.scheduledDate.isBefore(now);
              return _buildActivityItem(task, theme, isPast);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(TaskScheduleEntity task, ThemeData theme, bool isPast) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: isPast ? Colors.green : Colors.blue,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.address.isEmpty
                          ? (task.title.isEmpty ? '(No title)' : task.title)
                          : task.address,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isPast)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Upcoming',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _formatDateTime(task.scheduledDate),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (task.siteGrade.isNotEmpty) ...[
                const SizedBox(height: 4),
                _buildGradeBadge(task.siteGrade, theme),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGradeBadge(String grade, ThemeData theme) {
    final color = _getGradeColor(grade);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        grade,
        style: theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getGradeColor(String grade) {
    switch (grade.toLowerCase()) {
      case 'green':
        return Colors.green;
      case 'amber':
      case 'yellow':
        return Colors.orange;
      case 'red':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSystemInfo(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'System Info',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  Icons.bolt,
                  'Voltcore',
                  'Inspection Management',
                  theme,
                ),
                const SizedBox(height: 12),
                _buildInfoRow(
                  Icons.update,
                  'Version',
                  '1.0.0',
                  theme,
                ),
                if (kDebugMode) ...[
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.bug_report,
                    'Mode',
                    'Debug',
                    theme,
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(
      IconData icon,
      String label,
      String value,
      ThemeData theme,
      ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const months = [
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
      'December'
    ];
    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatDateTime(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final hour =
    date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '${months[date.month - 1]} ${date.day} at $hour:$minute $period';
  }
}

// [Rest of the code remains exactly the same - tiles, models, helpers, etc.]

/// Simple tile model for the dashboard
class _DashTile {
  final String title;
  final String subtitle;
  final IconData icon;
  final String routeName;
  final Set<UserRole>? visibleFor;

  const _DashTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.routeName,
    this.visibleFor,
  });

  bool isVisibleFor(UserRole? role) {
    if (visibleFor == null) return true;
    if (role == null) return false;
    return visibleFor!.contains(role);
  }
}

/// Build all dashboard tiles (RBAC logic)
List<_DashTile> _buildAllTiles(UserRole? role) {
  const all = <_DashTile>[
    _DashTile(
      title: 'My Workload',
      subtitle: 'Personal inspections & maintenance stats',
      icon: Icons.dashboard_customize_outlined,
      routeName: 'tech_dashboard',
      visibleFor: {
        UserRole.tech,
        UserRole.supervisor,
        UserRole.dispatcher,
        UserRole.admin,
      },
    ),
    _DashTile(
      title: 'New Inspection',
      subtitle: 'Start a generator compliance inspection',
      icon: Icons.fact_check_outlined,
      routeName: 'inspection_new',
      visibleFor: {
        UserRole.tech,
        UserRole.dispatcher,
        UserRole.supervisor,
        UserRole.admin,
      },
    ),
    _DashTile(
      title: 'Inspection History',
      subtitle: 'View previous inspections & reports',
      icon: Icons.history_outlined,
      routeName: 'inspections',
      visibleFor: {
        UserRole.tech,
        UserRole.dispatcher,
        UserRole.supervisor,
        UserRole.admin,
      },
    ),
    _DashTile(
      title: 'New Maintenance Job',
      subtitle: 'Create a maintenance / repair checklist',
      icon: Icons.build_circle_outlined,
      routeName: 'maintenance_new',
      visibleFor: {
        UserRole.tech,
        UserRole.dispatcher,
        UserRole.supervisor,
        UserRole.admin,
      },
    ),
    _DashTile(
      title: 'Maintenance Archive',
      subtitle: 'Browse and export maintenance history',
      icon: Icons.archive_outlined,
      routeName: 'maintenance_archive',
      visibleFor: {
        UserRole.tech,
        UserRole.dispatcher,
        UserRole.supervisor,
        UserRole.admin,
      },
    ),
    _DashTile(
      title: 'Schedule',
      subtitle: 'View inspection & maintenance calendar',
      icon: Icons.calendar_month_outlined,
      routeName: 'schedule',
      visibleFor: {
        UserRole.dispatcher,
        UserRole.supervisor,
        UserRole.admin,
      },
    ),
    _DashTile(
      title: 'Equipment Registry',
      subtitle: 'Manage generator nameplate infra',
      icon: Icons.inventory_2_outlined,
      routeName: 'nameplate_list',
      visibleFor: {
        UserRole.tech,
        UserRole.dispatcher,
        UserRole.supervisor,
        UserRole.admin,
      },
    ),
    _DashTile(
      title: 'Admin Dashboard',
      subtitle: 'Fleet analytics, KPIs & overview',
      icon: Icons.analytics_outlined,
      routeName: 'admin_dashboard',
      visibleFor: {
        UserRole.admin,
      },
    ),
    _DashTile(
      title: 'Admin Settings',
      subtitle: 'Roles, permissions & configuration',
      icon: Icons.admin_panel_settings_outlined,
      routeName: 'admin_settings',
      visibleFor: {
        UserRole.admin,
      },
    ),
    if (kDebugMode)
      _DashTile(
        title: 'Hive Debug',
        subtitle: 'Inspect and manage local data',
        icon: Icons.bug_report,
        routeName: 'hive_debug',
        visibleFor: null,
      ),
  ];

  if (role == null) {
    return all.where((t) => t.visibleFor == null).toList();
  }

  return all.where((t) => t.isVisibleFor(role)).toList();
}

/// Enhanced stat card widget
class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final ThemeData theme;
  final VoidCallback? onTap;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.theme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 22),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
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
}

/// Enhanced dashboard tile widget
class _DashboardTile extends StatelessWidget {
  const _DashboardTile({required this.tile});

  final _DashTile tile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colors.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => context.goNamed(tile.routeName),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  tile.icon,
                  size: 24,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tile.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tile.subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: colors.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Helper: human label for roles
String _roleLabel(UserRole role) {
  switch (role) {
    case UserRole.tech:
      return 'Technician';
    case UserRole.dispatcher:
      return 'Dispatcher';
    case UserRole.supervisor:
      return 'Supervisor';
    case UserRole.admin:
      return 'Admin';
  }
}

/// Helper: icon for roles
IconData _roleIcon(UserRole role) {
  switch (role) {
    case UserRole.tech:
      return Icons.engineering_outlined;
    case UserRole.dispatcher:
      return Icons.support_agent_outlined;
    case UserRole.supervisor:
      return Icons.verified_user_outlined;
    case UserRole.admin:
      return Icons.admin_panel_settings_outlined;
  }
}