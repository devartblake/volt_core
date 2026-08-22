import '../../domain/entities/work_order_entity.dart';
const kWorkOrdersTable = 'work_orders';
Map<String, dynamic> workOrderToSupabaseJson(WorkOrderEntity order) => {
  'id': order.id,
  'tenant_id': order.tenantId,
  'title': order.title,
  'status': order.status.name,
  'priority': order.priority.name,
  'customer_id': order.customerId,
  'site_id': order.siteId,
  'asset_id': order.assetId,
  'assigned_to_user_id': order.assignedToUserId,
  'scheduled_for': order.scheduledFor?.toIso8601String(),
  'description': order.description,
  'created_at': order.createdAt.toIso8601String(),
  'updated_at': order.updatedAt.toIso8601String(),
};
