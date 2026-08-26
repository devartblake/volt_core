import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/sync/sync_context.dart';
import '../../../../core/services/sync/sync_service.dart';
import '../../domain/entities/vehicle_maintenance_check.dart';
import '../datasources/vehicle_maintenance_checks_box.dart';
import '../mappers/vehicle_maintenance_check_supabase_mapper.dart';
import '../models/vehicle_maintenance_check_record.dart';
import 'vehicle_repository.dart';
import 'vehicle_repository_impl.dart';

typedef VehicleCheckQueueWriter = Future<void> Function(
  VehicleMaintenanceCheck check,
);

abstract class VehicleCheckRepository {
  /// Checks for one vehicle, newest first.
  Future<List<VehicleMaintenanceCheck>> listForVehicle(String vehicleId);

  /// Record a check.
  ///
  /// Throws [OdometerWentBackwards] when the reading is lower than the
  /// vehicle already shows, unless [allowOdometerRollback]. See that class for
  /// why this is a refusal rather than a silent accept.
  Future<VehicleMaintenanceCheck> save(
    VehicleMaintenanceCheck check, {
    bool allowOdometerRollback = false,
  });
}

class VehicleCheckRepositoryImpl implements VehicleCheckRepository {
  VehicleCheckRepositoryImpl({
    required VehicleRepository vehicles,
    Box<VehicleMaintenanceCheckRecord>? box,
    VehicleCheckQueueWriter? queueWriter,
    TenantIdReader? tenantIdReader,
    SupabaseClient? client,
  })  : _vehicles = vehicles,
        _injectedBox = box,
        _queueWriter = queueWriter ?? _enqueueToSync,
        _tenantIdReader = tenantIdReader ?? (() => SyncContext.tenantId),
        _client = client;

  final VehicleRepository _vehicles;
  final Box<VehicleMaintenanceCheckRecord>? _injectedBox;
  final VehicleCheckQueueWriter _queueWriter;
  final TenantIdReader _tenantIdReader;
  final SupabaseClient? _client;

  Box<VehicleMaintenanceCheckRecord> get _box =>
      _injectedBox ?? VehicleMaintenanceChecksBox.box;

