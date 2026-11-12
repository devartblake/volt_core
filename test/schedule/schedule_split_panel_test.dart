import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:voltcore/modules/schedule/domain/entities/task_schedule_entity.dart';
import 'package:voltcore/modules/schedule/presenter/widgets/schedule_calendar.dart';

TaskScheduleEntity _task(String title, DateTime at) => TaskScheduleEntity(
      id: title,
      scheduledAt: at,
      scheduledDate: DateTime(at.year, at.month, at.day),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
      title: title,
      sourceType: 'manual',
    );

Widget _panel(DateTime selected, List<TaskScheduleEntity> items) => MaterialApp(
      home: Scaffold(
        body: ScheduleCalendarEnhanced(
          focusedDay: selected,
          selectedDay: selected,
          calendarFormat: CalendarFormat.month,
          items: items,
          onDaySelected: (_, __) {},
          onFormatChanged: (_) {},
          onPageChanged: (_) {},
        ),
      ),
    );

void main() {
  testWidgets('a marked day in the past lists its tasks when selected',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final past = DateTime.now().subtract(const Duration(days: 40));
    final day = DateTime(past.year, past.month, past.day, 9);
    await tester.pumpWidget(_panel(day, [_task('X460 service', day)]));
    await tester.pump();

    expect(find.text('X460 service'), findsOneWidget);
  });
}
