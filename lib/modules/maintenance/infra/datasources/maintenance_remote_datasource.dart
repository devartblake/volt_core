import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../mappers/maintenance_supabase_mapper.dart';
import '../models/maintenance_record.dart';

/// Retrieves a complete maintenance record on demand when its schedule link
/// survives a local-cache reset. RLS remains the authority for this read.
abstract class MaintenanceRemoteDatasource {
  Future<MaintenanceRecord?> getById(String id);

  /// Every maintenance record the signed-in user can see (RLS decides).
  Future<List<MaintenanceRecord>> listAll();
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
  Future<List<MaintenanceRecord>> listAll() async {
    final client = _supabase;
    if (client == null) return const [];

    final jobs = await client.from(kMaintenanceJobsTable).select();
    final details =
        await client.from(kMaintenanceRecordsTable).select('job_id, data');

    final detailByJob = <String, Map<String, dynamic>>{
      for (final d in details)
        d['job_id'].toString(): Map<String, dynamic>.from(d as Map),
    };

    return [
      for (final job in jobs)
        maintenanceRecordFromSupabaseRows(
          job: Map<String, dynamic>.from(job as Map),
          details: detailByJob[job['id'].toString()],
        ),
    ];
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
