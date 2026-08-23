import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../mappers/maintenance_supabase_mapper.dart';
import '../models/maintenance_record.dart';

/// Retrieves a complete maintenance record on demand when its schedule link
/// survives a local-cache reset. RLS remains the authority for this read.
abstract class MaintenanceRemoteDatasource {
  Future<MaintenanceRecord?> getById(String id);
}

class MaintenanceRemoteDatasourceImpl implements MaintenanceRemoteDatasource {
  MaintenanceRemoteDatasourceImpl({SupabaseClient? client}) : _client = client;

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
  Future<MaintenanceRecord?> getById(String id) async {
    final client = _supabase;
    if (client == null || id.trim().isEmpty) return null;

    final job = await client
        .from(kMaintenanceJobsTable)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (job == null) return null;

    final detail = await client
        .from(kMaintenanceRecordsTable)
        .select('data')
        .eq('job_id', id)
        .maybeSingle();

    return maintenanceRecordFromSupabaseRows(
      job: Map<String, dynamic>.from(job),
      details: detail == null ? null : Map<String, dynamic>.from(detail),
    );
  }
}

final maintenanceRemoteDatasourceProvider =
    Provider<MaintenanceRemoteDatasource>((ref) => MaintenanceRemoteDatasourceImpl());
