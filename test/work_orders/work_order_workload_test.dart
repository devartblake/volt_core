import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/work_orders/domain/entities/work_order_entity.dart';
import 'package:voltcore/modules/work_orders/presenter/work_order_workload.dart';

WorkOrderEntity _order({
  required String id,
  required WorkOrderStatus status,
  DateTime? scheduledFor,
  String? assignedToUserId,
}) => WorkOrderEntity(
  id: id,
  tenantId: 'tenant-1',
  title: id,
  status: status,
  priority: WorkOrderPriority.normal,
  scheduledFor: scheduledFor,
  assignedToUserId: assignedToUserId,
  createdAt: DateTime.utc(2026, 8, 1),
  updatedAt: DateTime.utc(2026, 8, 1),
);

void main() {
  test('summarizes active dispatch work without counting terminal records', () {
    final workload = WorkOrderWorkload.fromOrders(
      [
        _order(
          id: 'today',
          status: WorkOrderStatus.scheduled,
          scheduledFor: DateTime(2026, 8, 23),
          assignedToUserId: 'tech-1',
        ),
        _order(
          id: 'late',
          status: WorkOrderStatus.inProgress,
          scheduledFor: DateTime(2026, 8, 22),
        ),
        _order(id: 'draft', status: WorkOrderStatus.draft),
        _order(
          id: 'done',
          status: WorkOrderStatus.completed,
          scheduledFor: DateTime(2026, 8, 20),
        ),
        _order(id: 'cancelled', status: WorkOrderStatus.cancelled),
      ],
      today: DateTime(2026, 8, 23, 14),
    );

    expect(workload.open, 3);
    expect(workload.dueToday, 1);
    expect(workload.overdue, 1);
    expect(workload.unassigned, 2);
  });
}
