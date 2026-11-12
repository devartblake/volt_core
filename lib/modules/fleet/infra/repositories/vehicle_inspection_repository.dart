import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/sync/sync_context.dart';
import '../../../../core/services/sync/sync_service.dart';
import '../../domain/entities/vehicle_inspection.dart';
import '../mappers/vehicle_inspection_supabase_mapper.dart';

typedef VehicleInspectionUpsert = Future<void> Function(
  String table,
  String id,
  Map<String, dynamic> row,
);

typedef VehicleInspectionDelete = Future<void> Function(
  String table,
  String id,
);

/// Reads the cloud's inspection rows (optionally for one vehicle); returns []
/// when offline or signed out.
typedef VehicleInspectionFetch = Future<List<Map<String, dynamic>>> Function({
  String? vehicleId,
});

/// On-device store for [VehicleInspection]s: a plain `Box<String>` of JSON
/// keyed by id, like photo metadata. Every save and delete is also queued for
/// Supabase (`vehicle_inspections`) through the sync outbox.
///
/// A small sidecar box ([syncBoxName]) remembers, per inspection, when it was
/// last written here (`u:<id>`), that it has been queued (`s:<id>`) and that
/// it was deleted (`d:<id>`, so a pull cannot resurrect it before the delete
/// has reached the cloud).
class VehicleInspectionRepository {
  VehicleInspectionRepository({
    Box<String>? box,
    Box<String>? syncBox,
    VehicleInspectionUpsert? upsert,
    VehicleInspectionDelete? delete,
    VehicleInspectionFetch? fetch,
    String? Function()? tenantId,
    String? Function()? userId,
    DateTime Function()? now,
  })  : _injected = box,
        _syncInjected = syncBox,
        _upsert = upsert ?? _defaultUpsert,
        _delete = delete ?? _defaultDelete,
        _fetch = fetch ?? _defaultFetch,
        _tenantId = tenantId ?? (() => SyncContext.tenantId),
        _userId = userId ?? (() => SyncContext.userId),
        _now = now ?? (() => DateTime.now().toUtc());

  static const String boxName = 'vehicle_inspections';
  static const String syncBoxName = 'vehicle_inspections_sync';

  final Box<String>? _injected;
  final Box<String>? _syncInjected;
  final VehicleInspectionUpsert _upsert;
  final VehicleInspectionDelete _delete;
  final VehicleInspectionFetch _fetch;
  final String? Function() _tenantId;
  final String? Function() _userId;
  final DateTime Function() _now;

  Future<Box<String>> _box() async {
    final injected = _injected;
    if (injected != null) return injected;
    if (Hive.isBoxOpen(boxName)) return Hive.box<String>(boxName);
    return Hive.openBox<String>(boxName);
  }

  Future<Box<String>> _syncBox() async {
    final injected = _syncInjected;
    if (injected != null) return injected;
    if (Hive.isBoxOpen(syncBoxName)) return Hive.box<String>(syncBoxName);
    return Hive.openBox<String>(syncBoxName);
  }

  static Future<void> _defaultUpsert(
    String table,
    String id,
    Map<String, dynamic> row,
  ) =>
      SyncService.instance.enqueueUpsert(table: table, id: id, payload: row);

  static Future<void> _defaultDelete(String table, String id) =>
      SyncService.instance.enqueueDelete(table: table, id: id);

  static Future<List<Map<String, dynamic>>> _defaultFetch({
    String? vehicleId,
  }) async {
    try {
      final tenant = SyncContext.tenantId;
      if (tenant == null || tenant.isEmpty) return const [];
      var query = Supabase.instance.client
          .from(kVehicleInspectionsTable)
          .select()
          .eq('tenant_id', tenant);
      if (vehicleId != null) query = query.eq('vehicle_id', vehicleId);
      final rows = await query.timeout(const Duration(seconds: 8));
      return [for (final r in rows) Map<String, dynamic>.from(r as Map)];
    } catch (_) {
      return const [];
    }
  }

  /// Inspections for one vehicle, newest first.
  Future<List<VehicleInspection>> listForVehicle(String vehicleId) async {
    final box = await _box();
    final out = <VehicleInspection>[];
    for (final raw in box.values) {
      try {
        final inspection = VehicleInspection.fromJson(raw);
        if (inspection.vehicleId == vehicleId) out.add(inspection);
      } catch (_) {
        // Skip a corrupt row rather than hiding the rest of the history.
      }
    }
    out.sort((a, b) => b.inspectedAt.compareTo(a.inspectedAt));
    return out;
  }

  /// Every inspection on this device, newest first, for the cross-vehicle log.
  Future<List<VehicleInspection>> listAll() async {
    final box = await _box();
    final out = <VehicleInspection>[];
    for (final raw in box.values) {
      try {
        out.add(VehicleInspection.fromJson(raw));
      } catch (_) {
        // Skip a corrupt row rather than hiding the rest of the log.
      }
    }
    out.sort((a, b) => b.inspectedAt.compareTo(a.inspectedAt));
    return out;
  }

