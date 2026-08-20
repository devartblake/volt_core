import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../domain/entities/task_schedule_entity.dart';
import '../../../../core/theme/status_colors.dart';

/// Timeline View: Mini calendar sidebar (20%) + Chronological timeline (80%)
class ScheduleCalendarTimeline extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final CalendarFormat calendarFormat;
  final List<TaskScheduleEntity> items;

  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final void Function(CalendarFormat format) onFormatChanged;
  final void Function(DateTime focusedDay) onPageChanged;
  final void Function(TaskScheduleEntity task)? onTaskTap;

  const ScheduleCalendarTimeline({
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

  Widget _buildDesktopLayout(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mini calendar sidebar (20%)
        SizedBox(
          width: 280,
          child: _buildMiniCalendarSidebar(theme),
        ),

        // Divider
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: theme.colorScheme.outlineVariant,
        ),

        // Timeline panel (80%)
        Expanded(
          child: _buildTimelinePanel(theme),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Compact calendar on top
        _buildCompactCalendar(theme),

        Divider(
          height: 1,
          thickness: 1,
          color: theme.colorScheme.outlineVariant,
        ),

        // Timeline below
        Expanded(
          child: _buildTimelinePanel(theme),
        ),
      ],
    );
  }

  Widget _buildMiniCalendarSidebar(ThemeData theme) {
    return Container(
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        children: [
          // Mini calendar
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TableCalendar<TaskScheduleEntity>(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2035, 12, 31),
                  focusedDay: focusedDay,
                  selectedDayPredicate: (day) => isSameDay(selectedDay, day),
                  calendarFormat: CalendarFormat.month,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  eventLoader: (day) => _eventsForDay(day),
                  headerStyle: HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: theme.textTheme.titleMedium!,
                  ),
                  calendarStyle: CalendarStyle(
                    outsideDaysVisible: false,
                    weekendTextStyle: TextStyle(
                      color: theme.colorScheme.error,
                      fontSize: 12,
                    ),
                    defaultTextStyle: TextStyle(fontSize: 12),
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
                    markerSize: 6,
                    markersMaxCount: 3,
                  ),
                  onDaySelected: onDaySelected,
                  onPageChanged: onPageChanged,
                  availableGestures: AvailableGestures.horizontalSwipe,
                ),
              ),
            ),
          ),

          // Quick filters
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'QUICK FILTERS',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                _FilterButton(
                  label: 'Today',
                  icon: Icons.today,
                  onTap: () => onDaySelected(DateTime.now(), DateTime.now()),
                  theme: theme,
                ),
                const SizedBox(height: 8),
                _FilterButton(
                  label: 'This Week',
                  icon: Icons.view_week,
                  onTap: () {
                    final now = DateTime.now();
                    onDaySelected(now, now);
                  },
                  theme: theme,
                ),
                const SizedBox(height: 8),
                _FilterButton(
                  label: 'This Month',
                  icon: Icons.calendar_month,
                  onTap: () {
                    final now = DateTime.now();
                    onDaySelected(now, now);
                  },
                  theme: theme,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCalendar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: TableCalendar<TaskScheduleEntity>(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2035, 12, 31),
        focusedDay: focusedDay,
        selectedDayPredicate: (day) => isSameDay(selectedDay, day),
        calendarFormat: CalendarFormat.week,
        startingDayOfWeek: StartingDayOfWeek.monday,
        eventLoader: (day) => _eventsForDay(day),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
        ),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
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
          markerSize: 5,
          markersMaxCount: 3,
        ),
        onDaySelected: onDaySelected,
        onPageChanged: onPageChanged,
      ),
    );
  }

  Widget _buildTimelinePanel(ThemeData theme) {
    // Get tasks and group by date
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final monthEnd = DateTime(now.year, now.month + 1, 0);

    final timelineTasks = items.where((task) {
      return task.scheduledDate.isAfter(weekStart.subtract(Duration(days: 1))) &&
          task.scheduledDate.isBefore(monthEnd.add(Duration(days: 1)));
    }).toList()..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));

    final groupedTasks = <DateTime, List<TaskScheduleEntity>>{};
    for (final task in timelineTasks) {
      final date = DateTime(
        task.scheduledDate.year,
        task.scheduledDate.month,
        task.scheduledDate.day,
      );
      groupedTasks.putIfAbsent(date, () => []).add(task);
    }

    final sortedDates = groupedTasks.keys.toList()..sort();

    return Container(
      color: theme.colorScheme.surface,
      child: Column(
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
                  'Timeline',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${timelineTasks.length} tasks',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Timeline
          Expanded(
            child: timelineTasks.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sortedDates.length,
              itemBuilder: (context, index) {
                final date = sortedDates[index];
                final tasks = groupedTasks[date]!;
                return _buildTimelineDay(date, tasks, theme);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineDay(
      DateTime date,
      List<TaskScheduleEntity> tasks,
      ThemeData theme,
      ) {
    final isToday = isSameDay(date, DateTime.now());
    final isSelected = isSameDay(date, selectedDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Date header
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isToday
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                : (isSelected
                ? theme.colorScheme.surfaceContainerHighest
                : null),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isToday
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _formatDateHeader(date),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isToday
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${tasks.length}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Tasks for this day
        ...tasks.map((task) => _buildTimelineTask(task, theme)),

        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildTimelineTask(TaskScheduleEntity task, ThemeData theme) {
    final isPast = task.scheduledDate.isBefore(DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline connector
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isPast ? theme.status.success : theme.colorScheme.primary,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 2,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 2,
                height: 60,
                color: theme.colorScheme.outlineVariant,
              ),
            ],
          ),

          const SizedBox(width: 16),

          // Task card
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
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
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Time badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isPast
                                  ? theme.status.success.withValues(alpha: 0.1)
                                  : theme.colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 14,
                                  color: isPast
                                      ? theme.status.success
                                      : theme.colorScheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _formatTime(task.scheduledDate),
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: isPast
                                        ? theme.status.success
                                        : theme.colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),

                          // Status
                          if (isPast)
                            Icon(
                              Icons.check_circle,
                              color: theme.status.success,
                              size: 20,
                            ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Title
                      Text(
                        task.address.isEmpty
                            ? (task.title.isEmpty ? '(No address/title)' : task.title)
                            : task.address,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 8),

                      // Metadata
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          if (task.siteCode.isNotEmpty)
                            _buildMetaChip(
                              Icons.location_on_outlined,
                              task.siteCode,
                              theme,
                            ),
                          if (task.siteGrade.isNotEmpty)
                            _buildGradeBadge(task.siteGrade, theme),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaChip(IconData icon, String label, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.colorScheme.onSurfaceVariant),
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

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.timeline_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No tasks in timeline',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tasks scheduled this week and month\nwill appear here',
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

  List<TaskScheduleEntity> _eventsForDay(DateTime day) {
    return items
        .where((e) =>
    e.scheduledDate.year == day.year &&
        e.scheduledDate.month == day.month &&
        e.scheduledDate.day == day.day)
        .toList()
      ..sort((a, b) => a.scheduledDate.compareTo(b.scheduledDate));
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final minute = date.minute.toString().padLeft(2, '0');
    final period = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatDateHeader(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final isToday = isSameDay(date, DateTime.now());
    final isTomorrow = isSameDay(date, DateTime.now().add(Duration(days: 1)));

    if (isToday) return 'Today, ${months[date.month - 1]} ${date.day}';
    if (isTomorrow) return 'Tomorrow, ${months[date.month - 1]} ${date.day}';

    return '${days[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
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
}

class _FilterButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final ThemeData theme;

  const _FilterButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}