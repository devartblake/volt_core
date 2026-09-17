import 'dart:convert';

import '../../../../core/services/sync/sync_context.dart';
import '../../domain/entities/asset_disclaimer.dart';
import '../../domain/entities/fleet_depot.dart';
import '../../domain/entities/vehicle_asset.dart';
import '../../domain/entities/vehicle_asset_check.dart';

const String kVehicleAssetChecksTable = 'vehicle_asset_checks';
const String kVehicleAssetCheckLinesTable = 'vehicle_asset_check_lines';
const String kFleetDisclaimersTable = 'fleet_disclaimers';
const String kFleetDepotsTable = 'fleet_depots';

/// The header row. Lines are enqueued separately, one upsert each, mirroring
/// the two tables.
Map<String, dynamic> assetCheckToSupabaseJson(VehicleAssetCheck check) {
  return {
    'id': check.id,
    // Always present: the sync queue's tenant re-stamp only touches payloads
    // that already carry the column. See retagQueuedRow.
    'tenant_id': check.tenantId,
    'vehicle_id': check.vehicleId,
    'checked_at': check.checkedAt.toIso8601String(),
    'operator_user_id': check.operatorUserId,
    'operator_name': check.operatorName.trim(),
    'co_operator_name': check.coOperatorName.trim(),
    'dispatcher_user_id': check.dispatcherUserId,
    'dispatcher_name': check.dispatcherName.trim(),
    'operator_signature_path': check.operatorSignaturePath,
    'operator_signed_at': check.operatorSignedAt?.toIso8601String(),
    'dispatcher_signature_path': check.dispatcherSignaturePath,
    'dispatcher_signed_at': check.dispatcherSignedAt?.toIso8601String(),
    'disclaimer_version': check.disclaimerVersion,
    'disclaimer_accepted_at': check.disclaimerAcceptedAt?.toIso8601String(),
    'notes': check.notes.trim(),
    'created_at': check.createdAt.toIso8601String(),
    'updated_at': check.updatedAt.toIso8601String(),
  };
}

VehicleAssetCheck assetCheckFromSupabaseJson(
  Map<String, dynamic> row, {
  List<VehicleAssetCheckLine> lines = const [],
}) {
  final now = DateTime.now().toUtc();
  return VehicleAssetCheck(
    id: row['id'].toString(),
    tenantId: (row['tenant_id'] ?? '').toString(),
    vehicleId: (row['vehicle_id'] ?? '').toString(),
    checkedAt: DateTime.tryParse('${row['checked_at']}')?.toUtc() ?? now,
    lines: lines,
    operatorUserId: row['operator_user_id']?.toString(),
    operatorName: (row['operator_name'] ?? '').toString(),
    coOperatorName: (row['co_operator_name'] ?? '').toString(),
    dispatcherUserId: row['dispatcher_user_id']?.toString(),
    dispatcherName: (row['dispatcher_name'] ?? '').toString(),
    operatorSignaturePath: row['operator_signature_path']?.toString(),
    operatorSignedAt: DateTime.tryParse('${row['operator_signed_at']}')?.toUtc(),
    dispatcherSignaturePath: row['dispatcher_signature_path']?.toString(),
    dispatcherSignedAt:
        DateTime.tryParse('${row['dispatcher_signed_at']}')?.toUtc(),
    disclaimerVersion: _asInt(row['disclaimer_version']) ?? 1,
    disclaimerAcceptedAt:
        DateTime.tryParse('${row['disclaimer_accepted_at']}')?.toUtc(),
    notes: (row['notes'] ?? '').toString(),
    createdAt: DateTime.tryParse('${row['created_at']}')?.toUtc() ?? now,
    updatedAt: DateTime.tryParse('${row['updated_at']}')?.toUtc() ?? now,
  );
}

Map<String, dynamic> assetCheckLineToSupabaseJson(VehicleAssetCheckLine line) {
  return {
    'id': line.id,
    'tenant_id': line.tenantId,
    'check_id': line.checkId,
    'vehicle_asset_id': line.vehicleAssetId,
    // Snapshots, not joins: what the tool was called on the day it was signed
    // for. Renaming the catalog entry later must not rewrite this receipt.
    'asset_name': line.assetName.trim(),
    'part_number': line.partNumber.trim(),
    'serial_number': line.serialNumber.trim(),
    'quantity': line.quantity,
    'readiness': line.readiness.wire,
    'is_missing': line.isMissing,
    'reason': line.reason.trim(),
    'sort_index': line.sortIndex,
    'created_at': line.createdAt.toIso8601String(),
    'updated_at': line.updatedAt.toIso8601String(),
  };
}

