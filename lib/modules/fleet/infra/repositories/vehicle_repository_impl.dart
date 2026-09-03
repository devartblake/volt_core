import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../../core/services/sync/sync_context.dart';
import '../../../../core/services/sync/sync_service.dart';
import '../../domain/entities/vehicle_entity.dart';
import '../datasources/vehicle_remote_datasource.dart';
import '../datasources/vehicles_box.dart';
import '../mappers/vehicle_supabase_mapper.dart';
import '../models/vehicle_record.dart';
import 'vehicle_repository.dart';

typedef VehicleQueueWriter = Future<void> Function(VehicleEntity vehicle);
typedef TenantIdReader = String? Function();

/// Hive-backed fleet, with writes handed to the durable sync outbox.
///
/// Offline-first for the same reason inspections are: a vehicle is added or
/// corrected in a yard or a garage, which is exactly where signal is worst.
class VehicleRepositoryImpl implements VehicleRepository {
  VehicleRepositoryImpl({
    Box<VehicleRecord>? box,
    VehicleQueueWriter? queueWriter,
    TenantIdReader? tenantIdReader,
    VehicleRemoteDatasource? remote,
  })  : _injectedBox = box,
        _queueWriter = queueWriter ?? _enqueueToSync,
        _tenantIdReader = tenantIdReader ?? _readActiveTenantId,
        _remote = remote;

  /// Only set when a box is injected (tests). Otherwise resolved per use, so a
  /// HiveService reset cannot leave this repository holding a closed one.
  final Box<VehicleRecord>? _injectedBox;

  Box<VehicleRecord> get _box => _injectedBox ?? VehiclesBox.box;
  final VehicleQueueWriter _queueWriter;
  final TenantIdReader _tenantIdReader;
  final VehicleRemoteDatasource? _remote;

  static String? _readActiveTenantId() => SyncContext.tenantId;

  static Future<void> _enqueueToSync(VehicleEntity vehicle) {
    return SyncService.instance.enqueueUpsert(
      table: kFleetVehiclesTable,
      id: vehicle.id,
      payload: vehicleToSupabaseJson(vehicle),
    );
  }

  VehicleEntity _toEntity(VehicleRecord value) => VehicleEntity(
        id: value.id,
        tenantId: value.tenantId,
        designation: value.designation,
        vin: value.vin,
        licensePlate: value.licensePlate,
        make: value.make,
        model: value.model,
        modelYear: value.modelYear,
        vehicleType: VehicleTypeX.fromWire(value.vehicleType),
        odometer: value.odometer,
        status: VehicleStatusX.fromWire(value.status),
        assignedToUserId: value.assignedToUserId,
        notes: value.notes,
        lastCheckAt: value.lastCheckAt,
        createdAt: value.createdAt,
        updatedAt: value.updatedAt,
      );

  VehicleRecord _toRecord(VehicleEntity value) => VehicleRecord(
        id: value.id,
        tenantId: value.tenantId,
        designation: value.designation,
        vin: value.vin,
        licensePlate: value.licensePlate,
        make: value.make,
        model: value.model,
        modelYear: value.modelYear,
        vehicleType: value.vehicleType.wire,
        odometer: value.odometer,
        status: value.status.wire,
        assignedToUserId: value.assignedToUserId,
        notes: value.notes,
        lastCheckAt: value.lastCheckAt,
        createdAt: value.createdAt,
        updatedAt: value.updatedAt,
      );

  /// Pull server rows before returning the local list. Best-effort: dispatch
  /// keeps working from Hive while offline, and a locally newer row is never
  /// replaced by an older remote copy.
  Future<void> _hydrateFromRemote() async {
    final remote = _remote;
    if (remote == null) return;

    try {
      for (final vehicle in await remote.list()) {
        final local = _box.get(vehicle.id);
        if (local == null || vehicle.updatedAt.isAfter(local.updatedAt)) {
          await _box.put(vehicle.id, _toRecord(vehicle));
        }
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[Fleet] remote hydrate failed (using local only): $error');
      }
    }
  }

