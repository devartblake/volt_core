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

/// Converts a row read from `public.work_orders` to the offline-first domain
/// model. Unknown enum values degrade safely, which keeps a newly deployed
/// server value from making the local job list unusable.
WorkOrderEntity workOrderFromSupabaseJson(Map<String, dynamic> row) {
  return WorkOrderEntity(
    id: (row['id'] ?? '').toString(),
    tenantId: (row['tenant_id'] ?? '').toString(),
    title: (row['title'] ?? '').toString(),
    status: _statusFromName((row['status'] ?? '').toString()),
    priority: _priorityFromName((row['priority'] ?? '').toString()),
    customerId: _nullableString(row['customer_id']),
    siteId: _nullableString(row['site_id']),
    assetId: _nullableString(row['asset_id']),
    assignedToUserId: _nullableString(row['assigned_to_user_id']),
    scheduledFor: _dateTime(row['scheduled_for']),
    description: (row['description'] ?? '').toString(),
    createdAt: _dateTime(row['created_at']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    updatedAt: _dateTime(row['updated_at']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
}

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

DateTime? _dateTime(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString())?.toUtc();

WorkOrderStatus _statusFromName(String name) {
  for (final status in WorkOrderStatus.values) {
    if (status.name == name) return status;
  }
  return WorkOrderStatus.draft;
}

WorkOrderPriority _priorityFromName(String name) {
  for (final priority in WorkOrderPriority.values) {
    if (priority.name == name) return priority;
  }
  return WorkOrderPriority.normal;
}
