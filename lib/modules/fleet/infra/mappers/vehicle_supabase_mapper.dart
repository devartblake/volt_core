import '../../../../core/services/sync/sync_context.dart';
import '../../domain/entities/vehicle_entity.dart';

/// Supabase table holding the fleet (migration 20260825140000).
const String kFleetVehiclesTable = 'fleet_vehicles';

/// Serialize a vehicle to a `public.fleet_vehicles` row.
///
/// `tenant_id` is always included when the entity carries one. The sync queue
/// re-stamps a stale tenant at drain time, but only on rows that already have
/// the column — omitting it means the row fails RLS forever with no way to
/// heal it. See `retagQueuedRow`.
Map<String, dynamic> vehicleToSupabaseJson(VehicleEntity v) {
  return {
    'id': v.id,
    'tenant_id': v.tenantId,
    'designation': v.designation.trim(),
    // Null rather than '' so the partial unique index on VIN ignores the row
    // instead of colliding every un-VINed vehicle with every other one.
    'vin': (v.vin ?? '').trim().isEmpty ? null : normalizeVin(v.vin!.trim()),
    'license_plate': v.licensePlate.trim(),
    'make': v.make.trim(),
    'model': v.model.trim(),
    'model_year': v.modelYear,
    'vehicle_type': v.vehicleType.wire,
    'odometer': v.odometer,
    // `wire`, not `name` — the check constraint spells the two-word states
    // with an underscore and rejects `outOfService`.
    'status': v.status.wire,
    'assigned_to_user_id':
        (v.assignedToUserId ?? '').trim().isEmpty ? null : v.assignedToUserId,
    'notes': v.notes.trim(),
    'last_check_at': v.lastCheckAt?.toIso8601String(),
    'created_at': v.createdAt.toIso8601String(),
    'updated_at': v.updatedAt.toIso8601String(),
    if (SyncContext.userId != null) 'updated_by': SyncContext.userId,
  };
}

/// Read a `public.fleet_vehicles` row back into the domain entity.
VehicleEntity vehicleFromSupabaseJson(Map<String, dynamic> row) {
  final vin = row['vin']?.toString().trim();

  return VehicleEntity(
    id: row['id'].toString(),
    tenantId: (row['tenant_id'] ?? '').toString(),
    designation: (row['designation'] ?? '').toString(),
    vin: vin == null || vin.isEmpty ? null : vin,
    licensePlate: (row['license_plate'] ?? '').toString(),
    make: (row['make'] ?? '').toString(),
    model: (row['model'] ?? '').toString(),
    modelYear: (row['model_year'] as num?)?.toInt(),
    vehicleType: VehicleTypeX.fromWire(row['vehicle_type']?.toString()),
    odometer: (row['odometer'] as num?)?.toInt() ?? 0,
    status: VehicleStatusX.fromWire(row['status']?.toString()),
    assignedToUserId: row['assigned_to_user_id']?.toString(),
    notes: (row['notes'] ?? '').toString(),
    lastCheckAt: DateTime.tryParse('${row['last_check_at']}')?.toUtc(),
    createdAt:
        DateTime.tryParse('${row['created_at']}')?.toUtc() ?? DateTime.now().toUtc(),
    updatedAt:
        DateTime.tryParse('${row['updated_at']}')?.toUtc() ?? DateTime.now().toUtc(),
  );
}
