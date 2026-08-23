import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/work_orders/domain/entities/work_order_event.dart';
import 'package:voltcore/modules/work_orders/infra/datasources/work_order_event_remote_datasource.dart';

void main() {
  test('maps a status-change audit row from Supabase', () {
    final event = workOrderEventFromSupabaseJson({
      'id': 'event-1',
      'tenant_id': 'tenant-1',
      'work_order_id': 'work-order-1',
      'event_type': 'status_changed',
      'actor_user_id': 'user-1',
      'from_status': 'scheduled',
      'to_status': 'inProgress',
      'created_at': '2026-08-23T16:00:00Z',
    });

    expect(event.type, WorkOrderEventType.statusChanged);
    expect(event.fromStatus, 'scheduled');
    expect(event.toStatus, 'inProgress');
    expect(event.createdAt, DateTime.utc(2026, 8, 23, 16));
  });

  test('maps missing optional audit values safely', () {
    final event = workOrderEventFromSupabaseJson({
      'id': 'event-2',
      'tenant_id': 'tenant-1',
      'work_order_id': 'work-order-1',
      'event_type': 'assignment_changed',
      'created_at': 'not-a-date',
    });

    expect(event.type, WorkOrderEventType.assignmentChanged);
    expect(event.actorUserId, isNull);
    expect(event.assignedToUserId, isNull);
    expect(event.createdAt, DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
  });
}
