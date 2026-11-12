import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/schedule/domain/entities/task_schedule_entity.dart';
import 'package:voltcore/modules/schedule/presenter/widgets/schedule_day_list.dart';
import 'package:voltcore/modules/schedule/presenter/widgets/schedule_job_card.dart';

TaskScheduleEntity _task(int i) {
  final at = DateTime(2030, 1, 1 + i ~/ 5, 8 + i % 5);
  return TaskScheduleEntity(
    id: 't$i',
    scheduledAt: at,
    scheduledDate: DateTime(at.year, at.month, at.day),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    title: 'Job $i',
    sourceType: 'manual',
    siteCode: 'S-$i',
    status: 'scheduled',
  );
}

void main() {
  testWidgets('schedule day list builds cards lazily (300 tasks)', (t) async {
    t.view.physicalSize = const Size(400, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) return;
      prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);

    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ScheduleDayList(
            tasks: [for (var i = 0; i < 300; i++) _task(i)], names: const {}),
      ),
    ));
    final built = find.byType(ScheduleJobCard).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(60));
    await t.scrollUntilVisible(find.text('Job 299'), 500,
        maxScrolls: 600, scrollable: find.byType(Scrollable).first);
    expect(find.text('Job 299'), findsOneWidget);
  });
}
