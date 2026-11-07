import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/sync/sync_context.dart';
import '../../../core/services/sync/sync_service.dart';
import '../../materials/domain/material_item.dart';
import '../domain/catalog_part.dart';
import '../domain/inventory_location.dart';
import '../domain/stock.dart';

const String kPartsCatalogTable = 'parts_catalog';
const String kInventoryLocationsTable = 'inventory_locations';
const String kInventoryMovementsTable = 'inventory_movements';

typedef InventoryUpsert = Future<void> Function(
  String table,
  String id,
  Map<String, dynamic> row,
);

/// Reads the cloud's rows for a table; returns [] when offline or signed out.
typedef InventoryFetch = Future<List<Map<String, dynamic>>> Function(
  String table,
);

class DuplicatePartException implements Exception {
  const DuplicatePartException(this.existing);
  final CatalogPart existing;

  @override
  String toString() =>
      'Part ${existing.partNumber} is already in the catalog.';
}

String generateInventoryId() => const Uuid().v4();

/// The parts catalog and stock ledger, kept on the device and queued for the
/// cloud. Two plain `Box<String>` JSON stores (no Hive adapters).
class InventoryRepository {
  InventoryRepository({
    Box<String>? catalogBox,
    Box<String>? movementsBox,
    Box<String>? locationsBox,
    InventoryUpsert? upsert,
    InventoryFetch? fetch,
    String? Function()? tenantId,
    String? Function()? userId,
    String Function()? newId,
    DateTime Function()? now,
  })  : _catalogInjected = catalogBox,
        _movementsInjected = movementsBox,
        _locationsInjected = locationsBox,
        _upsert = upsert ?? _defaultUpsert,
        _fetch = fetch ?? _defaultFetch,
        _tenantId = tenantId ?? (() => SyncContext.tenantId),
        _userId = userId ?? (() => SyncContext.userId),
        _newId = newId ?? generateInventoryId,
        _now = now ?? (() => DateTime.now().toUtc());

  static const String catalogBoxName = 'parts_catalog';
  static const String movementsBoxName = 'inventory_movements';
  static const String locationsBoxName = 'inventory_locations';

  final Box<String>? _catalogInjected;
  final Box<String>? _movementsInjected;
  final Box<String>? _locationsInjected;
  final InventoryUpsert _upsert;
  final InventoryFetch _fetch;
  final String? Function() _tenantId;
  final String? Function() _userId;
  final String Function() _newId;
  final DateTime Function() _now;

  Future<Box<String>> _open(String name, Box<String>? injected) async {
    if (injected != null) return injected;
    if (Hive.isBoxOpen(name)) return Hive.box<String>(name);
    return Hive.openBox<String>(name);
  }

  Future<Box<String>> _catalog() => _open(catalogBoxName, _catalogInjected);
  Future<Box<String>> _movements() =>
      _open(movementsBoxName, _movementsInjected);
  Future<Box<String>> _locations() =>
      _open(locationsBoxName, _locationsInjected);

  static Future<void> _defaultUpsert(
    String table,
    String id,
    Map<String, dynamic> row,
  ) =>
      SyncService.instance.enqueueUpsert(table: table, id: id, payload: row);

  static Future<List<Map<String, dynamic>>> _defaultFetch(String table) async {
    try {
      final rows = await Supabase.instance.client
          .from(table)
          .select()
          .timeout(const Duration(seconds: 8));
      return [for (final r in rows) Map<String, dynamic>.from(r as Map)];
    } catch (_) {
      return const [];
    }
  }

  // ---- reads --------------------------------------------------------------

  Future<List<CatalogPart>> parts() async {
    final box = await _catalog();
    return [
      for (final raw in box.values)
        if (CatalogPart.decode(raw) case final p?) p,
    ];
  }

  Future<List<InventoryMovement>> movements({String? partId}) async {
    final box = await _movements();
    final all = [
      for (final raw in box.values)
        if (InventoryMovement.decode(raw) case final m?) m,
    ];
    final list = partId == null
        ? all
        : all.where((m) => m.partId == partId).toList();
    list.sort((a, b) => b.at.compareTo(a.at));
    return list;
  }

  Future<List<StockLevel>> stock() async =>
      computeStock(await parts(), await movements());

  // ---- writes -------------------------------------------------------------

