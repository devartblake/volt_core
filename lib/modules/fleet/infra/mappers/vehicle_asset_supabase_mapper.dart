import '../../../../core/services/sync/sync_context.dart';
import '../../domain/entities/vehicle_asset.dart';
import '../../domain/entities/vehicle_asset_catalog_item.dart';

const String kVehicleAssetCatalogTable = 'vehicle_asset_catalog';
const String kVehicleAssetsTable = 'vehicle_assets';

Map<String, dynamic> catalogItemToSupabaseJson(VehicleAssetCatalogItem item) {
  final part = (item.partNumber ?? '').trim();
  return {
    'id': item.id,
    // Always present: the sync queue's tenant re-stamp only touches payloads
    // that already carry the column. See retagQueuedRow.
    'tenant_id': item.tenantId,
    'name': item.name.trim(),
    // Null, never '' — the unique index is partial, and '' would collide every
    // part-numberless item with every other one.
    'part_number': part.isEmpty ? null : part,
    'category': item.category.trim(),
    'notes': item.notes.trim(),
    'is_active': item.isActive,
    'created_at': item.createdAt.toIso8601String(),
    'updated_at': item.updatedAt.toIso8601String(),
    if (SyncContext.userId != null) 'updated_by': SyncContext.userId,
  };
}

VehicleAssetCatalogItem catalogItemFromSupabaseJson(Map<String, dynamic> row) {
  final now = DateTime.now().toUtc();
  final part = row['part_number']?.toString().trim();
  return VehicleAssetCatalogItem(
    id: row['id'].toString(),
    tenantId: (row['tenant_id'] ?? '').toString(),
    name: (row['name'] ?? '').toString(),
    partNumber: part == null || part.isEmpty ? null : part,
    category: (row['category'] ?? '').toString(),
    notes: (row['notes'] ?? '').toString(),
    isActive: row['is_active'] != false,
    createdAt: DateTime.tryParse('${row['created_at']}')?.toUtc() ?? now,
    updatedAt: DateTime.tryParse('${row['updated_at']}')?.toUtc() ?? now,
  );
}

Map<String, dynamic> vehicleAssetToSupabaseJson(VehicleAsset asset) {
  final serial = (asset.serialNumber ?? '').trim();
  return {
    'id': asset.id,
    'tenant_id': asset.tenantId,
    'vehicle_id': asset.vehicleId,
    'catalog_id': asset.catalogId,
    'serial_number': serial.isEmpty ? null : serial,
    'readiness': asset.readiness.wire,
    'is_missing': asset.isMissing,
    'notes': asset.notes.trim(),
    'assigned_at': asset.assignedAt.toIso8601String(),
    'retired_at': asset.retiredAt?.toIso8601String(),
    'created_at': asset.createdAt.toIso8601String(),
    'updated_at': asset.updatedAt.toIso8601String(),
    if (SyncContext.userId != null) 'updated_by': SyncContext.userId,
  };
}

VehicleAsset vehicleAssetFromSupabaseJson(Map<String, dynamic> row) {
  final now = DateTime.now().toUtc();
  final serial = row['serial_number']?.toString().trim();
  return VehicleAsset(
    id: row['id'].toString(),
    tenantId: (row['tenant_id'] ?? '').toString(),
    vehicleId: (row['vehicle_id'] ?? '').toString(),
    catalogId: (row['catalog_id'] ?? '').toString(),
    serialNumber: serial == null || serial.isEmpty ? null : serial,
    readiness: AssetReadinessX.fromWire(row['readiness']?.toString()),
    isMissing: row['is_missing'] == true,
    notes: (row['notes'] ?? '').toString(),
    assignedAt: DateTime.tryParse('${row['assigned_at']}')?.toUtc() ?? now,
    retiredAt: DateTime.tryParse('${row['retired_at']}')?.toUtc(),
    createdAt: DateTime.tryParse('${row['created_at']}')?.toUtc() ?? now,
    updatedAt: DateTime.tryParse('${row['updated_at']}')?.toUtc() ?? now,
  );
}
