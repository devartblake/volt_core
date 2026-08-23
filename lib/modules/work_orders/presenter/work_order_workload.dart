import '../domain/entities/work_order_entity.dart';

/// Dispatch-ready counts derived from the current tenant's work-order queue.
///
/// Keeping the calculation independent of the page makes the definitions of
/// "open", "due today", and "overdue" consistent across future dashboards.
class WorkOrderWorkload {
  const WorkOrderWorkload({
    required this.open,
    required this.dueToday,
    required this.overdue,
    required this.unassigned,
  });

  final int open;
  final int dueToday;
  final int overdue;
  final int unassigned;

  factory WorkOrderWorkload.fromOrders(
    Iterable<WorkOrderEntity> orders, {
    required DateTime today,
  }) {
    final dayStart = DateTime(today.year, today.month, today.day);
    final nextDay = dayStart.add(const Duration(days: 1));
    var open = 0;
    var dueToday = 0;
    var overdue = 0;
    var unassigned = 0;

    for (final order in orders) {
      if (_isTerminal(order.status)) continue;
      open++;
      if (order.assignedToUserId == null || order.assignedToUserId!.isEmpty) {
        unassigned++;
      }
      final scheduledFor = order.scheduledFor;
      if (scheduledFor == null) continue;
      if (!scheduledFor.isBefore(dayStart) && scheduledFor.isBefore(nextDay)) {
        dueToday++;
      } else if (scheduledFor.isBefore(dayStart)) {
        overdue++;
      }
    }

    return WorkOrderWorkload(
      open: open,
      dueToday: dueToday,
      overdue: overdue,
      unassigned: unassigned,
    );
  }
}

bool _isTerminal(WorkOrderStatus status) =>
    status == WorkOrderStatus.completed || status == WorkOrderStatus.cancelled;