VehicleAssetCheckLine assetCheckLineFromSupabaseJson(Map<String, dynamic> row) {
  final now = DateTime.now().toUtc();
  return VehicleAssetCheckLine(
    id: row['id'].toString(),
    checkId: (row['check_id'] ?? '').toString(),
    tenantId: (row['tenant_id'] ?? '').toString(),
    vehicleAssetId: row['vehicle_asset_id']?.toString(),
    assetName: (row['asset_name'] ?? 'Unknown tool').toString(),
    partNumber: (row['part_number'] ?? '').toString(),
    serialNumber: (row['serial_number'] ?? '').toString(),
    quantity: _asInt(row['quantity']) ?? 1,
    readiness: AssetReadinessX.fromWire(row['readiness']?.toString()),
    isMissing: row['is_missing'] == true,
    reason: (row['reason'] ?? '').toString(),
    sortIndex: _asInt(row['sort_index']) ?? 0,
    createdAt: DateTime.tryParse('${row['created_at']}')?.toUtc() ?? now,
    updatedAt: DateTime.tryParse('${row['updated_at']}')?.toUtc() ?? now,
  );
}

Map<String, dynamic> disclaimerToSupabaseJson(AssetDisclaimer disclaimer) {
  return {
    'id': disclaimer.id,
    'tenant_id': disclaimer.tenantId,
    'version': disclaimer.version,
    'title': disclaimer.title,
    'intro': disclaimer.intro,
    'clauses': disclaimer.clauses.map((c) => c.toJson()).toList(),
    'closing': disclaimer.closing,
    'published_at': disclaimer.publishedAt.toIso8601String(),
    if (SyncContext.userId != null) 'published_by': SyncContext.userId,
  };
}

AssetDisclaimer disclaimerFromSupabaseJson(Map<String, dynamic> row) {
  return AssetDisclaimer(
    id: row['id'].toString(),
    tenantId: (row['tenant_id'] ?? '').toString(),
    version: _asInt(row['version']) ?? 1,
    title: (row['title'] ?? kBuiltInDisclaimerTitle).toString(),
    intro: (row['intro'] ?? '').toString(),
    clauses: decodeClauses(row['clauses']),
    closing: (row['closing'] ?? '').toString(),
    publishedAt:
        DateTime.tryParse('${row['published_at']}')?.toUtc() ?? DateTime.now().toUtc(),
    publishedBy: row['published_by']?.toString(),
  );
}

/// Clauses arrive as a decoded jsonb list from Supabase and as a JSON string
/// from Hive. Both land here so the two paths cannot disagree about the shape.
List<DisclaimerClause> decodeClauses(Object? raw) {
  if (raw == null) return const [];
  final decoded = raw is String ? jsonDecode(raw) : raw;
  if (decoded is! List) return const [];
  return decoded
      .whereType<Map>()
      .map((m) => DisclaimerClause.fromJson(m.cast<String, dynamic>()))
      .toList(growable: false);
}

String encodeClauses(List<DisclaimerClause> clauses) =>
    jsonEncode(clauses.map((c) => c.toJson()).toList());

Map<String, dynamic> depotToSupabaseJson(FleetDepot depot) {
  return {
    'id': depot.id,
    'tenant_id': depot.tenantId,
    'name': depot.name.trim(),
    'address': depot.address.trim(),
    'notes': depot.notes.trim(),
    'is_active': depot.isActive,
    'created_at': depot.createdAt.toIso8601String(),
    'updated_at': depot.updatedAt.toIso8601String(),
    if (SyncContext.userId != null) 'updated_by': SyncContext.userId,
  };
}

FleetDepot depotFromSupabaseJson(Map<String, dynamic> row) {
  final now = DateTime.now().toUtc();
  return FleetDepot(
    id: row['id'].toString(),
    tenantId: (row['tenant_id'] ?? '').toString(),
    name: (row['name'] ?? '').toString(),
    address: (row['address'] ?? '').toString(),
    notes: (row['notes'] ?? '').toString(),
    isActive: row['is_active'] != false,
    createdAt: DateTime.tryParse('${row['created_at']}')?.toUtc() ?? now,
    updatedAt: DateTime.tryParse('${row['updated_at']}')?.toUtc() ?? now,
  );
}

/// Postgres hands integers back as int, but a jsonb round trip or a mocked
/// client can produce a String or a double. Parse rather than cast.
int? _asInt(Object? raw) {
  if (raw is int) return raw;
  if (raw is num) return raw.toInt();
  return int.tryParse('$raw');
}