  /// Adds or updates a part. Throws [DuplicatePartException] when another
  /// part already has this part number.
  Future<CatalogPart> savePart(CatalogPart part) async {
    if (partKey(part.partNumber).isEmpty) {
      throw ArgumentError('A part number is required.');
    }
    final box = await _catalog();
    for (final other in await parts()) {
      if (other.id != part.id && partKey(other.partNumber) == partKey(part.partNumber)) {
        throw DuplicatePartException(other);
      }
    }
    final saved = part.copyWith(
      partNumber: part.partNumber.trim(),
      name: part.name.trim(),
      manufacturer: part.manufacturer.trim(),
      updatedAt: _now(),
    );
    await box.put(saved.id, CatalogPart.encode(saved));
    await _syncPart(saved);
    return saved;
  }

  CatalogPart newPart({
    required String partNumber,
    String name = '',
    String manufacturer = '',
    MaterialSlot? slot,
    int minStock = 0,
    List<String> altPartNumbers = const [],
    String notes = '',
    String unit = 'each',
  }) {
    final now = _now();
    return CatalogPart(
      id: _newId(),
      partNumber: partNumber,
      name: name,
      manufacturer: manufacturer,
      slot: slot,
      unit: unit,
      minStock: minStock,
      altPartNumbers: altPartNumbers,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Appends to the ledger. [qty] is the signed change; zero is ignored.
  Future<InventoryMovement?> record({
    required String partId,
    required int qty,
    required MovementReason reason,
    String note = '',
    String? jobRef,
  }) =>
      recordAt(
        locationId: kMainLocationId,
        partId: partId,
        qty: qty,
        reason: reason,
        note: note,
        jobRef: jobRef,
      );

  /// [record] at a named location (the warehouse or a truck).
  Future<InventoryMovement?> recordAt({
    required String locationId,
    required String partId,
    required int qty,
    required MovementReason reason,
    String note = '',
    String? jobRef,
  }) async {
    if (qty == 0) return null;
    final m = InventoryMovement(
      id: _newId(),
      partId: partId,
      qtyDelta: qty,
      reason: reason,
      at: _now(),
      locationId: locationId,
      note: note.trim(),
      jobRef: jobRef,
      userId: _userId(),
    );
    final box = await _movements();
    await box.put(m.id, InventoryMovement.encode(m));
    await _syncMovement(m);
    return m;
  }

  // ---- locations and transfers --------------------------------------------

  /// The main warehouse first, then trucks by name.
  Future<List<InventoryLocation>> locations(
      {bool includeInactive = false}) async {
    final Box<String> box;
    try {
      box = await _locations();
    } catch (_) {
      // No store to read (very early start-up): the warehouse alone.
      return sortedLocations(const []);
    }
    return sortedLocations([
      for (final raw in box.values)
        if (InventoryLocation.decode(raw) case final l?) l,
    ], includeInactive: includeInactive);
  }

  InventoryLocation newTruck({
    required String name,
    String? vehicleId,
    String? assignedUserId,
  }) =>
      InventoryLocation(
        id: _newId(),
        name: name,
        kind: LocationKind.truck,
        vehicleId: vehicleId,
        assignedUserId: assignedUserId,
        updatedAt: _now(),
      );

  /// Adds or updates a truck (the main warehouse is not stored).
  Future<InventoryLocation> saveLocation(InventoryLocation location) async {
    final name = location.name.trim();
    if (name.isEmpty) throw ArgumentError('A name is required.');
    if (location.isMain) throw ArgumentError('The main warehouse is fixed.');
    final saved = location.copyWith(name: name, updatedAt: _now());
    final box = await _locations();
    await box.put(saved.id, InventoryLocation.encode(saved));
    await _syncLocation(saved);
    return saved;
  }

  /// Stock held at one location.
  Future<List<StockLevel>> stockAt(String locationId) async =>
      computeStockAt(await parts(), await movements(), locationId);

  /// Moves [qty] of a part between locations as two ledger lines. Throws
  /// [ArgumentError] (with a readable message) when it would take the source
  /// below zero or the locations are the same.
  Future<void> transfer({
    required String partId,
    required String fromId,
    required String toId,
    required int qty,
    String note = '',
  }) async {
    final have = onHandAt(await movements(partId: partId), partId, fromId);
    final plan = planTransfer(
      partId: partId,
      fromId: fromId,
      toId: toId,
      qty: qty,
      onHandAtSource: have,
      at: _now(),
      outId: _newId(),
      intoId: _newId(),
      note: note.trim(),
      userId: _userId(),
    );
    final box = await _movements();
    for (final m in [plan.out, plan.into]) {
      await box.put(m.id, InventoryMovement.encode(m));
      await _syncMovement(m);
    }
  }

  Future<InventoryMovement?> movementById(String id) async {
    final box = await _movements();
    return InventoryMovement.decode(box.get(id));
  }

  /// Sets the on-hand count to [counted] by recording the difference.
  Future<InventoryMovement?> recordCount(String partId, int counted,
      {String note = ''}) async {
    final level = (await stock()).where((l) => l.part.id == partId);
    final current = level.isEmpty ? 0 : level.first.onHand;
    return record(
      partId: partId,
      qty: counted - current,
      reason: MovementReason.count,
      note: note,
    );
  }

  // ---- job movements ------------------------------------------------------

  /// Sets [qty] aside for a job. Stock on hand does not change; available
  /// goes down.
  Future<void> reserveForJob(String jobRef, String partId, int qty,
          {String note = ''}) =>
      record(
          partId: partId,
          qty: qty,
          reason: MovementReason.reserve,
          jobRef: jobRef,
          note: note);

  /// Lets a reservation go.
  Future<void> releaseForJob(String jobRef, String partId, int qty,
          {String note = ''}) =>
      record(
          partId: partId,
          qty: qty,
          reason: MovementReason.release,
          jobRef: jobRef,
          note: note);

  /// Takes [qty] out of the warehouse for a job. [fromReserved] of it was
  /// reserved for that job, so that much of the reservation is consumed.
  Future<void> issueToJob(String jobRef, String partId, int qty,
      {int fromReserved = 0, String note = ''}) async {
    await record(
        partId: partId,
        qty: -qty,
        reason: MovementReason.issue,
        jobRef: jobRef,
        note: note);
    if (fromReserved > 0) {
      await record(
          partId: partId,
          qty: fromReserved > qty ? qty : fromReserved,
          reason: MovementReason.release,
          jobRef: jobRef,
          note: 'Issued');
    }
  }

  /// Brings unused parts back from a job.
  Future<void> returnFromJob(String jobRef, String partId, int qty,
          {String note = ''}) =>
      record(
          partId: partId,
          qty: qty,
          reason: MovementReason.returned,
          jobRef: jobRef,
          note: note);

  // ---- sync ---------------------------------------------------------------

  Future<void> _syncPart(CatalogPart p) async {
    final tenant = _tenantId();
    if (tenant == null || tenant.isEmpty) return;
    await _upsert(kPartsCatalogTable, p.id, partToRow(p, tenant, _userId()));
  }

  Future<void> _syncLocation(InventoryLocation l) async {
    final tenant = _tenantId();
    if (tenant == null || tenant.isEmpty) return;
    await _upsert(kInventoryLocationsTable, l.id, locationToRow(l, tenant));
  }

  Future<void> _syncMovement(InventoryMovement m) async {
    final tenant = _tenantId();
    if (tenant == null || tenant.isEmpty) return;
    // The warehouse row must exist before a movement points at it.
    await _upsert(kInventoryLocationsTable, tenant, {
      'id': tenant,
      'tenant_id': tenant,
      'name': 'Main warehouse',
      'kind': 'warehouse',
    });
    await _upsert(kInventoryMovementsTable, m.id, movementToRow(m, tenant));
  }

  /// Pulls the cloud catalog and ledger into the device: catalog entries by
  /// newest `updatedAt`, movements added if missing (they never change).
  /// Returns how many records were added or updated.
  Future<int> refreshFromCloud() async {
    var changed = 0;
    final catalog = await _catalog();
    for (final row in await _fetch(kPartsCatalogTable)) {
      final remote = partFromRow(row);
      if (remote == null) continue;
      final local = CatalogPart.decode(catalog.get(remote.id));
      if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
        await catalog.put(remote.id, CatalogPart.encode(remote));
        changed++;
      }
    }
    final locs = await _locations();
    for (final row in await _fetch(kInventoryLocationsTable)) {
      final remote = locationFromRow(row);
      if (remote == null) continue;
      final local = InventoryLocation.decode(locs.get(remote.id));
      if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
        await locs.put(remote.id, InventoryLocation.encode(remote));
        changed++;
      }
    }
    final ledger = await _movements();
    for (final row in await _fetch(kInventoryMovementsTable)) {
      final m = movementFromRow(row);
      if (m == null || ledger.containsKey(m.id)) continue;
      await ledger.put(m.id, InventoryMovement.encode(m));
      changed++;
    }
    return changed;
  }
}

