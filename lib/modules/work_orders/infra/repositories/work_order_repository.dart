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

    /// Set when the job was raised from a fleet asset receipt: the van, and the
    /// receipt line that reported the problem.
    String? vehicleId,
    String? assetCheckLineId,
    String? assignedToUserId,
    DateTime? scheduledFor,
    String description = '',
  });

  Future<WorkOrderEntity> save(WorkOrderEntity order);
  Future<WorkOrderEntity> transition(String id, WorkOrderStatus status);
}
