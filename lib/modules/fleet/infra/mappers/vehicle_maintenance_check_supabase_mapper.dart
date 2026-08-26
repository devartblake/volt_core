import '../../../../core/services/sync/sync_context.dart';
import '../../domain/entities/vehicle_maintenance_check.dart';

/// Supabase table holding vehicle checks (migration 20260825160000).
const String kVehicleMaintenanceChecksTable = 'vehicle_maintenance_checks';

/// `date` columns want a bare calendar day, not an instant. Sending a full
/// timestamp works but round-trips back with a time component the user never
/// entered, which then renders as a different day either side of midnight.
String? _dateOnly(DateTime? value) {
  if (value == null) return null;
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

Map<String, dynamic> vehicleCheckToSupabaseJson(VehicleMaintenanceCheck c) {
  return {
    'id': c.id,
    // Always present: the sync queue's tenant re-stamp only touches payloads
    // that already carry the column. See retagQueuedRow.
    'tenant_id': c.tenantId,
    'vehicle_id': c.vehicleId,
    'checked_at': c.checkedAt.toIso8601String(),
    'checked_by_user_id': c.checkedByUserId,
    'odometer': c.odometer,
    'last_oil_change_at': _dateOnly(c.lastOilChangeAt),
    'last_lubricant_check_at': _dateOnly(c.lastLubricantCheckAt),
    'odometer_at_last_service': c.odometerAtLastService,
    'brake_status': c.brakeStatus.wire,
    'battery_status': c.batteryStatus.wire,
    'notes': c.notes.trim(),
    'created_at': c.createdAt.toIso8601String(),
    'updated_at': c.updatedAt.toIso8601String(),
    if (SyncContext.userId != null) 'updated_by': SyncContext.userId,
  };
}

VehicleMaintenanceCheck vehicleCheckFromSupabaseJson(Map<String, dynamic> row) {
  final now = DateTime.now().toUtc();
  return VehicleMaintenanceCheck(
    id: row['id'].toString(),
    tenantId: (row['tenant_id'] ?? '').toString(),
    vehicleId: (row['vehicle_id'] ?? '').toString(),
    checkedAt: DateTime.tryParse('${row['checked_at']}')?.toUtc() ?? now,
    checkedByUserId: row['checked_by_user_id']?.toString(),
    odometer: (row['odometer'] as num?)?.toInt() ?? 0,
    lastOilChangeAt: DateTime.tryParse('${row['last_oil_change_at']}'),
    lastLubricantCheckAt:
        DateTime.tryParse('${row['last_lubricant_check_at']}'),
    odometerAtLastService: (row['odometer_at_last_service'] as num?)?.toInt(),
    brakeStatus: CheckStatusX.fromWire(row['brake_status']?.toString()),
    batteryStatus: CheckStatusX.fromWire(row['battery_status']?.toString()),
    notes: (row['notes'] ?? '').toString(),
    createdAt: DateTime.tryParse('${row['created_at']}')?.toUtc() ?? now,
    updatedAt: DateTime.tryParse('${row['updated_at']}')?.toUtc() ?? now,
  );
}
