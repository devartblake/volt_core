import '../../domain/entities/work_order_entity.dart';

abstract class WorkOrderRepository {
  Future<List<WorkOrderEntity>> list();
  Future<WorkOrderEntity?> getById(String id);

  Future<WorkOrderEntity> create({
    required String title,
    WorkOrderPriority priority = WorkOrderPriority.normal,
    String? customerId,
    String? siteId,
    String? assetId,
    String? assignedToUserId,
    DateTime? scheduledFor,
    String description = '',
  });

  Future<WorkOrderEntity> save(WorkOrderEntity order);
  Future<WorkOrderEntity> transition(String id, WorkOrderStatus status);
}
