import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/sync/sync_context.dart';
import '../../domain/entities/work_order_event.dart';

const kWorkOrderEventsTable = 'work_order_events';

/// Reads trigger-created work-order history. The database grants no direct
/// writes to this table, so audit records cannot be forged by the app.
abstract class WorkOrderEventRemoteDatasource {
  Future<List<WorkOrderEvent>> listForWorkOrder(String workOrderId);
}

class WorkOrderEventRemoteDatasourceImpl
    implements WorkOrderEventRemoteDatasource {
  WorkOrderEventRemoteDatasourceImpl({SupabaseClient? client})
    : _client = client;

  final SupabaseClient? _client;

  SupabaseClient? get _supabase {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<WorkOrderEvent>> listForWorkOrder(String workOrderId) async {
    final client = _supabase;
    final tenantId = SyncContext.tenantId;
    if (client == null || tenantId == null || tenantId.isEmpty) return const [];

    final response = await client
        .from(kWorkOrderEventsTable)
        .select()
        .eq('tenant_id', tenantId)
        .eq('work_order_id', workOrderId)
        .order('created_at', ascending: false);

    return (response as List)
        .cast<Map<String, dynamic>>()
        .map(workOrderEventFromSupabaseJson)
        .toList(growable: false);
  }
}

WorkOrderEvent workOrderEventFromSupabaseJson(Map<String, dynamic> row) {
  return WorkOrderEvent(
    id: (row['id'] ?? '').toString(),
    workOrderId: (row['work_order_id'] ?? '').toString(),
    tenantId: (row['tenant_id'] ?? '').toString(),
    type: _eventType((row['event_type'] ?? '').toString()),
    actorUserId: _nullableString(row['actor_user_id']),
    fromStatus: _nullableString(row['from_status']),
    toStatus: _nullableString(row['to_status']),
    previousAssignedToUserId: _nullableString(
      row['previous_assigned_to_user_id'],
    ),
    assignedToUserId: _nullableString(row['assigned_to_user_id']),
    createdAt:
        DateTime.tryParse((row['created_at'] ?? '').toString())?.toUtc() ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
}

WorkOrderEventType _eventType(String value) => switch (value) {
  'status_changed' => WorkOrderEventType.statusChanged,
  'assignment_changed' => WorkOrderEventType.assignmentChanged,
  _ => WorkOrderEventType.created,
};

String? _nullableString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

final workOrderEventRemoteDatasourceProvider =
    Provider<WorkOrderEventRemoteDatasource>(
      (ref) => WorkOrderEventRemoteDatasourceImpl(),
    );
