import '../../domain/entities/vehicle_inspection.dart';

/// Supabase table holding vehicle walk-around inspections (migration
/// 20261109100000).
const String kVehicleInspectionsTable = 'vehicle_inspections';

/// The row sent to Supabase. `payload` carries the whole entity so nothing is
/// lost; the typed columns are for filtering and reporting.
///
/// [updatedAt] is the local save time; it decides which copy wins on a pull.
Map<String, dynamic> vehicleInspectionToRow(
  VehicleInspection i, {
  required String tenantId,
  String? userId,
  required DateTime updatedAt,
}) {
  return {
    'id': i.id,
    // Always present: the sync queue's tenant re-stamp only touches payloads
    // that already carry the column.
    'tenant_id': tenantId,
    'vehicle_id': i.vehicleId,
    'cadence': i.cadence.name,
    'inspected_at': i.inspectedAt.toUtc().toIso8601String(),
    // RLS lets the inspector write their own rows; fall back to the signed-in
    // user for older records that never stored one. The payload keeps the
    // original value untouched.
    'inspector_user_id': i.inspectorUserId ?? userId,
    'odometer': i.odometer < 0 ? 0 : i.odometer,
    'issue_count': i.issueCount,
    'fail_count': i.failCount,
    'signed_at': i.signedAt?.toUtc().toIso8601String(),
    'payload': i.toMap(),
    'created_at': i.createdAt.toUtc().toIso8601String(),
    'updated_at': updatedAt.toUtc().toIso8601String(),
    if (userId != null) 'updated_by': userId,
  };
}

/// Decodes a pulled row back into an inspection, or null when it is unusable.
VehicleInspection? vehicleInspectionFromRow(Map<String, dynamic> row) {
  try {
    final payload = row['payload'];
    if (payload is Map) {
      final map = Map<String, dynamic>.from(payload);
      // The row ids are authoritative.
      map['id'] = row['id'].toString();
      if (row['vehicle_id'] != null) {
        map['vehicleId'] = row['vehicle_id'].toString();
      }
      return VehicleInspection.fromMap(map);
    }
    // No payload: rebuild what the typed columns know.
    return VehicleInspection(
      id: row['id'].toString(),
      vehicleId: (row['vehicle_id'] ?? '').toString(),
      cadence: InspectionCadenceX.fromWire(row['cadence']?.toString()),
      inspectedAt:
          DateTime.tryParse('${row['inspected_at']}') ?? DateTime.now(),
      createdAt: DateTime.tryParse('${row['created_at']}') ?? DateTime.now(),
      inspectorUserId: row['inspector_user_id']?.toString(),
      odometer: (row['odometer'] as num?)?.toInt() ?? 0,
      signedAt: DateTime.tryParse('${row['signed_at']}'),
    );
  } catch (_) {
    return null;
  }
}

/// The row's `updated_at`, or null when missing.
DateTime? vehicleInspectionRowUpdatedAt(Map<String, dynamic> row) =>
    DateTime.tryParse('${row['updated_at']}')?.toUtc();
