import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../modules/equipment/domain/entities/equipment_entity.dart' as domain;
import '../modules/equipment/infra/repositories/equipment_repository.dart';
import '../modules/equipment/infra/repositories/equipment_repository_impl.dart';

enum EquipmentStatus {
  active,
  inactive,
  maintenance,
  retired,
}

class Equipment {
  final String id;
  final String name;
  final String make;
  final String model;
  final String serialNumber;
  final String voltage;
  final String location;
  final DateTime? lastInspection;
  final EquipmentStatus status;

  const Equipment({
    required this.id,
    required this.name,
    required this.make,
    required this.model,
    required this.serialNumber,
    required this.voltage,
    required this.location,
    this.lastInspection,
    this.status = EquipmentStatus.active,
  });

  /// Adapt the domain entity the repository produces to the model the search
  /// UI renders. Extra context the entity carries (site code, grade, how many
  /// inspections) isn't shown by the current UI and is dropped here.
  factory Equipment.fromEntity(domain.EquipmentEntity e) {
    return Equipment(
      id: e.id,
      name: e.name,
      make: e.make,
      model: e.model,
      serialNumber: e.serialNumber,
      voltage: e.voltage,
      location: e.location,
      lastInspection: e.lastInspection,
      status: EquipmentStatus.values.byName(e.status.name),
    );
  }

  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: json['id'] as String,
      name: json['name'] as String,
      make: json['make'] as String,
      model: json['model'] as String,
      serialNumber: json['serial_number'] as String,
      voltage: json['voltage'] as String,
      location: json['location'] as String,
      lastInspection: json['last_inspection'] != null
          ? DateTime.parse(json['last_inspection'] as String)
          : null,
      status: EquipmentStatus.values.firstWhere(
        (e) => e.name == (json['status'] as String? ?? 'active'),
        orElse: () => EquipmentStatus.active,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'make': make,
      'model': model,
      'serial_number': serialNumber,
      'voltage': voltage,
      'location': location,
      'last_inspection': lastInspection?.toIso8601String(),
      'status': status.name,
    };
  }
}

/// Search Filters Model
class EquipmentSearchFilters {
  final String? make;
  final String? voltage;
  final EquipmentStatus? status;
  final String? location;

  const EquipmentSearchFilters({
    this.make,
    this.voltage,
    this.status,
    this.location,
  });

  EquipmentSearchFilters copyWith({
    String? make,
    String? voltage,
    EquipmentStatus? status,
    String? location,
    bool clearMake = false,
    bool clearVoltage = false,
    bool clearStatus = false,
    bool clearLocation = false,
  }) {
    return EquipmentSearchFilters(
      make: clearMake ? null : (make ?? this.make),
      voltage: clearVoltage ? null : (voltage ?? this.voltage),
      status: clearStatus ? null : (status ?? this.status),
      location: clearLocation ? null : (location ?? this.location),
    );
  }

  bool get hasFilters =>
      make != null || voltage != null || status != null || location != null;

  int get activeFilterCount {
    int count = 0;
    if (make != null) count++;
    if (voltage != null) count++;
    if (status != null) count++;
    if (location != null) count++;
    return count;
  }

  Map<String, dynamic> toJson() {
    return {
      'make': make,
      'voltage': voltage,
      'status': status?.name,
      'location': location,
    };
  }

  factory EquipmentSearchFilters.fromJson(Map<String, dynamic> json) {
    return EquipmentSearchFilters(
      make: json['make'] as String?,
      voltage: json['voltage'] as String?,
      status: json['status'] != null
          ? EquipmentStatus.values.firstWhere((e) => e.name == json['status'])
          : null,
      location: json['location'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EquipmentSearchFilters &&
          runtimeType == other.runtimeType &&
          make == other.make &&
          voltage == other.voltage &&
          status == other.status &&
          location == other.location;

  @override
  int get hashCode =>
      make.hashCode ^ voltage.hashCode ^ status.hashCode ^ location.hashCode;
}

/// Provider for the full list of equipment.
///
/// Backed by [EquipmentRepository], which derives the registry from the local
/// inspection history — one entry per physical generator, showing its latest
/// known state. Previously this returned hardcoded sample records.
final equipmentListProvider = FutureProvider<List<Equipment>>((ref) async {
  final repo = ref.watch(equipmentRepositoryProvider);
  final entities = await repo.listEquipment();
  return entities.map(Equipment.fromEntity).toList(growable: false);
});

/// Filter values actually present in the data, so the filter sheet never
/// offers a choice that would return nothing.
final equipmentFacetsProvider = FutureProvider<EquipmentFacets>((ref) async {
  final repo = ref.watch(equipmentRepositoryProvider);
  return repo.facets();
});