  @override
  Future<List<VehicleEntity>> list({String? assignedToUserId}) async {
    await _hydrateFromRemote();
    final tenantId = _tenantIdReader();

    final vehicles = _box.values
        .map(_toEntity)
        .where((v) => tenantId == null || v.tenantId == tenantId)
        .where(
          (v) => assignedToUserId == null || v.assignedToUserId == assignedToUserId,
        )
        .toList(growable: false)
      ..sort(_byDesignation);

    return vehicles;
  }

  /// Retired vehicles sink to the bottom; the rest sort by designation, which
  /// is what the crew calls them and how a paper board is ordered.
  static int _byDesignation(VehicleEntity a, VehicleEntity b) {
    final retiredA = a.status == VehicleStatus.retired ? 1 : 0;
    final retiredB = b.status == VehicleStatus.retired ? 1 : 0;
    if (retiredA != retiredB) return retiredA - retiredB;
    return a.displayTitle.toLowerCase().compareTo(b.displayTitle.toLowerCase());
  }

  @override
  Future<VehicleEntity?> getById(String id) async {
    final value = _box.get(id);
    if (value == null) return null;
    final tenantId = _tenantIdReader();
    if (tenantId != null && value.tenantId != tenantId) return null;
    return _toEntity(value);
  }

  @override
  Future<VehicleEntity> save(VehicleEntity vehicle) async {
    final tenantId = _tenantIdReader();
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('Select an active tenant before saving a vehicle.');
    }
    if (vehicle.tenantId != tenantId) {
      throw StateError('Vehicles can only be saved in the active tenant.');
    }

    final designation = vehicle.designation.trim();
    if (designation.isEmpty) {
      throw ArgumentError.value(
        vehicle.designation,
        'designation',
        'A vehicle needs a designation — this is what the crew calls it.',
      );
    }

    final vinProblem = validateVin(vehicle.vin);
    if (vinProblem != null) {
      throw ArgumentError.value(vehicle.vin, 'vin', vinProblem);
    }

    // Catch the collision here rather than letting the row reach the partial
    // unique index and come back as an opaque 23505 several seconds later,
    // after the technician has moved on.
    final normalizedVin = normalizeVin((vehicle.vin ?? '').trim());
    for (final other in _box.values) {
      if (other.id == vehicle.id) continue;
      if (other.tenantId != tenantId) continue;

      if (other.status != VehicleStatus.retired.wire &&
          vehicle.status != VehicleStatus.retired &&
          other.designation.trim().toLowerCase() ==
              designation.toLowerCase()) {
        throw StateError('Another vehicle is already called "$designation".');
      }
      if (normalizedVin.isNotEmpty &&
          normalizeVin((other.vin ?? '').trim()) == normalizedVin) {
        throw StateError(
          'VIN $normalizedVin already belongs to "${other.designation}".',
        );
      }
    }

    final updated = vehicle.copyWith(
      designation: designation,
      vin: normalizedVin.isEmpty ? null : normalizedVin,
      clearVin: normalizedVin.isEmpty,
      updatedAt: DateTime.now().toUtc(),
    );

    await _box.put(updated.id, _toRecord(updated));
    await _queueWriter(updated);
    return updated;
  }

  @override
  Future<VehicleEntity> assign(String vehicleId, String? userId) async {
    final existing = await getById(vehicleId);
    if (existing == null) throw StateError('Vehicle $vehicleId was not found.');

    final trimmed = (userId ?? '').trim();
    return save(
      existing.copyWith(
        assignedToUserId: trimmed.isEmpty ? null : trimmed,
        clearAssignee: trimmed.isEmpty,
      ),
    );
  }
}

final vehicleRepositoryProvider = Provider<VehicleRepository>((ref) {
  return VehicleRepositoryImpl(
    remote: ref.watch(vehicleRemoteDatasourceProvider),
  );
});
