import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/customers/customer_site_repository.dart';
import 'package:voltcore/modules/work_orders/domain/entities/work_order_entity.dart';
import 'package:voltcore/modules/work_orders/domain/entities/work_order_event.dart';
import 'package:voltcore/modules/work_orders/presenter/pages/work_order_form_page.dart';
import 'package:voltcore/modules/work_orders/presenter/work_order_providers.dart';
import 'package:voltcore/providers/equipment_providers.dart';

void main() {
  testWidgets('shows database audit activity on an existing job', (tester) async {
    final order = WorkOrderEntity(
      id: 'job-1',
      tenantId: 'tenant-1',
      title: 'Inspect transfer switch',
      status: WorkOrderStatus.scheduled,
      priority: WorkOrderPriority.high,
      scheduledFor: DateTime.utc(2026, 8, 25),
      createdAt: DateTime.utc(2026, 8, 20),
      updatedAt: DateTime.utc(2026, 8, 21),
    );
    final events = [
      WorkOrderEvent(
        id: 'event-1',
        tenantId: 'tenant-1',
        workOrderId: order.id,
        type: WorkOrderEventType.statusChanged,
        fromStatus: 'draft',
        toStatus: 'scheduled',
        createdAt: DateTime.utc(2026, 8, 21),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          workOrderProvider(order.id).overrideWith((ref) async => order),
          workOrderEventsProvider(order.id).overrideWith((ref) async => events),
          customerSiteDirectoryProvider.overrideWith(
            (ref) async => const CustomerSiteDirectory(),
          ),
          equipmentListProvider.overrideWith((ref) async => const []),
          workOrderAssigneesProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(home: WorkOrderFormPage(id: 'job-1')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Activity history'),
      300,
    );

    expect(find.text('Activity history'), findsOneWidget);
    expect(
      find.text('Status changed from Draft to Scheduled'),
      findsOneWidget,
    );
  });
}
