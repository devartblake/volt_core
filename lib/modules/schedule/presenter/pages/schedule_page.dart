import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../domain/entities/task_schedule_entity.dart';
import '../controllers/schedule_controller.dart';
import '../widgets/schedule_calendar.dart';
import '../widgets/calendar_view_mode.dart';
import '../widgets/schedule_calendar_daily_agenda.dart';
import '../widgets/schedule_calendar_timeline.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../core/theme/status_colors.dart';

/// Schedule view mode enum
enum ScheduleView { list, calendar }

/// Time range filter enum
enum TimeRange { week, month, year, all }

/// Provider for current schedule view
final scheduleViewProvider =
StateProvider<ScheduleView>((ref) => ScheduleView.calendar);

/// Provider for current time range filter
final timeRangeProvider =
StateProvider<TimeRange>((ref) => TimeRange.month);

/// Provider for selected date in calendar
final selectedDateProvider =
StateProvider<DateTime>((ref) => DateTime.now());

/// Inspection Schedule Page with calendar and list views
class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key});

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheduleView = ref.watch(scheduleViewProvider);
    final timeRange = ref.watch(timeRangeProvider);

    final scheduleState = ref.watch(scheduleControllerProvider);

    return scheduleState.when(
      loading: () => AppPage(
      title: 'Schedule',
      body: const LoadingIndicator(),
    ),
      error: (err, st) => AppPage(
      title: 'Schedule',
      body: Center(
          child: Text('Error loading schedule: $err'),
        ),
    ),
      data: (allItems) {
        final filteredItems =
        _filterItems(allItems, timeRange, _selectedDay);

        return AppPage(
      title: 'Schedule',
      actions: [
              // Calendar view mode selector
              PopupMenuButton<CalendarViewMode>(
                icon: Icon(ref.watch(calendarViewModeProvider).icon),
                tooltip: 'Calendar View',
                onSelected: (mode) {
                  ref.read(calendarViewModeProvider.notifier).state = mode;
                },
                itemBuilder: (context) => CalendarViewMode.values.map((mode) {
                  final isActive = ref.watch(calendarViewModeProvider) == mode;
                  return PopupMenuItem(
                    value: mode,
                    child: Row(
                      children: [
                        Icon(
                          mode.icon,
                          color: isActive ? theme.colorScheme.primary : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                mode.label,
                                style: TextStyle(
                                  color: isActive ? theme.colorScheme.primary : null,
                                  fontWeight: isActive ? FontWeight.w600 : null,
                                ),
                              ),
                              Text(
                                mode.description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isActive
                                      ? theme.colorScheme.primary.withValues(alpha: 0.7)
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isActive)
                          Icon(
                            Icons.check,
                            color: theme.colorScheme.primary,
                            size: 20,
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),

              // View mode toggle (list/calendar)
              IconButton(
                icon: Icon(
                  scheduleView == ScheduleView.calendar
                      ? Icons.list
                      : Icons.calendar_month,
                ),
                tooltip: scheduleView == ScheduleView.calendar
                    ? 'List View'
                    : 'Calendar View',
                onPressed: () {
                  ref.read(scheduleViewProvider.notifier).state =
                  scheduleView == ScheduleView.calendar
                      ? ScheduleView.list
                      : ScheduleView.calendar;
                },
              ),

              // Filter menu
              PopupMenuButton<TimeRange>(
                icon: const Icon(Icons.filter_list),
                tooltip: 'Filter by time',
                onSelected: (range) {
                  ref.read(timeRangeProvider.notifier).state = range;
                },
                itemBuilder: (context) => _buildTimeRangeMenu(
                  context,
                  theme,
                  timeRange,
                ),
              ),
            ],
      body: Column(
            children: [
              // Stats summary bar
              _buildStatsBar(
                theme,
                allItems,
                filteredItems,
                timeRange,
              ),

              // Main content based on view mode
              Expanded(
                child: scheduleView == ScheduleView.calendar
                    ? _buildCalendarView(theme, allItems)
                    : _buildListView(theme, filteredItems),
              ),
            ],
          ),
    );
      },
    );
  }

  List<PopupMenuEntry<TimeRange>> _buildTimeRangeMenu(
      BuildContext context,
      ThemeData theme,
      TimeRange timeRange,
      ) {
    return [
      _timeRangeItem(
        theme: theme,
        value: TimeRange.week,
        current: timeRange,
        icon: Icons.view_week,
        label: 'This Week',
      ),
      _timeRangeItem(
        theme: theme,
        value: TimeRange.month,
        current: timeRange,
        icon: Icons.calendar_today,
        label: 'This Month',
      ),
      _timeRangeItem(
        theme: theme,
        value: TimeRange.year,
        current: timeRange,
        icon: Icons.date_range,
        label: 'This Year',
      ),
      _timeRangeItem(
        theme: theme,
        value: TimeRange.all,
        current: timeRange,
        icon: Icons.all_inclusive,
        label: 'All Time',
      ),
    ];
  }

  PopupMenuItem<TimeRange> _timeRangeItem({
    required ThemeData theme,
    required TimeRange value,
    required TimeRange current,
    required IconData icon,
    required String label,
  }) {
    final isActive = current == value;
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(
            icon,
            color: isActive ? theme.colorScheme.primary : null,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: isActive ? theme.colorScheme.primary : null,
              fontWeight: isActive ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
  }

  // ---- UI builders ----

  Widget _buildStatsBar(ThemeData theme, List<TaskScheduleEntity> allItems, List<TaskScheduleEntity> filteredItems, TimeRange timeRange) {
    final timeRangeText = timeRange == TimeRange.week
        ? 'This Week'
        : timeRange == TimeRange.month
        ? 'This Month'
        : timeRange == TimeRange.year
        ? 'This Year'
        : 'All Time';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
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
            child: _StatsChip(
              icon: Icons.event_available,
              label: timeRangeText,
              value: '${filteredItems.length}',
              color: theme.colorScheme.primary,
              theme: theme,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatsChip(
              icon: Icons.pending_actions,
              label: 'Upcoming',
              value: '${_countUpcoming(filteredItems)}',
              color: Colors.blue,
              theme: theme,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatsChip(
              icon: Icons.check_circle_outline,
              label: 'Completed',
              value: '${_countPast(filteredItems)}',
              color: theme.status.success,
              theme: theme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView(ThemeData theme, List<TaskScheduleEntity> allItems) {
    final viewMode = ref.watch(calendarViewModeProvider);

    switch (viewMode) {
      case CalendarViewMode.splitPanel:
        return ScheduleCalendarEnhanced(
          focusedDay: _focusedDay,
          selectedDay: _selectedDay,
          calendarFormat: _calendarFormat,
          items: allItems,
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onFormatChanged: (format) {
            setState(() {
              _calendarFormat = format;
            });
          },
          onPageChanged: (focusedDay) {
            setState(() {
              _focusedDay = focusedDay;
            });
          },
          onTaskTap: (task) {
            if (task.inspectionId != null && task.inspectionId!.isNotEmpty) {
              context.push('/inspections/detail/${task.inspectionId}');
            }
          },
        );

      case CalendarViewMode.dailyAgenda:
        return ScheduleCalendarDailyAgenda(
          focusedDay: _focusedDay,
          selectedDay: _selectedDay,
          calendarFormat: _calendarFormat,
          items: allItems,
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onFormatChanged: (format) {
            setState(() {
              _calendarFormat = format;
            });
          },
          onPageChanged: (focusedDay) {
            setState(() {
              _focusedDay = focusedDay;
            });
          },
          onTaskTap: (task) {
            if (task.inspectionId != null && task.inspectionId!.isNotEmpty) {
              context.push('/inspections/detail/${task.inspectionId}');
            }
          },
        );

      case CalendarViewMode.timeline:
        return ScheduleCalendarTimeline(
          focusedDay: _focusedDay,
          selectedDay: _selectedDay,
          calendarFormat: _calendarFormat,
          items: allItems,
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onFormatChanged: (format) {
            setState(() {
              _calendarFormat = format;
            });
          },
          onPageChanged: (focusedDay) {
            setState(() {
              _focusedDay = focusedDay;
            });
          },
          onTaskTap: (task) {
            if (task.inspectionId != null && task.inspectionId!.isNotEmpty) {
              context.push('/inspections/detail/${task.inspectionId}');
            }
          },
        );
    }
  }

  Widget _buildListView(
      ThemeData theme,
      List<TaskScheduleEntity> items,
      ) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 80,
              color: theme.colorScheme.primary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'No inspections found',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filter',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      );
    }

    final grouped = _groupItemsByDate(items);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: grouped.length,
      itemBuilder: (context, index) {
        final entry = grouped.entries.elementAt(index);
        final date = entry.key;
        final dayItems = entry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 8, bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _isToday(date)
                          ? theme.colorScheme.primaryContainer
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatDateHeader(date),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: _isToday(date)
                            ? theme.colorScheme.onPrimaryContainer
                            : theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${dayItems.length} inspection${dayItems.length != 1 ? 's' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // Items for this date
            ...dayItems.map(
                  (item) => _ScheduleCard(
                item: item,
                theme: theme,
                showDate: false,
              ),
            ),

            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  // ---- Helper methods (now using TaskScheduleEntity) ----

  List<TaskScheduleEntity> _filterItems(
      List<TaskScheduleEntity> items,
      TimeRange range,
      DateTime selectedDay,
      ) {
    final now = DateTime.now();

    switch (range) {
      case TimeRange.week:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return items.where((i) {
          final d = i.scheduledDate;
          return d.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
              d.isBefore(endOfWeek.add(const Duration(days: 1)));
        }).toList();

      case TimeRange.month:
        return items
            .where((i) =>
        i.scheduledDate.year == now.year &&
            i.scheduledDate.month == now.month)
            .toList();

      case TimeRange.year:
        return items
            .where((i) => i.scheduledDate.year == now.year)
            .toList();

      case TimeRange.all:
        return items;
    }
  }

  Map<DateTime, List<TaskScheduleEntity>> _groupItemsByDate(
      List<TaskScheduleEntity> items,
      ) {
    final grouped = <DateTime, List<TaskScheduleEntity>>{};

    for (final item in items) {
      final d = item.scheduledDate;
      final date = DateTime(d.year, d.month, d.day);

      grouped.putIfAbsent(date, () => []).add(item);
    }

    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Map.fromEntries(sortedEntries);
  }

  int _countUpcoming(List<TaskScheduleEntity> items) {
    final now = DateTime.now();
    return items.where((i) => i.scheduledDate.isAfter(now)).length;
  }

  int _countPast(List<TaskScheduleEntity> items) {
    final now = DateTime.now();
    return items.where((i) => i.scheduledDate.isBefore(now)).length;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _formatDateHeader(DateTime date) {
    if (_isToday(date)) return 'Today';

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    if (isSameDay(date, tomorrow)) return 'Tomorrow';

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    if (isSameDay(date, yesterday)) return 'Yesterday';

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
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
}

class _StatsChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final ThemeData theme;

  const _StatsChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final TaskScheduleEntity item;
  final ThemeData theme;
  final bool showDate;

  const _ScheduleCard({
    required this.item,
    required this.theme,
    this.showDate = true,
  });

  @override
  Widget build(BuildContext context) {
    final isPast = item.scheduledDate.isBefore(DateTime.now());
    final isToday = _isToday(item.scheduledDate);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isToday
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: isToday ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          // If linked to an inspection, navigate to its detail page.
          if (item.inspectionId != null && item.inspectionId!.isNotEmpty) {
            context.push('/inspections/detail/${item.inspectionId}');
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isPast
                      ? theme.status.success.withValues(alpha: 0.1)
                      : theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPast ? Icons.check_circle : Icons.schedule,
                  color: isPast ? theme.status.success : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.address.isEmpty
                          ? (item.title.isEmpty ? '(No address/title)' : item.title)
                          : item.address,
                      style: theme.textTheme.titleMedium?.copyWith(
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
                        if (showDate)
                          _InfoChip(
                            icon: Icons.calendar_today,
                            label: _formatDate(item.scheduledDate),
                            theme: theme,
                          ),
                        if (item.siteCode.isNotEmpty)
                          _InfoChip(
                            icon: Icons.location_on_outlined,
                            label: item.siteCode,
                            theme: theme,
                          ),
                        if (item.siteGrade.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getGradeColor(item.siteGrade)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              item.siteGrade,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: _getGradeColor(item.siteGrade),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Chevron
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _formatDate(DateTime date) {
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
    return '${months[date.month - 1]} ${date.day}';
  }

  Color _getGradeColor(String grade) {
    switch (grade.toLowerCase()) {
      case 'green':
        return theme.status.success;
      case 'amber':
        return theme.status.warning;
      case 'red':
        return theme.colorScheme.error;
      default:
        return theme.colorScheme.primary;
    }
  }
}

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
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
