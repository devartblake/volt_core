import 'package:flutter/foundation.dart';

/// Lifecycle states shared by every field-service work order.
///
/// These names intentionally match the database enum planned for Phase 2. A
/// work order is not considered complete merely because its scheduled date is
/// in the past; completion is an explicit workflow transition.
enum WorkOrderStatus { draft, scheduled, inProgress, completed, cancelled }

/// Dispatch urgency, independent of lifecycle state.
enum WorkOrderPriority { low, normal, high, urgent }

/// A tenant-scoped field-service work order.
///
/// The Phase 2 database migration will persist this model. Keeping the state
/// machine in the domain layer first prevents schedule screens and future
/// template packs from inventing conflicting lifecycle rules.
@immutable
class WorkOrderEntity {
  const WorkOrderEntity({
    required this.id,
    required this.tenantId,
    required this.title,
    required this.status,
    required this.priority,
    this.customerId,
    this.siteId,
    this.assetId,
    this.assignedToUserId,
    this.scheduledFor,
    this.description = '',
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String title;
  final WorkOrderStatus status;
  final WorkOrderPriority priority;
  final String? customerId;
  final String? siteId;
  final String? assetId;
  final String? assignedToUserId;
  final DateTime? scheduledFor;
  final String description;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Valid next states. Invalid moves are rejected before they can be queued
  /// for offline sync or sent to the database.
  Set<WorkOrderStatus> get allowedNextStatuses => switch (status) {
    WorkOrderStatus.draft => {
      WorkOrderStatus.scheduled,
      WorkOrderStatus.cancelled,
    },
    WorkOrderStatus.scheduled => {
      WorkOrderStatus.inProgress,
      WorkOrderStatus.cancelled,
    },
    WorkOrderStatus.inProgress => {
      WorkOrderStatus.completed,
      WorkOrderStatus.cancelled,
    },
    WorkOrderStatus.completed || WorkOrderStatus.cancelled => const {},
  };

  bool canTransitionTo(WorkOrderStatus next) =>
      allowedNextStatuses.contains(next);

  WorkOrderEntity transitionTo(WorkOrderStatus next) {
    if (!canTransitionTo(next)) {
      throw StateError('Cannot transition work order $status to $next.');
    }
    return copyWith(status: next);
  }

  WorkOrderEntity copyWith({
    String? title,
    WorkOrderStatus? status,
    WorkOrderPriority? priority,
    String? customerId,
    bool clearCustomerId = false,
    String? siteId,
    bool clearSiteId = false,
    String? assetId,
    bool clearAssetId = false,
    String? assignedToUserId,
    bool clearAssignedToUserId = false,
    DateTime? scheduledFor,
    bool clearScheduledFor = false,
    String? description,
    DateTime? updatedAt,
  }) => WorkOrderEntity(
    id: id,
    tenantId: tenantId,
    title: title ?? this.title,
    status: status ?? this.status,
    priority: priority ?? this.priority,
    customerId: clearCustomerId ? null : (customerId ?? this.customerId),
    siteId: clearSiteId ? null : (siteId ?? this.siteId),
    assetId: clearAssetId ? null : (assetId ?? this.assetId),
    assignedToUserId: clearAssignedToUserId
        ? null
        : (assignedToUserId ?? this.assignedToUserId),
    scheduledFor: clearScheduledFor
        ? null
        : (scheduledFor ?? this.scheduledFor),
    description: description ?? this.description,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
