import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';

import '../inspections/data/models/inspection.dart';
import '../inspections/data/repo/inspection_repo.dart';
import '../../shared/widgets/responsive_scaffold.dart';
import '../inspections/providers/user_profile_provider.dart';
import '../inspections/providers/app_badges_provider.dart';
import '../inspections/providers/app_badges_provider.dart';

/// Schedule view mode enum
enum ScheduleView { list, calendar }

/// Time range filter enum
enum TimeRange { week, month, year, all }

/// Provider for current schedule view
final scheduleViewProvider = StateProvider<ScheduleView>((ref) => ScheduleView.calendar);

/// Provider for current time range filter
final timeRangeProvider = StateProvider<TimeRange>((ref) => TimeRange.month);

/// Provider for selected date in calendar
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Inspection Schedule Page with calendar and list views
class InspectionSchedulePage extends ConsumerStatefulWidget {
  const InspectionSchedulePage({super.key});

  @override
  ConsumerState<InspectionSchedulePage> createState() => _InspectionSchedulePageState();
}

class _InspectionSchedulePageState extends ConsumerState<InspectionSchedulePage> {
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
    final badges = ref.watch(appBadgesProvider);
    final userProfile = ref.watch(userProfileProvider);
    final scheduleView = ref.watch(scheduleViewProvider);
    final timeRange = ref.watch(timeRangeProvider);

