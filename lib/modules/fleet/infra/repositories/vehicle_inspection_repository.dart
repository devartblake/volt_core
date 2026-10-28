import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../domain/entities/vehicle_inspection.dart';

/// Adapter-free, on-device store for [VehicleInspection]s: a plain
/// `Box<String>` of JSON keyed by id, like photo metadata.
///
/// Local only for now — these are not yet synced to Supabase.
class VehicleInspectionRepository {
  VehicleInspectionRepository({Box<String>? box}) : _injected = box;

  static const String boxName = 'vehicle_inspections';

  final Box<String>? _injected;

  Future<Box<String>> _box() async {
    final injected = _injected;
    if (injected != null) return injected;
    if (Hive.isBoxOpen(boxName)) return Hive.box<String>(boxName);
    return Hive.openBox<String>(boxName);
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

  Future<void> save(VehicleInspection inspection) async {
    final box = await _box();
    await box.put(inspection.id, inspection.toJson());
  }

  Future<void> delete(String id) async {
    final box = await _box();
    await box.delete(id);
  }
}

final vehicleInspectionRepositoryProvider =
    Provider<VehicleInspectionRepository>(
  (ref) => VehicleInspectionRepository(),
);

/// Inspection history for one vehicle, newest first.
final vehicleInspectionsProvider =
    FutureProvider.family<List<VehicleInspection>, String>(
  (ref, vehicleId) =>
      ref.watch(vehicleInspectionRepositoryProvider).listForVehicle(vehicleId),
);