  Future<void> save(VehicleInspection inspection) async {
    final box = await _box();
    await box.put(inspection.id, inspection.toJson());
    final sync = await _syncBox();
    final at = _now();
    await sync.put('u:${inspection.id}', at.toIso8601String());
    await sync.delete('d:${inspection.id}');
    await _queueUpsert(inspection, at, sync);
  }

  Future<void> delete(String id) async {
    final box = await _box();
    await box.delete(id);
    final sync = await _syncBox();
    await sync.delete('u:$id');
    await sync.delete('s:$id');
    await sync.put('d:$id', _now().toIso8601String());
    final tenant = _tenantId();
    if (tenant == null || tenant.isEmpty) return;
    try {
      await _delete(kVehicleInspectionsTable, id);
    } catch (_) {
      // Queueing is best effort; the local delete already happened.
    }
  }

  // ---- sync ---------------------------------------------------------------

  Future<void> _queueUpsert(
    VehicleInspection inspection,
    DateTime updatedAt,
    Box<String> sync,
  ) async {
    final tenant = _tenantId();
    if (tenant == null || tenant.isEmpty) return;
    try {
      await _upsert(
        kVehicleInspectionsTable,
        inspection.id,
        vehicleInspectionToRow(
          inspection,
          tenantId: tenant,
          userId: _userId(),
          updatedAt: updatedAt,
        ),
      );
      await sync.put('s:${inspection.id}', updatedAt.toIso8601String());
    } catch (_) {
      // Left unmarked, so the next backfill queues it again.
    }
  }

  /// Queues every local inspection that has never been queued (records made
  /// before syncing existed, or saved while no tenant was active). Idempotent:
  /// an upsert of the same id just replaces the row. Returns how many were
  /// queued.
  Future<int> backfillUnsynced() async {
    final tenant = _tenantId();
    if (tenant == null || tenant.isEmpty) return 0;
    final box = await _box();
    final sync = await _syncBox();
    var queued = 0;
    for (final raw in box.values.toList()) {
      VehicleInspection inspection;
      try {
        inspection = VehicleInspection.fromJson(raw);
      } catch (_) {
        continue;
      }
      if (sync.containsKey('s:${inspection.id}') ||
          sync.containsKey('d:${inspection.id}')) {
        continue;
      }
      final at = _now();
      await sync.put('u:${inspection.id}', at.toIso8601String());
      await _queueUpsert(inspection, at, sync);
      if (sync.containsKey('s:${inspection.id}')) queued++;
    }
    return queued;
  }

  /// Uploads anything never uploaded, then merges the cloud's rows into the
  /// device: a remote row wins only when its `updated_at` is newer than the
  /// local copy's last write. Never throws. Returns how many records were
  /// added or updated.
  Future<int> refreshFromCloud({String? vehicleId}) async {
    try {
      await backfillUnsynced();
      final box = await _box();
      final sync = await _syncBox();
      var changed = 0;
      for (final row in await _fetch(vehicleId: vehicleId)) {
        final remote = vehicleInspectionFromRow(row);
        if (remote == null) continue;
        if (sync.containsKey('d:${remote.id}')) continue;
        final remoteAt =
            vehicleInspectionRowUpdatedAt(row) ?? DateTime.now().toUtc();
        if (box.get(remote.id) != null) {
          final localAt = DateTime.tryParse(sync.get('u:${remote.id}') ?? '');
          // No marker means a record we have not stamped yet: keep it.
          if (localAt == null || !remoteAt.isAfter(localAt)) continue;
        }
        await box.put(remote.id, remote.toJson());
        await sync.put('u:${remote.id}', remoteAt.toIso8601String());
        await sync.put('s:${remote.id}', remoteAt.toIso8601String());
        changed++;
      }
      return changed;
    } catch (_) {
      return 0;
    }
  }
}

final vehicleInspectionRepositoryProvider =
    Provider<VehicleInspectionRepository>(
  (ref) => VehicleInspectionRepository(),
);

/// Pulls from the cloud in the background (silent on failure) and calls
/// [onChanged] when something new arrived, so the list shows local data at
/// once instead of waiting on the network.
void _refreshInBackground(
  VehicleInspectionRepository repo,
  void Function() onChanged, {
  String? vehicleId,
}) {
  repo.refreshFromCloud(vehicleId: vehicleId).then((changed) {
    if (changed > 0) onChanged();
  }).catchError((_) {});
}

/// Every vehicle's inspections, for the inspection log.
final allVehicleInspectionsProvider =
    FutureProvider<List<VehicleInspection>>((ref) async {
  final repo = ref.watch(vehicleInspectionRepositoryProvider);
  var alive = true;
  ref.onDispose(() => alive = false);
  _refreshInBackground(repo, () {
    if (alive) ref.invalidateSelf();
  });
  return repo.listAll();
});

/// Inspection history for one vehicle, newest first.
final vehicleInspectionsProvider =
    FutureProvider.family<List<VehicleInspection>, String>(
        (ref, vehicleId) async {
  final repo = ref.watch(vehicleInspectionRepositoryProvider);
  var alive = true;
  ref.onDispose(() => alive = false);
  _refreshInBackground(repo, () {
    if (alive) ref.invalidateSelf();
  }, vehicleId: vehicleId);
  return repo.listForVehicle(vehicleId);
});