// ---- row mapping ---------------------------------------------------------

Map<String, dynamic> partToRow(CatalogPart p, String tenantId, String? userId) =>
    {
      'id': p.id,
      'tenant_id': tenantId,
      'part_number': p.partNumber,
      'name': p.name,
      'manufacturer': p.manufacturer,
      'slot_type': p.slot?.wire,
      'unit': p.unit,
      'min_stock': p.minStock,
      'alt_part_numbers': p.altPartNumbers,
      'notes': p.notes,
      'is_active': p.isActive,
      'created_at': p.createdAt.toUtc().toIso8601String(),
      'updated_at': p.updatedAt.toUtc().toIso8601String(),
      if (userId != null) 'updated_by': userId,
    };

CatalogPart? partFromRow(Map<String, dynamic> row) => CatalogPart.fromJson({
      'id': row['id'],
      'partNumber': row['part_number'],
      'name': row['name'],
      'manufacturer': row['manufacturer'],
      'slot': row['slot_type'],
      'unit': row['unit'],
      'minStock': row['min_stock'],
      'altPartNumbers': row['alt_part_numbers'],
      'notes': row['notes'],
      'isActive': row['is_active'],
      'createdAt': row['created_at'],
      'updatedAt': row['updated_at'],
    });

Map<String, dynamic> movementToRow(InventoryMovement m, String tenantId) => {
      'id': m.id,
      'tenant_id': tenantId,
      'part_id': m.partId,
      // The warehouse id is the tenant id.
      'location_id': m.locationId == kMainLocationId ? tenantId : m.locationId,
      'qty_delta': m.qtyDelta,
      'reason': m.reason.wire,
      'note': m.note,
      'job_ref': m.jobRef,
      if (m.userId != null) 'user_id': m.userId,
      'at': m.at.toUtc().toIso8601String(),
    };

