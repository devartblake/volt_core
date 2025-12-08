import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../domain/entities/task_schedule_entity.dart';

class ScheduleCalendar extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final CalendarFormat calendarFormat;
  final List<TaskScheduleEntity> items;

  final void Function(DateTime selectedDay, DateTime focusedDay) onDaySelected;
  final void Function(CalendarFormat format) onFormatChanged;
  final void Function(DateTime focusedDay) onPageChanged;

  const ScheduleCalendar({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.calendarFormat,
    required this.items,
    required this.onDaySelected,
    required this.onFormatChanged,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TableCalendar<TaskScheduleEntity>(
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
      onDaySelected: onDaySelected,
      onFormatChanged: onFormatChanged,
      onPageChanged: onPageChanged,
    );
  }

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
}
