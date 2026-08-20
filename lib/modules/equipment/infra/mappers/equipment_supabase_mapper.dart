import 'package:uuid/uuid.dart';

import '../../../../core/services/sync/sync_context.dart';
import '../../domain/entities/equipment_entity.dart';

/// Supabase table holding the shared equipment registry (migration 0004).
const String kEquipmentTable = 'equipment';

/// Namespace for deterministic equipment ids. Any fixed UUID works; this one is
/// arbitrary and must never change, or every device would start minting new
/// rows for units that already exist.
const String _kEquipmentNamespace = '6f5c1f1e-9c7a-4a3e-8f5b-2f0d3a7c1b44';

/// The row id for a unit, derived from the tenant and the unit's identity key.
///
/// Two devices that derive the same physical generator produce the same id, so
/// a plain upsert merges their records — the sync queue doesn't need conflict
/// targets. Changing this function would orphan every existing row.
String equipmentIdFor({required String tenantId, required String identityKey}) {
  return const Uuid().v5(_kEquipmentNamespace, '$tenantId|$identityKey');
}

/// Serialize a derived unit to a `public.equipment` row.
///
/// [identityKey] must be the same value used to build the id.
Map<String, dynamic> equipmentToSupabaseJson(
  EquipmentEntity e, {
  required String identityKey,
  required String tenantId,
}) {
  return {
    'id': equipmentIdFor(tenantId: tenantId, identityKey: identityKey),
    'tenant_id': tenantId,
    'identity_key': identityKey,
    'name': e.name,
    'make': e.make,
    'model': e.model,
    'serial_number': e.serialNumber,
    'voltage': e.voltage,
    'location': e.location,
    'site_code': e.siteCode,
    'site_grade': e.siteGrade,
    'status': e.status.name,
    'last_inspection_at': e.lastInspection?.toIso8601String(),
    'inspection_count': e.inspectionCount,
    // The local inspection this was derived from, for the nameplate deep-link.
    'latest_inspection_id': e.id,
    'updated_at': DateTime.now().toIso8601String(),
    if (SyncContext.userId != null) 'updated_by': SyncContext.userId,
  };
}

/// Read a `public.equipment` row back into the domain entity.
///
/// `id` becomes the **latest inspection id** rather than the row id, because
/// that is what the UI navigates with (`/nameplate/:inspectionId`). Rows for
/// units never inspected on this device carry no inspection id; those get the
/// row id, and the nameplate page will open an empty record for them.
EquipmentEntity equipmentFromSupabaseJson(Map<String, dynamic> row) {
  final lastInspection = row['last_inspection_at'];

  return EquipmentEntity(
    id: (row['latest_inspection_id'] ?? row['id'] ?? '').toString(),
    name: (row['name'] ?? '').toString(),
    make: (row['make'] ?? '').toString(),
    model: (row['model'] ?? '').toString(),
    serialNumber: (row['serial_number'] ?? '').toString(),
    voltage: (row['voltage'] ?? '').toString(),
    location: (row['location'] ?? '').toString(),
    siteCode: (row['site_code'] ?? '').toString(),
    siteGrade: (row['site_grade'] ?? '').toString(),
    lastInspection:
        lastInspection == null ? null : DateTime.tryParse('$lastInspection'),
    inspectionCount: (row['inspection_count'] as num?)?.toInt() ?? 0,
    status: _statusFromName((row['status'] ?? '').toString()),
  );
}

/// The identity key stored on a remote row, used to merge it with locally
/// derived units.
String identityKeyOf(Map<String, dynamic> row) =>
    (row['identity_key'] ?? '').toString();

EquipmentStatus _statusFromName(String name) {
  for (final status in EquipmentStatus.values) {
    if (status.name == name) return status;
  }
  return EquipmentStatus.active;
}
