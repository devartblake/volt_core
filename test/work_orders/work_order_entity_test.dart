import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/work_orders/domain/entities/work_order_entity.dart';

WorkOrderEntity _order(WorkOrderStatus status) => WorkOrderEntity(
  id: 'work-order-1',
  tenantId: 'tenant-1',
  title: 'Test transfer switch',
  status: status,
  priority: WorkOrderPriority.normal,
  createdAt: DateTime(2026, 8, 22),
  updatedAt: DateTime(2026, 8, 22),
);

void main() {
  group('WorkOrderEntity lifecycle', () {
    test('copyWith can clear optional operational links', () {
      final linked = _order(WorkOrderStatus.draft).copyWith(
        customerId: 'customer-1',
        siteId: 'site-1',
        assetId: 'asset-1',
        assignedToUserId: 'tech-1',
        scheduledFor: DateTime.utc(2026, 8, 23),
      );

      final cleared = linked.copyWith(
        clearCustomerId: true,
        clearSiteId: true,
        clearAssetId: true,
        clearAssignedToUserId: true,
        clearScheduledFor: true,
      );

      expect(cleared.customerId, isNull);
      expect(cleared.siteId, isNull);
      expect(cleared.assetId, isNull);
      expect(cleared.assignedToUserId, isNull);
      expect(cleared.scheduledFor, isNull);
    });

    test('moves through dispatch lifecycle in order', () {
      final scheduled = _order(WorkOrderStatus.draft)
          .transitionTo(WorkOrderStatus.scheduled);
      final active = scheduled.transitionTo(WorkOrderStatus.inProgress);
      final complete = active.transitionTo(WorkOrderStatus.completed);

      expect(complete.status, WorkOrderStatus.completed);
      expect(complete.allowedNextStatuses, isEmpty);
    });

    test(
      'does not infer completion from scheduling or allow terminal moves',
      () {
        final scheduled = _order(WorkOrderStatus.scheduled);
        expect(scheduled.canTransitionTo(WorkOrderStatus.completed), isFalse);
        expect(
          () => scheduled.transitionTo(WorkOrderStatus.completed),
          throwsStateError,
        );
        expect(
          () =>
              _order(WorkOrderStatus.completed)
                  .transitionTo(WorkOrderStatus.inProgress),
          throwsStateError,
        );
      },
    );

    test('allows cancellation before completion', () {
      expect(
        _order(WorkOrderStatus.draft)
            .canTransitionTo(WorkOrderStatus.cancelled),
        isTrue,
      );
      expect(
        _order(WorkOrderStatus.inProgress)
            .transitionTo(WorkOrderStatus.cancelled)
            .status,
        WorkOrderStatus.cancelled,
      );
    });
  });
}
