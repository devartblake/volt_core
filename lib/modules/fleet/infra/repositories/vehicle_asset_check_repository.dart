import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/sync/sync_context.dart';
import '../../../../core/services/sync/sync_service.dart';
import '../../domain/entities/asset_disclaimer.dart';
import '../../domain/entities/fleet_depot.dart';
import '../../domain/entities/vehicle_asset.dart';
import '../../domain/entities/vehicle_asset_check.dart';
import '../datasources/vehicle_asset_check_boxes.dart';
import '../mappers/vehicle_asset_check_supabase_mapper.dart';
import '../models/fleet_reference_records.dart';
import '../models/vehicle_asset_check_record.dart';
import 'vehicle_asset_repository.dart';
import 'vehicle_repository_impl.dart' show TenantIdReader;

typedef AssetCheckQueueWriter = Future<void> Function(VehicleAssetCheck check);
typedef AssetCheckLineQueueWriter = Future<void> Function(
  VehicleAssetCheckLine line,
);

/// Thrown when something tries to edit a receipt both parties have signed.
///
/// Surfaced here as well as in the database so the person finds out while the
/// screen is still open, rather than as a sync failure hours later.
class ReceiptIsFinalized implements Exception {
  const ReceiptIsFinalized(this.checkId);
  final String checkId;

  @override
  String toString() =>
      'Receipt $checkId is counter-signed and can no longer be changed.';
}

abstract class VehicleAssetCheckRepository {
  /// The wording a driver must accept, newest version first.
  ///
  /// Falls back to the transcription built into the app when the tenant has
  /// published nothing and nothing has synced — a driver on a fresh tablet
  /// still gets shown the terms rather than a blank modal.
  Future<AssetDisclaimer> currentDisclaimer();

  /// The exact wording a stored receipt was signed under.
  ///
  /// Used when reprinting: a receipt signed against version 1 must print
  /// version 1's clauses even after version 2 exists, or the paper misstates
  /// what the person agreed to.
  Future<AssetDisclaimer> disclaimerVersion(int version);

  /// A draft receipt for [vehicleId], one line per tool currently assigned,
  /// prefilled from each tool's standing state.
  Future<VehicleAssetCheck> startReceipt(String vehicleId);

  Future<VehicleAssetCheck> save(VehicleAssetCheck check);

  Future<List<VehicleAssetCheck>> listForVehicle(String vehicleId);

  Future<VehicleAssetCheck?> latestForVehicle(String vehicleId);

  Future<List<FleetDepot>> listDepots({bool includeInactive});
}

class VehicleAssetCheckRepositoryImpl implements VehicleAssetCheckRepository {
  VehicleAssetCheckRepositoryImpl({
    Box<VehicleAssetCheckRecord>? checkBox,
    Box<VehicleAssetCheckLineRecord>? lineBox,
    Box<AssetDisclaimerRecord>? disclaimerBox,
    Box<FleetDepotRecord>? depotBox,
    VehicleAssetRepository? assets,
    AssetCheckQueueWriter? checkQueueWriter,
    AssetCheckLineQueueWriter? lineQueueWriter,
    TenantIdReader? tenantIdReader,
    SupabaseClient? client,
  })  : _injectedCheckBox = checkBox,
        _injectedLineBox = lineBox,
        _injectedDisclaimerBox = disclaimerBox,
        _injectedDepotBox = depotBox,
        _injectedAssets = assets,
        _checkQueue = checkQueueWriter ?? _enqueueCheck,
        _lineQueue = lineQueueWriter ?? _enqueueLine,
        _tenantIdReader = tenantIdReader ?? (() => SyncContext.tenantId),
        _client = client;

  final Box<VehicleAssetCheckRecord>? _injectedCheckBox;
  final Box<VehicleAssetCheckLineRecord>? _injectedLineBox;
  final Box<AssetDisclaimerRecord>? _injectedDisclaimerBox;
  final Box<FleetDepotRecord>? _injectedDepotBox;
  final VehicleAssetRepository? _injectedAssets;
  final AssetCheckQueueWriter _checkQueue;
  final AssetCheckLineQueueWriter _lineQueue;
  final TenantIdReader _tenantIdReader;
  final SupabaseClient? _client;

  Box<VehicleAssetCheckRecord> get _checkBox =>
      _injectedCheckBox ?? VehicleAssetChecksBox.box;
  Box<VehicleAssetCheckLineRecord> get _lineBox =>
      _injectedLineBox ?? VehicleAssetCheckLinesBox.box;
  Box<AssetDisclaimerRecord> get _disclaimerBox =>
      _injectedDisclaimerBox ?? AssetDisclaimersBox.box;
  Box<FleetDepotRecord> get _depotBox =>
      _injectedDepotBox ?? FleetDepotsBox.box;
  VehicleAssetRepository get _assets =>
      _injectedAssets ?? VehicleAssetRepositoryImpl();