InventoryMovement? movementFromRow(Map<String, dynamic> row) =>
    InventoryMovement.fromJson({
      'id': row['id'],
      'partId': row['part_id'],
      'qtyDelta': row['qty_delta'],
      'reason': row['reason'],
      'note': row['note'],
      'jobRef': row['job_ref'],
      'userId': row['user_id'],
      'at': row['at'],
      'locationId': row['location_id'] == null ||
              row['location_id'] == row['tenant_id']
          ? kMainLocationId
          : row['location_id'].toString(),
    });

Map<String, dynamic> locationToRow(InventoryLocation l, String tenantId) => {
      'id': l.id,
      'tenant_id': tenantId,
      'name': l.name,
      'kind': l.kind.wire,
      'is_active': l.isActive,
      'vehicle_id': l.vehicleId,
      'assigned_user_id': l.assignedUserId,
      'updated_at': l.updatedAt.toUtc().toIso8601String(),
    };

/// Null for the warehouse row (its id is the tenant id; the app's main
/// warehouse is built in).
InventoryLocation? locationFromRow(Map<String, dynamic> row) {
  if (row['id'] == null ||
      row['id'] == row['tenant_id'] ||
      row['kind'] == null) {
    return null;
  }
  return InventoryLocation.fromJson({
    'id': row['id'],
    'name': row['name'],
    'kind': row['kind'],
    'isActive': row['is_active'],
    'vehicleId': row['vehicle_id'],
    'assignedUserId': row['assigned_user_id'],
    'updatedAt': row['updated_at'],
  });
}

// ---- providers -----------------------------------------------------------

final inventoryRepositoryProvider =
    Provider<InventoryRepository>((ref) => InventoryRepository());

final catalogPartsProvider = FutureProvider.autoDispose<List<CatalogPart>>(
  (ref) => ref.watch(inventoryRepositoryProvider).parts(),
);

final stockLevelsProvider = FutureProvider.autoDispose<List<StockLevel>>(
  (ref) => ref.watch(inventoryRepositoryProvider).stock(),
);

final inventoryLocationsProvider =
    FutureProvider.autoDispose<List<InventoryLocation>>(
  (ref) => ref.watch(inventoryRepositoryProvider).locations(),
);

/// Every location including deactivated trucks, for the admin sheet.
final allInventoryLocationsProvider =
    FutureProvider.autoDispose<List<InventoryLocation>>(
  (ref) =>
      ref.watch(inventoryRepositoryProvider).locations(includeInactive: true),
);

final partMovementsProvider = FutureProvider.autoDispose
    .family<List<InventoryMovement>, String>(
  (ref, partId) =>
      ref.watch(inventoryRepositoryProvider).movements(partId: partId),
);
