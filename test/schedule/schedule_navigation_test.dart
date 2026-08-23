import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voltcore/core/constants/route_paths.dart';
import 'package:voltcore/modules/schedule/domain/entities/task_schedule_entity.dart';
import 'package:voltcore/modules/schedule/presenter/schedule_navigation.dart';

TaskScheduleEntity _task() => TaskScheduleEntity(
  id: 'schedule-1',
  scheduledAt: DateTime.utc(2026, 8, 25),
  scheduledDate: DateTime.utc(2026, 8, 25),
  createdAt: DateTime.utc(2026, 8, 20),
  updatedAt: DateTime.utc(2026, 8, 20),
  title: 'Generator maintenance',
  sourceType: 'maintenance_record',
  sourceId: 'maintenance-record-1',
);

void main() {
  testWidgets('maintenance-record schedule rows open scheduled-task detail', (
    tester,
  ) async {
    final task = _task();
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: TextButton(
              onPressed: () => openScheduledTask(context, task),
              child: const Text('Open task'),
            ),
          ),
        ),
        GoRoute(
          path: '/schedule/detail/:id',
          name: RouteNames.scheduleTaskDetail,
          builder: (_, state) => Scaffold(
            body: Text('Scheduled task ${state.pathParameters['id']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('Open task'));
    await tester.pumpAndSettle();

    expect(find.text('Scheduled task schedule-1'), findsOneWidget);
  });
}
