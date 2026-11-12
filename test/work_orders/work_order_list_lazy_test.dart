import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/schedule/domain/entities/task_schedule_entity.dart';
import 'package:voltcore/modules/schedule/domain/usecases/load_schedule_usecase.dart';
import 'package:voltcore/modules/schedule/presenter/controllers/schedule_controller.dart';
import 'package:voltcore/modules/work_orders/domain/entities/work_order_entity.dart';
import 'package:voltcore/modules/work_orders/presenter/pages/work_order_list_page.dart';
import 'package:voltcore/modules/work_orders/presenter/work_order_providers.dart';

class _NoSchedule implements LoadScheduleUseCase {
  @override
  Future<List<TaskScheduleEntity>> call(LoadScheduleParams params) async =>
      const [];
}

void main() {
  testWidgets('jobs list builds rows lazily (300 jobs)', (t) async {
    t.view.physicalSize = const Size(400, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) return;
      prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);

    final orders = [
      for (var i = 0; i < 300; i++)
        WorkOrderEntity(
          id: 'w$i',
          tenantId: 't',
          title: 'Job number $i',
          status: WorkOrderStatus.scheduled,
          priority: WorkOrderPriority.normal,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
    ];
    await t.pumpWidget(ProviderScope(
      overrides: [
        workOrderListProvider.overrideWith((ref) async => orders),
        scheduleControllerProvider
            .overrideWith((ref) => ScheduleController(_NoSchedule())),
      ],
      child: const MaterialApp(home: WorkOrderListPage()),
    ));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
    final built = find.byType(ListTile).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(60));
    await t.scrollUntilVisible(find.text('Job number 299'), 500,
        maxScrolls: 600,
        scrollable: find
            .byWidgetPredicate(
                (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
            .first);
    expect(find.text('Job number 299'), findsOneWidget);
  });
}
