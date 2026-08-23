import 'package:flutter/foundation.dart';

/// An immutable, database-created entry in a work order's audit timeline.
@immutable
class WorkOrderEvent {
  const WorkOrderEvent({
    required this.id,
    required this.workOrderId,
    required this.tenantId,
    required this.type,
    this.actorUserId,
    this.fromStatus,
    this.toStatus,
    this.previousAssignedToUserId,
    this.assignedToUserId,
    required this.createdAt,
  });

  final String id;
  final String workOrderId;
  final String tenantId;
  final WorkOrderEventType type;
  final String? actorUserId;
  final String? fromStatus;
  final String? toStatus;
  final String? previousAssignedToUserId;
  final String? assignedToUserId;
  final DateTime createdAt;
}

enum WorkOrderEventType { created, statusChanged, assignmentChanged }
