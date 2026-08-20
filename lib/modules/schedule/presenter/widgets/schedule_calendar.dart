import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../domain/entities/task_schedule_entity.dart';
import '../../../../core/theme/status_colors.dart';

/// Enhanced schedule calendar with split-panel design
/// Left: Calendar view (60%) | Right: Upcoming tasks panel (40%)
/// Mobile: Stacked layout (calendar top, tasks bottom)
class ScheduleCalendarEnhanced extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final CalendarFormat calendarFormat;
  final List<TaskScheduleEntity> items;

  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final void Function(CalendarFormat format) onFormatChanged;
  final void Function(DateTime focusedDay) onPageChanged;
  final void Function(TaskScheduleEntity task)? onTaskTap;

  const ScheduleCalendarEnhanced({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.calendarFormat,
    required this.items,
    required this.onDaySelected,
    required this.onFormatChanged,
    required this.onPageChanged,
    this.onTaskTap,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 900;

        if (isMobile) {
          return _buildMobileLayout(context);
        } else {
          return _buildDesktopLayout(context);
        }
      },
    );
  }

  // Desktop layout - split panel
  Widget _buildDesktopLayout(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Calendar panel (60%)
        Expanded(
          flex: 60,
          child: _buildCalendar(theme),
        ),

        // Divider
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: theme.colorScheme.outlineVariant,
        ),

        // Upcoming tasks panel (40%)
        Expanded(
          flex: 40,
          child: _buildUpcomingPanel(theme),
        ),
      ],
    );
  }

  // Mobile layout - stacked
  Widget _buildMobileLayout(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Calendar on top
        _buildCalendar(theme),

        // Divider
        Divider(
          height: 1,
          thickness: 1,
          color: theme.colorScheme.outlineVariant,
        ),

        // Upcoming tasks below
        Expanded(
          child: _buildUpcomingPanel(theme),
        ),
      ],
    );
  }

  // Calendar widget
  Widget _buildCalendar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TableCalendar<TaskScheduleEntity>(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2035, 12, 31),
        focusedDay: focusedDay,
        selectedDayPredicate: (day) => isSameDay(selectedDay, day),
        calendarFormat: calendarFormat,
        startingDayOfWeek: StartingDayOfWeek.monday,
        eventLoader: (day) => _eventsForDay(day),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: true,
          weekendTextStyle: TextStyle(color: theme.colorScheme.error),
          holidayTextStyle: TextStyle(color: theme.colorScheme.error),
          selectedDecoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
          todayDecoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          markerDecoration: BoxDecoration(
            color: theme.colorScheme.secondary,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 3,
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
          formatButtonShowsNext: false,
          formatButtonDecoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          formatButtonTextStyle: TextStyle(
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        onDaySelected: onDaySelected,
        onFormatChanged: onFormatChanged,
        onPageChanged: onPageChanged,
      ),
    );
  }

  // Upcoming tasks panel
  Widget _buildUpcomingPanel(ThemeData theme) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekEnd = today.add(const Duration(days: 7));

    // Group tasks
    final todayTasks = items.where((task) {
      final taskDate = DateTime(
        task.scheduledDate.year,
        task.scheduledDate.month,
        task.scheduledDate.day,
      );
      return taskDate.isAtSameMomentAs(today);
    }).toList()..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    final tomorrowTasks = items.where((task) {
      final taskDate = DateTime(
        task.scheduledDate.year,
        task.scheduledDate.month,
        task.scheduledDate.day,
      );
      return taskDate.isAtSameMomentAs(tomorrow);
    }).toList()..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    final weekTasks = items.where((task) {
      final taskDate = DateTime(
        task.scheduledDate.year,
        task.scheduledDate.month,
        task.scheduledDate.day,
      );
      return taskDate.isAfter(tomorrow) && taskDate.isBefore(weekEnd);
    }).toList()..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    final upcomingCount = todayTasks.length + tomorrowTasks.length + weekTasks.length;

    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Upcoming Tasks',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (upcomingCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$upcomingCount',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Task list
          Expanded(
            child: upcomingCount == 0
                ? _buildEmptyState(theme)
                : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (todayTasks.isNotEmpty) ...[
                  _buildTaskGroup('TODAY', todayTasks, theme),
                  const SizedBox(height: 16),
                ],
                if (tomorrowTasks.isNotEmpty) ...[
                  _buildTaskGroup('TOMORROW', tomorrowTasks, theme),
                  const SizedBox(height: 16),
                ],
                if (weekTasks.isNotEmpty) ...[
                  _buildTaskGroup('THIS WEEK', weekTasks, theme),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Task group section
  Widget _buildTaskGroup(
      String title,
      List<TaskScheduleEntity> tasks,
      ThemeData theme,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Text(
                title,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${tasks.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Tasks
        ...tasks.map((task) => _buildTaskItem(task, theme)),
      ],
    );
  }

  // Individual task item
  Widget _buildTaskItem(TaskScheduleEntity task, ThemeData theme) {
    final isPast = task.scheduledDate.isBefore(DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => onTaskTap?.call(task),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Status indicator bar
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: _getTaskStatusColor(task, isPast, theme),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Address/Title
                    Text(
                      task.address.isEmpty
                          ? (task.title.isEmpty ? '(No address/title)' : task.title)
                          : task.address,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6),

                    // Metadata row
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        // Time
                        _buildMetaItem(
                          Icons.access_time,
                          _formatTime(task.scheduledDate),
                          theme,
                        ),

                        // Site code
                        if (task.siteCode.isNotEmpty)
                          _buildMetaItem(
                            Icons.location_on_outlined,
                            task.siteCode,
                            theme,
                          ),

                        // Grade badge
                        if (task.siteGrade.isNotEmpty)
                          _buildGradeBadge(task.siteGrade, theme),
                      ],
                    ),
                  ],
                ),
              ),

              // Chevron
              Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Metadata item helper
  Widget _buildMetaItem(IconData icon, String label, ThemeData theme) {
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
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // Grade badge
  Widget _buildGradeBadge(String grade, ThemeData theme) {
    final color = _getGradeColor(grade);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
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

  // Empty state
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No upcoming tasks',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tasks scheduled for today and this week\nwill appear here',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper: Get events for a specific day
  List<TaskScheduleEntity> _eventsForDay(DateTime day) {
    return items
        .where(
          (e) =>
      e.scheduledDate.year == day.year &&
          e.scheduledDate.month == day.month &&
          e.scheduledDate.day == day.day,
    )
        .toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
  }

  // Helper: Format time
  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  // Helper: Get task status color
  Color _getTaskStatusColor(TaskScheduleEntity task, bool isPast, ThemeData theme) {
    if (isPast) {
      return theme.status.success; // Completed
    }

    final now = DateTime.now();
    final taskDate = DateTime(
      task.scheduledDate.year,
      task.scheduledDate.month,
      task.scheduledDate.day,
    );
    final today = DateTime(now.year, now.month, now.day);

    if (taskDate.isAtSameMomentAs(today)) {
      return theme.status.warning; // Today
    }

    return theme.colorScheme.primary; // Upcoming
  }

  // Helper: Get grade color
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
}