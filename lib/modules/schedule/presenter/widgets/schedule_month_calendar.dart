import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../domain/entities/task_schedule_entity.dart';
import 'calendar_view_mode.dart';
import 'schedule_calendar.dart';
import 'schedule_calendar_daily_agenda.dart';
import 'schedule_calendar_timeline.dart';

/// The month calendar in whichever of the three layouts is chosen.
class ScheduleMonthCalendar extends StatelessWidget {
  const ScheduleMonthCalendar({
    super.key,
    required this.mode,
    required this.focusedDay,
    required this.selectedDay,
    required this.calendarFormat,
    required this.items,
    required this.onDaySelected,
    required this.onFormatChanged,
    required this.onPageChanged,
    required this.onTaskTap,
    this.onAssign,
  });

  final CalendarViewMode mode;
  final DateTime focusedDay;
  final DateTime selectedDay;
  final CalendarFormat calendarFormat;
  final List<TaskScheduleEntity> items;
  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final ValueChanged<CalendarFormat> onFormatChanged;
  final ValueChanged<DateTime> onPageChanged;
  final ValueChanged<TaskScheduleEntity> onTaskTap;

  /// Assign action shown on task cards in every layout.
  final ValueChanged<TaskScheduleEntity>? onAssign;

  @override
  Widget build(BuildContext context) {
    switch (mode) {
      case CalendarViewMode.splitPanel:
        return ScheduleCalendarEnhanced(
          focusedDay: focusedDay,
          selectedDay: selectedDay,
          calendarFormat: calendarFormat,
          items: items,
          onDaySelected: onDaySelected,
          onFormatChanged: onFormatChanged,
          onPageChanged: onPageChanged,
          onTaskTap: onTaskTap,
          onAssign: onAssign,
        );
      case CalendarViewMode.dailyAgenda:
        return ScheduleCalendarDailyAgenda(
          focusedDay: focusedDay,
          selectedDay: selectedDay,
          calendarFormat: calendarFormat,
          items: items,
          onDaySelected: onDaySelected,
          onFormatChanged: onFormatChanged,
          onPageChanged: onPageChanged,
          onTaskTap: onTaskTap,
          onAssign: onAssign,
        );
      case CalendarViewMode.timeline:
        return ScheduleCalendarTimeline(
          focusedDay: focusedDay,
          selectedDay: selectedDay,
          calendarFormat: calendarFormat,
          items: items,
          onDaySelected: onDaySelected,
          onFormatChanged: onFormatChanged,
          onPageChanged: onPageChanged,
          onTaskTap: onTaskTap,
          onAssign: onAssign,
        );
    }
  }
}
