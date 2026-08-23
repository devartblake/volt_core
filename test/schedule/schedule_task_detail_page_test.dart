import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/schedule/domain/entities/task_schedule_entity.dart';
import 'package:voltcore/modules/schedule/presenter/controllers/schedule_controller.dart';
import 'package:voltcore/modules/schedule/presenter/pages/schedule_task_detail_page.dart';

TaskScheduleEntity _task() => TaskScheduleEntity(
  id: 'schedule-1',
  scheduledAt: DateTime.utc(2026, 8, 25, 9),
  scheduledDate: DateTime.utc(2026, 8, 25),
  createdAt: DateTime.utc(2026, 8, 20),
  updatedAt: DateTime.utc(2026, 8, 20),
  title: 'Generator maintenance',
  description: 'Quarterly load test',
  sourceType: 'maintenance_record',
  sourceId: 'maintenance-record-1',
  siteCode: 'Q844',
  address: '952 Flushing Ave, Brooklyn NY 11206',
  status: 'scheduled',
);

TaskScheduleEntity _cancelledTask() => _task().copyWith(status: 'cancelled');

void main() {
  testWidgets('displays the scheduled record before offering its source link', (
    tester,
  ) async {
    final task = _task();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleTaskProvider(task.id).overrideWith((ref) async => task),
        ],
        child: const MaterialApp(
          home: ScheduleTaskDetailPage(id: 'schedule-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Generator maintenance'), findsOneWidget);
    expect(find.text('Scheduled for'), findsOneWidget);
    expect(find.text('Quarterly load test'), findsOneWidget);
    expect(find.text('Open source record'), findsOneWidget);
  });

  testWidgets('offers a cancelled task a reschedule and permanent-delete path',
      (tester) async {
    final task = _cancelledTask();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          scheduleTaskProvider(task.id).overrideWith((ref) async => task),
        ],
        child: const MaterialApp(
          home: ScheduleTaskDetailPage(id: 'schedule-1'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Reschedule task'), findsOneWidget);
    expect(find.text('Delete task permanently'), findsOneWidget);
    expect(find.text('Cancel task'), findsNothing);
  });
}
