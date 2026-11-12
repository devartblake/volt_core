import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../dashboard/presenter/dashboard_providers.dart';
import '../../domain/entities/task_schedule_entity.dart';
import '../../domain/schedule_view_logic.dart';
import '../controllers/schedule_assignment.dart';
import '../controllers/schedule_controller.dart';
import '../controllers/schedule_view_providers.dart';
import '../schedule_navigation.dart';
import '../widgets/assign_technician_sheet.dart';
import '../widgets/calendar_view_mode.dart';
import '../widgets/schedule_day_list.dart';
import '../widgets/schedule_filters_bar.dart';
import '../widgets/schedule_menus.dart';
import '../widgets/schedule_month_calendar.dart';
import '../widgets/schedule_stats_bar.dart';

export '../controllers/schedule_view_providers.dart';

/// Schedule with Day / Week / Month views and a technician filter.
///
/// [technician] pre-selects the filter (a user id or [unassignedFilter]) and
/// opens today's Day view; the dashboard's "Who is on what today" uses it.
class SchedulePage extends ConsumerStatefulWidget {
  const SchedulePage({super.key, this.technician});

  final String? technician;

  @override
  ConsumerState<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends ConsumerState<SchedulePage> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  late ScheduleSpan _span;
  String? _technician;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _technician = _clean(widget.technician);
    _span = _technician != null
        ? ScheduleSpan.day
        : ref.read(scheduleSpanProvider);
  }

  @override
  void didUpdateWidget(SchedulePage old) {
    super.didUpdateWidget(old);
    if (old.technician != widget.technician) {
      _technician = _clean(widget.technician);
      if (_technician != null) {
        _span = ScheduleSpan.day;
        _focusedDay = DateTime.now();
      }
    }
  }

  static String? _clean(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v.trim();

  void _setSpan(ScheduleSpan span) {
    setState(() => _span = span);
    ref.read(scheduleSpanProvider.notifier).state = span;
  }

  @override
  Widget build(BuildContext context) {
    final scheduleView = ref.watch(scheduleViewProvider);
    final timeRange = ref.watch(timeRangeProvider);
    final scheduleState = ref.watch(scheduleControllerProvider);
    final isMonth = _span == ScheduleSpan.month;

    return scheduleState.when(
      loading: () =>
          const AppPage(title: 'Schedule', body: LoadingIndicator()),
      error: (err, st) => AppPage(
        title: 'Schedule',
        body: Center(child: Text('Error loading schedule: $err')),
      ),
      data: (allItems) {
        final names = ref.watch(dashboardTechniciansProvider).value?.names ??
            const <String, String>{};
        final canAssign = ref.watch(canAssignScheduleProvider);
        final listMode = isMonth && scheduleView == ScheduleView.list;

        // Tasks in the period being looked at, before the technician filter.
        final inView = !isMonth
            ? tasksInSpan(allItems, _span, _focusedDay)
            : listMode
                ? _filterByTimeRange(allItems, timeRange)
                : tasksInSpan(allItems, ScheduleSpan.month, _focusedDay);
        final visible = filterByTechnician(inView, _technician);

        final chipIds = technicianIdsIn(inView);
        if (_technician != null &&
            _technician != unassignedFilter &&
            !chipIds.contains(_technician)) {
          chipIds.add(_technician!);
        }

        return AppPage(
          title: 'Schedule',
          actions: [
            if (isMonth) ...[
              const CalendarLayoutMenu(),
              IconButton(
                icon: Icon(scheduleView == ScheduleView.calendar
                    ? Icons.list
                    : Icons.calendar_month),
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
              if (listMode) const TimeRangeMenu(),
            ],
          ],
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
                child: SizedBox(
                  width: double.infinity,
                  child: ScheduleSpanSelector(span: _span, onChanged: _setSpan),
                ),
              ),
              TechnicianFilterChips(
                technicianIds: chipIds,
                names: names,
                selected: _technician,
                onSelected: (v) => setState(() => _technician = v),
              ),
              if (!isMonth)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: ScheduleRangeNav(
                    span: _span,
                    focus: _focusedDay,
                    onChanged: (d) => setState(() {
                      _focusedDay = d;
                      _selectedDay = d;
                    }),
                  ),
                ),
              ScheduleStatsBar(
                rangeLabel: isMonth
                    ? (listMode ? timeRangeLabel(timeRange) : 'This Month')
                    : (_span == ScheduleSpan.day ? 'Day' : 'Week'),
                items: visible,
              ),
              Expanded(
                child: isMonth && !listMode
                    ? ScheduleMonthCalendar(
                        mode: ref.watch(calendarViewModeProvider),
                        focusedDay: _focusedDay,
                        selectedDay: _selectedDay,
                        calendarFormat: _calendarFormat,
                        items: filterByTechnician(allItems, _technician),
                        onDaySelected: (selected, focused) => setState(() {
                          _selectedDay = selected;
                          _focusedDay = focused;
                        }),
                        onFormatChanged: (f) =>
                            setState(() => _calendarFormat = f),
                        onPageChanged: (f) => setState(() => _focusedDay = f),
                        onTaskTap: (task) => openScheduledTask(context, task),
                        onAssign: canAssign
                            ? (task) =>
                                showAssignTechnicianSheet(context, ref, task)
                            : null,
                      )
                    : ScheduleDayList(
                        tasks: visible,
                        names: names,
                        onAssign: canAssign
                            ? (task) =>
                                showAssignTechnicianSheet(context, ref, task)
                            : null,
                        emptyTitle: _technician == null
                            ? 'No inspections found'
                            : 'Nothing for this technician',
                        emptyMessage: _technician == null
                            ? 'Try adjusting your filter'
                            : 'Try another day or choose All.',
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<TaskScheduleEntity> _filterByTimeRange(
    List<TaskScheduleEntity> items,
    TimeRange range,
  ) {
    final now = DateTime.now();
    switch (range) {
      case TimeRange.week:
        return tasksInSpan(items, ScheduleSpan.week, now);
      case TimeRange.month:
        return items
            .where((i) =>
                i.scheduledDate.year == now.year &&
                i.scheduledDate.month == now.month)
            .toList();
      case TimeRange.year:
        return items.where((i) => i.scheduledDate.year == now.year).toList();
      case TimeRange.all:
        return items;
    }
  }
}
