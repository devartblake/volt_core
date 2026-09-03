import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/sync/sync_context.dart';
import '../../../../core/services/sync/sync_service.dart';
import '../../domain/entities/vehicle_asset.dart';
import '../../domain/entities/vehicle_asset_catalog_item.dart';
import '../datasources/vehicle_asset_boxes.dart';
import '../mappers/vehicle_asset_supabase_mapper.dart';
import '../models/vehicle_asset_catalog_item_record.dart';
import '../models/vehicle_asset_record.dart';
import 'vehicle_repository_impl.dart' show TenantIdReader;

typedef CatalogQueueWriter = Future<void> Function(VehicleAssetCatalogItem item);
typedef AssetQueueWriter = Future<void> Function(VehicleAsset asset);

/// One tool, resolved against its catalog entry.
///
/// The list screen needs both halves on every row and neither is useful alone:
/// an asset row is a pair of uuids, and a catalog entry says nothing about
/// which van has it.
class ResolvedVehicleAsset {
  const ResolvedVehicleAsset({required this.asset, required this.item});

  final VehicleAsset asset;

  /// Null when the catalog entry has not synced to this device yet. The row
  /// still renders — with the serial, or "Unknown tool" — rather than being
  /// dropped, because a tool the app cannot name is exactly the one somebody
  /// needs to ask about.
  final VehicleAssetCatalogItem? item;

  String get displayLabel =>
      item?.displayLabel ??
      (asset.serialNumber?.trim().isNotEmpty == true
          ? 'Unknown tool · ${asset.serialNumber!.trim()}'
          : 'Unknown tool');
}

abstract class VehicleAssetRepository {
  Future<List<VehicleAssetCatalogItem>> listCatalog({bool includeInactive});
  Future<VehicleAssetCatalogItem> saveCatalogItem(VehicleAssetCatalogItem item);

  /// Tools in a vehicle, retired ones excluded unless asked for.
  Future<List<ResolvedVehicleAsset>> listForVehicle(
    String vehicleId, {
    bool includeRetired,
  });

  Future<VehicleAsset> saveAsset(VehicleAsset asset);

  /// Retire a tool — sold, destroyed, written off. Not the same as missing.
  Future<VehicleAsset> retireAsset(String assetId);
}

class VehicleAssetRepositoryImpl implements VehicleAssetRepository {
  VehicleAssetRepositoryImpl({
    Box<VehicleAssetCatalogItemRecord>? catalogBox,
    Box<VehicleAssetRecord>? assetBox,
    CatalogQueueWriter? catalogQueueWriter,
    AssetQueueWriter? assetQueueWriter,
    TenantIdReader? tenantIdReader,
    SupabaseClient? client,
  })  : _injectedCatalogBox = catalogBox,
        _injectedAssetBox = assetBox,
        _catalogQueue = catalogQueueWriter ?? _enqueueCatalog,
        _assetQueue = assetQueueWriter ?? _enqueueAsset,
        _tenantIdReader = tenantIdReader ?? (() => SyncContext.tenantId),
        _client = client;

  final Box<VehicleAssetCatalogItemRecord>? _injectedCatalogBox;
  final Box<VehicleAssetRecord>? _injectedAssetBox;
  final CatalogQueueWriter _catalogQueue;
  final AssetQueueWriter _assetQueue;
  final TenantIdReader _tenantIdReader;
  final SupabaseClient? _client;

  Box<VehicleAssetCatalogItemRecord> get _catalogBox =>
      _injectedCatalogBox ?? VehicleAssetCatalogBox.box;
  Box<VehicleAssetRecord> get _assetBox =>
      _injectedAssetBox ?? VehicleAssetsBox.box;

  static Future<void> _enqueueCatalog(VehicleAssetCatalogItem item) {
    return SyncService.instance.enqueueUpsert(
      table: kVehicleAssetCatalogTable,
      id: item.id,
      payload: catalogItemToSupabaseJson(item),
    );
  }

  static Future<void> _enqueueAsset(VehicleAsset asset) {
    return SyncService.instance.enqueueUpsert(
      table: kVehicleAssetsTable,
      id: asset.id,
      payload: vehicleAssetToSupabaseJson(asset),
    );
  }

