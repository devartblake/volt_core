import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/sync/sync_context.dart';
import '../../domain/entities/work_order_entity.dart';
import '../mappers/work_order_supabase_mapper.dart';

/// Read-only cloud side of the offline-first work-order repository.
///
/// Writes always use SyncService's durable outbox, so an unreachable Supabase
/// project cannot block a technician from creating or changing a job.
abstract class WorkOrderRemoteDatasource {
  Future<List<WorkOrderEntity>> list();
}

class WorkOrderRemoteDatasourceImpl implements WorkOrderRemoteDatasource {
  WorkOrderRemoteDatasourceImpl({SupabaseClient? client}) : _client = client;

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
  Future<List<WorkOrderEntity>> list() async {
    final client = _supabase;
    final tenantId = SyncContext.tenantId;
    if (client == null || tenantId == null || tenantId.isEmpty) return const [];

    final response = await client
        .from(kWorkOrdersTable)
        .select()
        .eq('tenant_id', tenantId)
        .order('updated_at', ascending: false);

    return (response as List)
        .cast<Map<String, dynamic>>()
        .map(workOrderFromSupabaseJson)
        .toList(growable: false);
  }
}

final workOrderRemoteDatasourceProvider =
    Provider<WorkOrderRemoteDatasource>((ref) => WorkOrderRemoteDatasourceImpl());
