import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// Provider for the full list of equipment
final equipmentListProvider = FutureProvider<List<Equipment>>((ref) async {
  // TODO: Implement actual data fetching from repository
  // For now, returning dummy data as requested/implied by the project state
  await Future.delayed(const Duration(milliseconds: 500));
  return [
    Equipment(
      id: '1',
      name: 'Generator Unit A1',
      make: 'Caterpillar',
      model: 'C32',
      serialNumber: 'CAT-2024-001',
      voltage: '480V',
      location: 'Building A - Basement',
      lastInspection: DateTime.now().subtract(const Duration(days: 30)),
      status: EquipmentStatus.active,
    ),
    Equipment(
      id: '2',
      name: 'Backup Generator B2',
      make: 'Cummins',
      model: 'QSX15',
      serialNumber: 'CUM-2024-002',
      voltage: '208V',
      location: 'Building B - Roof',
      lastInspection: DateTime.now().subtract(const Duration(days: 15)),
      status: EquipmentStatus.active,
    ),
    Equipment(
      id: '3',
      name: 'Emergency Generator C3',
      make: 'Generac',
      model: 'MD200',
      serialNumber: 'GEN-2024-003',
      voltage: '480V',
      location: 'Building C - Generator Room',
      lastInspection: DateTime.now().subtract(const Duration(days: 60)),
      status: EquipmentStatus.maintenance,
    ),
  ];
});