  SupabaseClient? get _supabase {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // ---- record <-> entity ----

  VehicleAssetCatalogItem _toItem(VehicleAssetCatalogItemRecord r) =>
      VehicleAssetCatalogItem(
        id: r.id,
        tenantId: r.tenantId,
        name: r.name,
        partNumber: r.partNumber,
        category: r.category,
        notes: r.notes,
        isActive: r.isActive,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  VehicleAssetCatalogItemRecord _toItemRecord(VehicleAssetCatalogItem i) =>
      VehicleAssetCatalogItemRecord(
        id: i.id,
        tenantId: i.tenantId,
        name: i.name,
        partNumber: i.partNumber,
        category: i.category,
        notes: i.notes,
        isActive: i.isActive,
        createdAt: i.createdAt,
        updatedAt: i.updatedAt,
      );

  VehicleAsset _toAsset(VehicleAssetRecord r) => VehicleAsset(
        id: r.id,
        tenantId: r.tenantId,
        vehicleId: r.vehicleId,
        catalogId: r.catalogId,
        serialNumber: r.serialNumber,
        readiness: AssetReadinessX.fromWire(r.readiness),
        isMissing: r.isMissing,
        notes: r.notes,
        assignedAt: r.assignedAt,
        retiredAt: r.retiredAt,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  VehicleAssetRecord _toAssetRecord(VehicleAsset a) => VehicleAssetRecord(
        id: a.id,
        tenantId: a.tenantId,
        vehicleId: a.vehicleId,
        catalogId: a.catalogId,
        serialNumber: a.serialNumber,
        readiness: a.readiness.wire,
        isMissing: a.isMissing,
        notes: a.notes,
        assignedAt: a.assignedAt,
        retiredAt: a.retiredAt,
        createdAt: a.createdAt,
        updatedAt: a.updatedAt,
      );

  // ---- hydration ----

  Future<void> _hydrate(String table) async {
    final client = _supabase;
    final tenantId = _tenantIdReader();
    if (client == null || tenantId == null || tenantId.isEmpty) return;

    try {
      final response =
          await client.from(table).select().eq('tenant_id', tenantId);
      final rows = (response as List).cast<Map<String, dynamic>>();

      if (table == kVehicleAssetCatalogTable) {
        for (final row in rows) {
          final item = catalogItemFromSupabaseJson(row);
          final local = _catalogBox.get(item.id);
          if (local == null || item.updatedAt.isAfter(local.updatedAt)) {
            await _catalogBox.put(item.id, _toItemRecord(item));
          }
        }
      } else {
        for (final row in rows) {
          final asset = vehicleAssetFromSupabaseJson(row);
          final local = _assetBox.get(asset.id);
          if (local == null || asset.updatedAt.isAfter(local.updatedAt)) {
            await _assetBox.put(asset.id, _toAssetRecord(asset));
          }
        }
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[Fleet] $table hydrate failed (using local only): $error');
      }
    }
  }

  // ---- catalog ----

  @override
  Future<List<VehicleAssetCatalogItem>> listCatalog({
    bool includeInactive = false,
  }) async {
    await _hydrate(kVehicleAssetCatalogTable);
    final tenantId = _tenantIdReader();

    return _catalogBox.values
        .map(_toItem)
        .where((i) => tenantId == null || i.tenantId == tenantId)
        .where((i) => includeInactive || i.isActive)
        .toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Future<VehicleAssetCatalogItem> saveCatalogItem(
    VehicleAssetCatalogItem item,
  ) async {
    final tenantId = _requireTenant();
    if (item.tenantId != tenantId) {
      throw StateError('Catalog items belong to the active tenant.');
    }

    final name = item.name.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(item.name, 'name', 'Give the tool a name.');
    }

    final part = normalizePartNumber(item.partNumber);

    // Caught here rather than as an opaque 23505 from the unique indexes,
    // seconds later, once whoever typed it has moved on.
    for (final other in _catalogBox.values) {
      if (other.id == item.id || other.tenantId != tenantId) continue;

      if (other.name.trim().toLowerCase() == name.toLowerCase()) {
        throw StateError('"$name" is already in the catalog.');
      }
      if (part.isNotEmpty && normalizePartNumber(other.partNumber) == part) {
        throw StateError('Part number $part already belongs to "${other.name}".');
      }
    }

    final saved = item.copyWith(
      name: name,
      partNumber: part.isEmpty ? null : part,
      clearPartNumber: part.isEmpty,
      updatedAt: DateTime.now().toUtc(),
    );

    await _catalogBox.put(saved.id, _toItemRecord(saved));
    await _catalogQueue(saved);
    return saved;
  }

  // ---- assets ----

  @override
  Future<List<ResolvedVehicleAsset>> listForVehicle(
    String vehicleId, {
    bool includeRetired = false,
  }) async {
    await _hydrate(kVehicleAssetCatalogTable);
    await _hydrate(kVehicleAssetsTable);
    final tenantId = _tenantIdReader();

    final catalog = <String, VehicleAssetCatalogItem>{
      for (final record in _catalogBox.values) record.id: _toItem(record),
    };

    final resolved = _assetBox.values
        .map(_toAsset)
        .where((a) => a.vehicleId == vehicleId)
        .where((a) => tenantId == null || a.tenantId == tenantId)
        .where((a) => includeRetired || !a.isRetired)
        .map((a) => ResolvedVehicleAsset(asset: a, item: catalog[a.catalogId]))
        .toList(growable: false);

    // Anything needing attention floats to the top: a missing ladder is the
    // reason somebody opened this screen. Then by name, so two of the same
    // tool sit together.
    resolved.sort((a, b) {
      final attentionA = a.asset.needsAttention ? 0 : 1;
      final attentionB = b.asset.needsAttention ? 0 : 1;
      if (attentionA != attentionB) return attentionA - attentionB;
      return a.displayLabel.toLowerCase().compareTo(
            b.displayLabel.toLowerCase(),
          );
    });

    return resolved;
  }

  @override
  Future<VehicleAsset> saveAsset(VehicleAsset asset) async {
    final tenantId = _requireTenant();
    if (asset.tenantId != tenantId) {
      throw StateError('Assets belong to the active tenant.');
    }

    final catalogEntry = _catalogBox.get(asset.catalogId);
    if (catalogEntry == null) {
      throw StateError('That tool is not in the catalog.');
    }

    final serial = normalizeSerial(asset.serialNumber);
    if (serial.isNotEmpty) {
      for (final other in _assetBox.values) {
        if (other.id == asset.id || other.tenantId != tenantId) continue;
        if (other.retiredAt != null) continue;
        if (normalizeSerial(other.serialNumber) != serial) continue;

        // The same numbered tool cannot be in two vans. Say which one, or the
        // person is left hunting.
        throw StateError(
          'Serial $serial is already assigned to another vehicle.',
        );
      }
    }

    final saved = asset.copyWith(
      serialNumber: serial.isEmpty ? null : serial,
      clearSerialNumber: serial.isEmpty,
      updatedAt: DateTime.now().toUtc(),
    );

    await _assetBox.put(saved.id, _toAssetRecord(saved));
    await _assetQueue(saved);
    return saved;
  }

  @override
  Future<VehicleAsset> retireAsset(String assetId) async {
    final record = _assetBox.get(assetId);
    if (record == null) throw StateError('Asset $assetId was not found.');

    final asset = _toAsset(record);
    if (asset.isRetired) return asset;

    // Retiring clears "missing": the tool is not coming back, so leaving it
    // flagged would keep it on the attention list forever.
    return saveAsset(
      asset.copyWith(retiredAt: DateTime.now().toUtc(), isMissing: false),
    );
  }

  String _requireTenant() {
    final tenantId = _tenantIdReader();
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('Select an active tenant first.');
    }
    return tenantId;
  }
}

final vehicleAssetRepositoryProvider = Provider<VehicleAssetRepository>(
  (ref) => VehicleAssetRepositoryImpl(),
);