  static Future<void> _enqueueToSync(VehicleMaintenanceCheck check) {
    return SyncService.instance.enqueueUpsert(
      table: kVehicleMaintenanceChecksTable,
      id: check.id,
      payload: vehicleCheckToSupabaseJson(check),
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

  VehicleMaintenanceCheck _toEntity(VehicleMaintenanceCheckRecord r) =>
      VehicleMaintenanceCheck(
        id: r.id,
        tenantId: r.tenantId,
        vehicleId: r.vehicleId,
        checkedAt: r.checkedAt,
        checkedByUserId: r.checkedByUserId,
        odometer: r.odometer,
        lastOilChangeAt: r.lastOilChangeAt,
        lastLubricantCheckAt: r.lastLubricantCheckAt,
        odometerAtLastService: r.odometerAtLastService,
        brakeStatus: CheckStatusX.fromWire(r.brakeStatus),
        batteryStatus: CheckStatusX.fromWire(r.batteryStatus),
        notes: r.notes,
        createdAt: r.createdAt,
        updatedAt: r.updatedAt,
      );

  VehicleMaintenanceCheckRecord _toRecord(VehicleMaintenanceCheck c) =>
      VehicleMaintenanceCheckRecord(
        id: c.id,
        tenantId: c.tenantId,
        vehicleId: c.vehicleId,
        checkedAt: c.checkedAt,
        checkedByUserId: c.checkedByUserId,
        odometer: c.odometer,
        lastOilChangeAt: c.lastOilChangeAt,
        lastLubricantCheckAt: c.lastLubricantCheckAt,
        odometerAtLastService: c.odometerAtLastService,
        brakeStatus: c.brakeStatus.wire,
        batteryStatus: c.batteryStatus.wire,
        notes: c.notes,
        createdAt: c.createdAt,
        updatedAt: c.updatedAt,
      );

  /// Best-effort pull, same contract as the vehicle repository: a technician
  /// keeps reading history from Hive while offline, and a locally newer row is
  /// never replaced by an older remote copy.
  Future<void> _hydrate(String vehicleId) async {
    final client = _supabase;
    final tenantId = _tenantIdReader();
    if (client == null || tenantId == null || tenantId.isEmpty) return;

    try {
      final response = await client
          .from(kVehicleMaintenanceChecksTable)
          .select()
          .eq('tenant_id', tenantId)
          .eq('vehicle_id', vehicleId)
          .order('checked_at', ascending: false);

      for (final row in (response as List).cast<Map<String, dynamic>>()) {
        final check = vehicleCheckFromSupabaseJson(row);
        final local = _box.get(check.id);
        if (local == null || check.updatedAt.isAfter(local.updatedAt)) {
          await _box.put(check.id, _toRecord(check));
        }
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[Fleet] check hydrate failed (using local only): $error');
      }
    }
  }

  @override
  Future<List<VehicleMaintenanceCheck>> listForVehicle(String vehicleId) async {
    await _hydrate(vehicleId);
    final tenantId = _tenantIdReader();

    return _box.values
        .map(_toEntity)
        .where((c) => c.vehicleId == vehicleId)
        .where((c) => tenantId == null || c.tenantId == tenantId)
        .toList(growable: false)
      // Newest first, with createdAt breaking ties: two checks backdated to
      // the same day are ordered by when they were actually written.
      ..sort((a, b) {
        final byChecked = b.checkedAt.compareTo(a.checkedAt);
        return byChecked != 0 ? byChecked : b.createdAt.compareTo(a.createdAt);
      });
  }

  @override
  Future<VehicleMaintenanceCheck> save(
    VehicleMaintenanceCheck check, {
    bool allowOdometerRollback = false,
  }) async {
    final tenantId = _tenantIdReader();
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('Select an active tenant before recording a check.');
    }
    if (check.tenantId != tenantId) {
      throw StateError('Checks can only be saved in the active tenant.');
    }

    final vehicle = await _vehicles.getById(check.vehicleId);
    if (vehicle == null) {
      throw StateError('Vehicle ${check.vehicleId} was not found.');
    }

    if (!allowOdometerRollback && check.odometer < vehicle.odometer) {
      throw OdometerWentBackwards(
        recorded: check.odometer,
        previous: vehicle.odometer,
      );
    }

    final saved = check.copyWith(updatedAt: DateTime.now().toUtc());
    await _box.put(saved.id, _toRecord(saved));
    await _queueWriter(saved);

    // Advance the vehicle's cached values so the fleet list is right
    // immediately, offline, without waiting for the server trigger to run.
    //
    // Only ever forward. A check backdated to last month must not drag the
    // odometer or the last-check date back — which is also exactly what
    // refresh_vehicle_check_cache() does server-side, so the two agree.
    final newest = saved.checkedAt;
    final shouldTouch = vehicle.lastCheckAt == null ||
        newest.isAfter(vehicle.lastCheckAt!) ||
        saved.odometer > vehicle.odometer;

    if (shouldTouch) {
      await _vehicles.save(
        vehicle.copyWith(
          odometer:
              saved.odometer > vehicle.odometer ? saved.odometer : vehicle.odometer,
          lastCheckAt: vehicle.lastCheckAt == null ||
                  newest.isAfter(vehicle.lastCheckAt!)
              ? newest
              : vehicle.lastCheckAt,
        ),
      );
    }

    return saved;
  }
}

final vehicleCheckRepositoryProvider = Provider<VehicleCheckRepository>((ref) {
  return VehicleCheckRepositoryImpl(
    vehicles: ref.watch(vehicleRepositoryProvider),
  );
});
