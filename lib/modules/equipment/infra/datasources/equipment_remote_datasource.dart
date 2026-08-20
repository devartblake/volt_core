import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/sync/sync_context.dart';
import '../mappers/equipment_supabase_mapper.dart';

/// A row from the shared equipment registry, paired with the identity key that
/// lets it be merged against a locally derived unit.
@immutable
class RemoteEquipmentRow {
  const RemoteEquipmentRow({required this.identityKey, required this.raw});

  final String identityKey;
  final Map<String, dynamic> raw;
}

/// Reads the shared equipment registry.
///
/// Writes go through [SyncService] rather than here, so they survive being
/// offline; this side is read-only.
abstract class EquipmentRemoteDatasource {
  Future<List<RemoteEquipmentRow>> list();
}

class EquipmentRemoteDatasourceImpl implements EquipmentRemoteDatasource {
  EquipmentRemoteDatasourceImpl({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient? get _supabase {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null; // Supabase not initialised (e.g. tests, no config).
    }
  }

  @override
  Future<List<RemoteEquipmentRow>> list() async {
    final client = _supabase;
    final tenantId = SyncContext.tenantId;
    if (client == null || tenantId == null) return const [];

    final response = await client
        .from(kEquipmentTable)
        .select()
        .eq('tenant_id', tenantId)
        .order('last_inspection_at', ascending: false, nullsFirst: false);

    return (response as List)
        .cast<Map<String, dynamic>>()
        .map((row) => RemoteEquipmentRow(
              identityKey: identityKeyOf(row),
              raw: row,
            ))
        .toList(growable: false);
  }
}

final equipmentRemoteDatasourceProvider =
    Provider<EquipmentRemoteDatasource>((ref) {
  return EquipmentRemoteDatasourceImpl();
});