    final allInspections = ref.watch(inspectionRepoProvider).listAll();
    final filteredInspections = _filterInspections(allInspections, timeRange, _selectedDay);

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        actions: [
          // View mode toggle
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
            itemBuilder: (context) => [
              PopupMenuItem(
                value: TimeRange.week,
                child: Row(
                  children: [
                    Icon(
                      Icons.view_week,
                      color: timeRange == TimeRange.week
                          ? theme.colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'This Week',
                      style: TextStyle(
                        color: timeRange == TimeRange.week
                            ? theme.colorScheme.primary
                            : null,
                        fontWeight: timeRange == TimeRange.week
                            ? FontWeight.w600
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: TimeRange.month,
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      color: timeRange == TimeRange.month
                          ? theme.colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'This Month',
                      style: TextStyle(
                        color: timeRange == TimeRange.month
                            ? theme.colorScheme.primary
                            : null,
                        fontWeight: timeRange == TimeRange.month
                            ? FontWeight.w600
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: TimeRange.year,
                child: Row(
                  children: [
                    Icon(
                      Icons.date_range,
                      color: timeRange == TimeRange.year
                          ? theme.colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'This Year',
                      style: TextStyle(
                        color: timeRange == TimeRange.year
                            ? theme.colorScheme.primary
                            : null,
                        fontWeight: timeRange == TimeRange.year
                            ? FontWeight.w600
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: TimeRange.all,
                child: Row(
                  children: [
                    Icon(
                      Icons.all_inclusive,
                      color: timeRange == TimeRange.all
                          ? theme.colorScheme.primary
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'All Time',
                      style: TextStyle(
                        color: timeRange == TimeRange.all
                            ? theme.colorScheme.primary
                            : null,
                        fontWeight: timeRange == TimeRange.all
                            ? FontWeight.w600
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats summary bar
          _buildStatsBar(theme, allInspections, filteredInspections, timeRange),

          // Main content based on view mode
          Expanded(
            child: scheduleView == ScheduleView.calendar
                ? _buildCalendarView(theme, allInspections)
                : _buildListView(theme, filteredInspections),
          ),
        ],
      ),
      fab: FloatingActionButton.extended(
        onPressed: () => context.push('/inspection/new'),
        icon: const Icon(Icons.add),
        label: const Text('Schedule Inspection'),
      ),
      badges: badges.toRouteMap(),
      userProfile: userProfile,
      onSwitchTenant: (tenant) {
        ref.read(currentTenantProvider.notifier).switchTenant(tenant);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Switched to $tenant')),
        );
      },
    );
  }

  Widget _buildStatsBar(
      ThemeData theme,
      List<Inspection> allInspections,
      List<Inspection> filteredInspections,
      TimeRange timeRange,
      ) {
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
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
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
              value: '${filteredInspections.length}',
              color: theme.colorScheme.primary,
              theme: theme,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatsChip(
              icon: Icons.pending_actions,
              label: 'Upcoming',
              value: '${_countUpcoming(filteredInspections)}',
              color: Colors.blue,
              theme: theme,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatsChip(
              icon: Icons.check_circle_outline,
              label: 'Completed',
              value: '${_countPast(filteredInspections)}',
              color: Colors.green,
              theme: theme,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarView(ThemeData theme, List<Inspection> inspections) {
    return Column(
      children: [
        // Calendar widget
        Card(
          margin: const EdgeInsets.all(16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 1,
            ),
          ),
          child: TableCalendar<Inspection>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            eventLoader: (day) => _getInspectionsForDay(inspections, day),
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarStyle: CalendarStyle(
              outsideDaysVisible: true,
              weekendTextStyle: TextStyle(color: theme.colorScheme.error),
              holidayTextStyle: TextStyle(color: theme.colorScheme.error),
              selectedDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.3),
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
              _focusedDay = focusedDay;
            },
          ),
        ),

        // Selected day inspections
        Expanded(
          child: _buildSelectedDayInspections(theme, inspections),
        ),
      ],
    );
  }

  Widget _buildSelectedDayInspections(ThemeData theme, List<Inspection> allInspections) {
    final dayInspections = _getInspectionsForDay(allInspections, _selectedDay);

    if (dayInspections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No inspections scheduled',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatSelectedDate(_selectedDay),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            '${_formatSelectedDate(_selectedDay)} • ${dayInspections.length} inspection${dayInspections.length != 1 ? 's' : ''}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: dayInspections.length,
            itemBuilder: (context, index) => _ScheduleCard(
              inspection: dayInspections[index],
              theme: theme,
              showDate: false,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListView(ThemeData theme, List<Inspection> inspections) {
    if (inspections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'No inspections found',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filter',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ],
        ),
      );
    }

    // Group inspections by date
    final groupedInspections = _groupInspectionsByDate(inspections);

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groupedInspections.length,
      itemBuilder: (context, index) {
        final entry = groupedInspections.entries.elementAt(index);
        final date = entry.key;
        final dayInspections = entry.value;

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
                    '${dayInspections.length} inspection${dayInspections.length != 1 ? 's' : ''}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // Inspections for this date
            ...dayInspections.map((inspection) => _ScheduleCard(
              inspection: inspection,
              theme: theme,
              showDate: false,
            )),

            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  // Helper methods
  List<Inspection> _filterInspections(
      List<Inspection> inspections,
      TimeRange range,
      DateTime selectedDay,
      ) {
    final now = DateTime.now();

    switch (range) {
      case TimeRange.week:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return inspections.where((i) {
          return i.serviceDate.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
              i.serviceDate.isBefore(endOfWeek.add(const Duration(days: 1)));
        }).toList();

      case TimeRange.month:
        return inspections.where((i) {
          return i.serviceDate.year == now.year && i.serviceDate.month == now.month;
        }).toList();

      case TimeRange.year:
        return inspections.where((i) {
          return i.serviceDate.year == now.year;
        }).toList();

      case TimeRange.all:
        return inspections;
    }
  }

  List<Inspection> _getInspectionsForDay(List<Inspection> inspections, DateTime day) {
    return inspections.where((i) => isSameDay(i.serviceDate, day)).toList()
      ..sort((a, b) => a.serviceDate.compareTo(b.serviceDate));
  }

  Map<DateTime, List<Inspection>> _groupInspectionsByDate(List<Inspection> inspections) {
    final grouped = <DateTime, List<Inspection>>{};

    for (final inspection in inspections) {
      final date = DateTime(
        inspection.serviceDate.year,
        inspection.serviceDate.month,
        inspection.serviceDate.day,
      );

      grouped.putIfAbsent(date, () => []).add(inspection);
    }

    // Sort by date
    final sortedEntries = grouped.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Map.fromEntries(sortedEntries);
  }

  int _countUpcoming(List<Inspection> inspections) {
    final now = DateTime.now();
    return inspections.where((i) => i.serviceDate.isAfter(now)).length;
  }

  int _countPast(List<Inspection> inspections) {
    final now = DateTime.now();
    return inspections.where((i) => i.serviceDate.isBefore(now)).length;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  String _formatSelectedDate(DateTime date) {
    if (_isToday(date)) return 'Today';

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    if (isSameDay(date, tomorrow)) return 'Tomorrow';

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    if (isSameDay(date, yesterday)) return 'Yesterday';

    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatDateHeader(DateTime date) {
    if (_isToday(date)) return 'Today';

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    if (isSameDay(date, tomorrow)) return 'Tomorrow';

    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    if (isSameDay(date, yesterday)) return 'Yesterday';

    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
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
  final Inspection inspection;
  final ThemeData theme;
  final bool showDate;

  const _ScheduleCard({
    required this.inspection,
    required this.theme,
    this.showDate = true,
  });

  @override
  Widget build(BuildContext context) {
    final isPast = inspection.serviceDate.isBefore(DateTime.now());
    final isToday = _isToday(inspection.serviceDate);

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
        onTap: () => context.push('/detail/${inspection.id}'),
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
                      ? Colors.green.withOpacity(0.1)
                      : theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isPast ? Icons.check_circle : Icons.schedule,
                  color: isPast ? Colors.green : theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inspection.address.isEmpty
                          ? '(No address)'
                          : inspection.address,
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
                            label: _formatDate(inspection.serviceDate),
                            theme: theme,
                          ),
                        if (inspection.siteCode.isNotEmpty)
                          _InfoChip(
                            icon: Icons.location_on_outlined,
                            label: inspection.siteCode,
                            theme: theme,
                          ),
                        if (inspection.siteGrade.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getGradeColor(inspection.siteGrade)
                                  .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              inspection.siteGrade,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: _getGradeColor(inspection.siteGrade),
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
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];

    return '${months[date.month - 1]} ${date.day}';
  }

  Color _getGradeColor(String grade) {
    switch (grade.toLowerCase()) {
      case 'green':
        return Colors.green;
      case 'amber':
        return Colors.orange;
      case 'red':
        return Colors.red;
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