  static Future<void> _enqueueCheck(VehicleAssetCheck check) {
    return SyncService.instance.enqueueUpsert(
      table: kVehicleAssetChecksTable,
      id: check.id,
      payload: assetCheckToSupabaseJson(check),
    );
  }

  static Future<void> _enqueueLine(VehicleAssetCheckLine line) {
    return SyncService.instance.enqueueUpsert(
      table: kVehicleAssetCheckLinesTable,
      id: line.id,
      payload: assetCheckLineToSupabaseJson(line),
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

  VehicleAssetCheckRecord _toCheckRecord(VehicleAssetCheck c) =>
      VehicleAssetCheckRecord(
        id: c.id,
        tenantId: c.tenantId,
        vehicleId: c.vehicleId,
        checkedAt: c.checkedAt,
        operatorUserId: c.operatorUserId,
        operatorName: c.operatorName,
        coOperatorName: c.coOperatorName,
        dispatcherUserId: c.dispatcherUserId,
        dispatcherName: c.dispatcherName,
        operatorSignaturePath: c.operatorSignaturePath,
        operatorSignedAt: c.operatorSignedAt,
        dispatcherSignaturePath: c.dispatcherSignaturePath,
        dispatcherSignedAt: c.dispatcherSignedAt,
        disclaimerVersion: c.disclaimerVersion,
        disclaimerAcceptedAt: c.disclaimerAcceptedAt,
        notes: c.notes,
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
      );

  VehicleAssetCheck _toCheck(
    VehicleAssetCheckRecord r,
    List<VehicleAssetCheckLine> lines,
  ) =>
      VehicleAssetCheck(
        id: r.id,
        tenantId: r.tenantId,
        vehicleId: r.vehicleId,
        checkedAt: r.checkedAt,
        lines: lines,
        operatorUserId: r.operatorUserId,
        operatorName: r.operatorName,
        coOperatorName: r.coOperatorName,
        dispatcherUserId: r.dispatcherUserId,
        dispatcherName: r.dispatcherName,
        operatorSignaturePath: r.operatorSignaturePath,
        operatorSignedAt: r.operatorSignedAt,
        dispatcherSignaturePath: r.dispatcherSignaturePath,
        dispatcherSignedAt: r.dispatcherSignedAt,
        disclaimerVersion: r.disclaimerVersion,
        disclaimerAcceptedAt: r.disclaimerAcceptedAt,
        notes: r.notes,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  VehicleAssetCheckLineRecord _toLineRecord(VehicleAssetCheckLine l) =>
      VehicleAssetCheckLineRecord(
        id: l.id,
        checkId: l.checkId,
        tenantId: l.tenantId,
        vehicleAssetId: l.vehicleAssetId,
        assetName: l.assetName,
        partNumber: l.partNumber,
        serialNumber: l.serialNumber,
        quantity: l.quantity,
        readiness: l.readiness.wire,
        isMissing: l.isMissing,
        reason: l.reason,
        sortIndex: l.sortIndex,
        createdAt: l.createdAt,
        updatedAt: l.updatedAt,
      );

  VehicleAssetCheckLine _toLine(VehicleAssetCheckLineRecord r) =>
      VehicleAssetCheckLine(
        id: r.id,
        checkId: r.checkId,
        tenantId: r.tenantId,
        vehicleAssetId: r.vehicleAssetId,
        assetName: r.assetName,
        partNumber: r.partNumber,
        serialNumber: r.serialNumber,
        quantity: r.quantity,
        readiness: AssetReadinessX.fromWire(r.readiness),
        isMissing: r.isMissing,
        reason: r.reason,
        sortIndex: r.sortIndex,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  AssetDisclaimer _toDisclaimer(AssetDisclaimerRecord r) => AssetDisclaimer(
        id: r.id,
        tenantId: r.tenantId,
        version: r.version,
        title: r.title,
        intro: r.intro,
        clauses: decodeClauses(r.clausesJson),
        closing: r.closing,
        publishedAt: r.publishedAt,
      );

  AssetDisclaimerRecord _toDisclaimerRecord(AssetDisclaimer d) =>
      AssetDisclaimerRecord(
        id: d.id,
        tenantId: d.tenantId,
        version: d.version,
        title: d.title,
        intro: d.intro,
        clausesJson: encodeClauses(d.clauses),
        closing: d.closing,
        publishedAt: d.publishedAt,
      );

  FleetDepot _toDepot(FleetDepotRecord r) => FleetDepot(
        id: r.id,
        tenantId: r.tenantId,
        name: r.name,
        address: r.address,
        notes: r.notes,
        isActive: r.isActive,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  FleetDepotRecord _toDepotRecord(FleetDepot d) => FleetDepotRecord(
        id: d.id,
        tenantId: d.tenantId,
        name: d.name,
        address: d.address,
        notes: d.notes,
        isActive: d.isActive,
        createdAt: d.createdAt,
        updatedAt: d.updatedAt,
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

      switch (table) {
        case kVehicleAssetChecksTable:
          for (final row in rows) {
            final check = assetCheckFromSupabaseJson(row);
            final local = _checkBox.get(check.id);
            if (local == null || check.updatedAt.isAfter(local.updatedAt)) {
              await _checkBox.put(check.id, _toCheckRecord(check));
            }
          }
        case kVehicleAssetCheckLinesTable:
          for (final row in rows) {
            final line = assetCheckLineFromSupabaseJson(row);
            final local = _lineBox.get(line.id);
            if (local == null || line.updatedAt.isAfter(local.updatedAt)) {
              await _lineBox.put(line.id, _toLineRecord(line));
            }
          }
        case kFleetDisclaimersTable:
          for (final row in rows) {
            final disclaimer = disclaimerFromSupabaseJson(row);
            await _disclaimerBox.put(
              disclaimer.id,
              _toDisclaimerRecord(disclaimer),
            );
          }
        case kFleetDepotsTable:
          for (final row in rows) {
            final depot = depotFromSupabaseJson(row);
            final local = _depotBox.get(depot.id);
            if (local == null || depot.updatedAt.isAfter(local.updatedAt)) {
              await _depotBox.put(depot.id, _toDepotRecord(depot));
            }
          }
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[Fleet] $table hydrate failed (using local only): $error');
      }
    }
  }

  // ---- disclaimer ----

  @override
  Future<AssetDisclaimer> currentDisclaimer() async {
    await _hydrate(kFleetDisclaimersTable);
    final tenantId = _tenantIdReader() ?? '';

    final published = _disclaimerBox.values
        .map(_toDisclaimer)
        .where((d) => tenantId.isEmpty || d.tenantId == tenantId)
        .where((d) => d.clauses.isNotEmpty)
        .toList(growable: false)
      ..sort((a, b) => b.version.compareTo(a.version));

    if (published.isNotEmpty) return published.first;

    // Nothing published and nothing cached. The built-in transcription is what
    // stops a driver being asked to sign next to an empty box on their first
    // morning with a new tablet.
    return AssetDisclaimer.builtIn(tenantId: tenantId);
  }

  @override
  Future<AssetDisclaimer> disclaimerVersion(int version) async {
    await _hydrate(kFleetDisclaimersTable);
    final tenantId = _tenantIdReader() ?? '';

    for (final record in _disclaimerBox.values) {
      if (record.version != version) continue;
      if (tenantId.isNotEmpty && record.tenantId != tenantId) continue;
      return _toDisclaimer(record);
    }

    // The signed version is not on this device. The built-in text is the right
    // answer only when it IS that version; otherwise say so on the printout
    // rather than quietly substituting different clauses.
    if (version == kBuiltInDisclaimerVersion) {
      return AssetDisclaimer.builtIn(tenantId: tenantId);
    }

    return AssetDisclaimer(
      id: 'unavailable-v$version',
      tenantId: tenantId,
      version: version,
      title: kBuiltInDisclaimerTitle,
      intro: 'Version $version of the asset disclaimer is not available on '
          'this device. The signature below was given against that version.',
      clauses: const [],
      closing: '',
      publishedAt: DateTime.now().toUtc(),
    );
  }

  // ---- receipts ----

  @override
  Future<VehicleAssetCheck> startReceipt(String vehicleId) async {
    final tenantId = _requireTenant();
    final disclaimer = await currentDisclaimer();
    final assets = await _assets.listForVehicle(vehicleId);

    final draft = VehicleAssetCheck.newDraft(
      tenantId: tenantId,
      vehicleId: vehicleId,
      disclaimerVersion: disclaimer.version,
    );

    var sortIndex = 0;
    final lines = [
      for (final resolved in assets)
        VehicleAssetCheckLine.fromAsset(
          checkId: draft.id,
          asset: resolved.asset,
          item: resolved.item,
          sortIndex: sortIndex++,
        ),
    ];

    return draft.copyWith(lines: lines);
  }

  @override
  Future<VehicleAssetCheck> save(VehicleAssetCheck check) async {
    final tenantId = _requireTenant();
    if (check.tenantId != tenantId) {
      throw StateError('Receipts belong to the active tenant.');
    }

    // Local mirror of the database trigger. Without it the screen would accept
    // an edit, queue it, and only find out hours later when the upsert is
    // rejected — by which time whoever made the change has gone home.
    final existing = _checkBox.get(check.id);
    if (existing?.dispatcherSignedAt != null) {
      throw ReceiptIsFinalized(check.id);
    }

    final saved = check.copyWith(updatedAt: DateTime.now().toUtc());

    await _checkBox.put(saved.id, _toCheckRecord(saved));
    for (final line in saved.lines) {
      await _lineBox.put(line.id, _toLineRecord(line));
    }

    await _checkQueue(saved);
    for (final line in saved.lines) {
      await _lineQueue(line);
    }

    // The moment the driver signs is the moment the van's standing state
    // becomes what the receipt says. Doing it here rather than on the screen
    // means a receipt signed offline still updates the flag dispatch reads.
    if (saved.isSignedByOperator) {
      await _applyStandingState(saved);
    }

    return saved;
  }

  /// Push each line's answer back onto the tool it refers to.
  ///
  /// This is what makes "2 vehicles have missing assets" true on the fleet list
  /// without querying every receipt ever signed.
  Future<void> _applyStandingState(VehicleAssetCheck check) async {
    final byId = <String, VehicleAsset>{
      for (final resolved in await _assets.listForVehicle(
        check.vehicleId,
        includeRetired: true,
      ))
        resolved.asset.id: resolved.asset,
    };

    for (final line in check.lines) {
      final assetId = line.vehicleAssetId;
      if (assetId == null) continue;

      final asset = byId[assetId];
      // Retired mid-receipt: the tool is gone for good, so a "missing" answer
      // about it would re-flag something nobody is waiting for.
      if (asset == null || asset.isRetired) continue;
      if (asset.isMissing == line.isMissing &&
          asset.readiness == line.readiness) {
        continue;
      }

      try {
        await _assets.saveAsset(
          asset.copyWith(
            isMissing: line.isMissing,
            readiness: line.readiness,
            updatedAt: DateTime.now().toUtc(),
          ),
        );
      } catch (error) {
        // A single tool failing to update must not lose the signature that has
        // already been captured.
        if (kDebugMode) {
          debugPrint('[Fleet] could not update asset $assetId: $error');
        }
      }
    }
  }

  @override
  Future<List<VehicleAssetCheck>> listForVehicle(String vehicleId) async {
    await _hydrate(kVehicleAssetChecksTable);
    await _hydrate(kVehicleAssetCheckLinesTable);
    final tenantId = _tenantIdReader();

    final linesByCheck = <String, List<VehicleAssetCheckLine>>{};
    for (final record in _lineBox.values) {
      linesByCheck.putIfAbsent(record.checkId, () => []).add(_toLine(record));
    }
    for (final lines in linesByCheck.values) {
      lines.sort((a, b) => a.sortIndex.compareTo(b.sortIndex));
    }

    final checks = _checkBox.values
        .where((r) => r.vehicleId == vehicleId)
        .where((r) => tenantId == null || r.tenantId == tenantId)
        .map((r) => _toCheck(r, linesByCheck[r.id] ?? const []))
        .toList(growable: false)
      ..sort((a, b) => b.checkedAt.compareTo(a.checkedAt));

    return checks;
  }

  @override
  Future<VehicleAssetCheck?> latestForVehicle(String vehicleId) async {
    final checks = await listForVehicle(vehicleId);
    return checks.isEmpty ? null : checks.first;
  }

  // ---- depots ----

  @override
  Future<List<FleetDepot>> listDepots({bool includeInactive = false}) async {
    await _hydrate(kFleetDepotsTable);
    final tenantId = _tenantIdReader();

    return _depotBox.values
        .map(_toDepot)
        .where((d) => tenantId == null || d.tenantId == tenantId)
        .where((d) => includeInactive || d.isActive)
        .toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  String _requireTenant() {
    final tenantId = _tenantIdReader();
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('Select an active tenant first.');
    }
    return tenantId;
  }
}

final vehicleAssetCheckRepositoryProvider =
    Provider<VehicleAssetCheckRepository>(
  (ref) => VehicleAssetCheckRepositoryImpl(),
);
