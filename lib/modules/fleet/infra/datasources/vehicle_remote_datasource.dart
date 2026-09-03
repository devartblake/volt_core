import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/sync/sync_context.dart';
import '../../domain/entities/vehicle_entity.dart';
import '../mappers/vehicle_supabase_mapper.dart';

/// Read-only cloud side of the offline-first vehicle repository.
///
/// Writes always go through SyncService's durable outbox, so an unreachable
/// Supabase project cannot block dispatch from adding or editing a vehicle.
///
/// No client-side filter by assignee: RLS already returns only the vehicle a
/// technician is stationed to, and the whole fleet to a manager. Filtering here
/// as well would be a second copy of the rule that could disagree with the
/// first.
abstract class VehicleRemoteDatasource {
  Future<List<VehicleEntity>> list();
}

class VehicleRemoteDatasourceImpl implements VehicleRemoteDatasource {
  VehicleRemoteDatasourceImpl({SupabaseClient? client}) : _client = client;

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
  Future<List<VehicleEntity>> list() async {
    final client = _supabase;
    final tenantId = SyncContext.tenantId;
    if (client == null || tenantId == null || tenantId.isEmpty) return const [];

    final response = await client
        .from(kFleetVehiclesTable)
        .select()
        .eq('tenant_id', tenantId)
        .order('designation', ascending: true);

    return (response as List)
        .cast<Map<String, dynamic>>()
        .map(vehicleFromSupabaseJson)
        .toList(growable: false);
  }
}

final vehicleRemoteDatasourceProvider =
    Provider<VehicleRemoteDatasource>((ref) => VehicleRemoteDatasourceImpl());
