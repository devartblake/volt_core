import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Equipment Status Enum
enum EquipmentStatus {
  active,
  inactive,
  maintenance,
  retired,
}

/// Equipment Model (Nameplate)
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
  final DateTime createdAt;
  final DateTime? updatedAt;

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
    required this.createdAt,
    this.updatedAt,
  });

  Equipment copyWith({
    String? id,
    String? name,
    String? make,
    String? model,
    String? serialNumber,
    String? voltage,
    String? location,
    DateTime? lastInspection,
    EquipmentStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Equipment(
      id: id ?? this.id,
      name: name ?? this.name,
      make: make ?? this.make,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      voltage: voltage ?? this.voltage,
      location: location ?? this.location,
      lastInspection: lastInspection ?? this.lastInspection,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'make': make,
      'model': model,
      'serialNumber': serialNumber,
      'voltage': voltage,
      'location': location,
      'lastInspection': lastInspection?.toIso8601String(),
      'status': status.name,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      id: json['id'] as String,
      name: json['name'] as String,
      make: json['make'] as String,
      model: json['model'] as String,
      serialNumber: json['serialNumber'] as String,
      voltage: json['voltage'] as String,
      location: json['location'] as String,
      lastInspection: json['lastInspection'] != null
          ? DateTime.parse(json['lastInspection'] as String)
          : null,
      status: EquipmentStatus.values.firstWhere(
            (e) => e.name == json['status'],
        orElse: () => EquipmentStatus.active,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}

/// Equipment List State Notifier
class EquipmentListNotifier extends StateNotifier<AsyncValue<List<Equipment>>> {
  EquipmentListNotifier() : super(const AsyncValue.loading()) {
    loadEquipment();
  }

  /// Load all equipment from your infra source
  Future<void> loadEquipment() async {
    state = const AsyncValue.loading();
    try {
      // TODO: Replace with your actual infra source
      // Example: final equipment = await _equipmentRepository.getAll();
      final equipment = await _loadFromDataSource();
      state = AsyncValue.data(equipment);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Add new equipment
  Future<void> addEquipment(Equipment equipment) async {
    try {
      // TODO: Save to your infra source
      // await _equipmentRepository.create(equipment);

      state.whenData((equipmentList) {
        state = AsyncValue.data([...equipmentList, equipment]);
      });
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Update existing equipment
  Future<void> updateEquipment(Equipment equipment) async {
    try {
      // TODO: Update in your infra source
      // await _equipmentRepository.update(equipment);

      state.whenData((equipmentList) {
        final index = equipmentList.indexWhere((e) => e.id == equipment.id);
        if (index != -1) {
          final updated = [...equipmentList];
          updated[index] = equipment;
          state = AsyncValue.data(updated);
        }
      });
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Delete equipment
  Future<void> deleteEquipment(String id) async {
    try {
      // TODO: Delete from your infra source
      // await _equipmentRepository.delete(id);

      state.whenData((equipmentList) {
        state = AsyncValue.data(
          equipmentList.where((e) => e.id != id).toList(),
        );
      });
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  /// Refresh equipment list
  Future<void> refresh() async {
    await loadEquipment();
  }

  // TODO: Replace with actual infra loading
  Future<List<Equipment>> _loadFromDataSource() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // Return dummy infra for now
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
        createdAt: DateTime.now().subtract(const Duration(days: 365)),
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
        createdAt: DateTime.now().subtract(const Duration(days: 200)),
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
        createdAt: DateTime.now().subtract(const Duration(days: 100)),
      ),
      Equipment(
        id: '4',
        name: 'Standby Unit D4',
        make: 'Kohler',
        model: 'KD1500',
        serialNumber: 'KOH-2024-004',
        voltage: '240V',
        location: 'Building D - Exterior',
        lastInspection: DateTime.now().subtract(const Duration(days: 5)),
        status: EquipmentStatus.active,
        createdAt: DateTime.now().subtract(const Duration(days: 50)),
      ),
    ];
  }
}

/// Main equipment list provider
final equipmentListProvider =
StateNotifierProvider<EquipmentListNotifier, AsyncValue<List<Equipment>>>(
      (ref) => EquipmentListNotifier(),
);

/// Get single equipment by ID
final equipmentByIdProvider = Provider.family<Equipment?, String>((ref, id) {
  final equipmentList = ref.watch(equipmentListProvider);
  return equipmentList.whenData((list) {
    try {
      return list.firstWhere((e) => e.id == id);
    } catch (_) {
      return null;
    }
  }).value;
});

/// Get equipment count
final equipmentCountProvider = Provider<int>((ref) {
  final equipmentList = ref.watch(equipmentListProvider);
  return equipmentList.whenData((list) => list.length).value ?? 0;
});

/// Get equipment by status
final equipmentByStatusProvider =
Provider.family<List<Equipment>, EquipmentStatus>((ref, status) {
  final equipmentList = ref.watch(equipmentListProvider);
  return equipmentList.whenData((list) {
    return list.where((e) => e.status == status).toList();
  }).value ?? [];
});

/// Get active equipment count
final activeEquipmentCountProvider = Provider<int>((ref) {
  final activeEquipment = ref.watch(
    equipmentByStatusProvider(EquipmentStatus.active),
  );
  return activeEquipment.length;
});

/// Get equipment needing inspection (last inspection > 30 days ago)
final equipmentNeedingInspectionProvider = Provider<List<Equipment>>((ref) {
  final equipmentList = ref.watch(equipmentListProvider);
  return equipmentList.whenData((list) {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    return list.where((e) {
      if (e.lastInspection == null) return true;
      return e.lastInspection!.isBefore(thirtyDaysAgo);
    }).toList();
  }).value ?? [];
});

/// Get unique makes from all equipment
final equipmentMakesProvider = Provider<List<String>>((ref) {
  final equipmentList = ref.watch(equipmentListProvider);
  return equipmentList.whenData((list) {
    final makes = list.map((e) => e.make).toSet().toList();
    makes.sort();
    return makes;
  }).value ?? [];
});

/// Get unique voltages from all equipment
final equipmentVoltagesProvider = Provider<List<String>>((ref) {
  final equipmentList = ref.watch(equipmentListProvider);
  return equipmentList.whenData((list) {
    final voltages = list.map((e) => e.voltage).toSet().toList();
    voltages.sort();
    return voltages;
  }).value ?? [];
});

/// Get unique locations from all equipment
final equipmentLocationsProvider = Provider<List<String>>((ref) {
  final equipmentList = ref.watch(equipmentListProvider);
  return equipmentList.whenData((list) {
    final locations = list.map((e) => e.location).toSet().toList();
    locations.sort();
    return locations;
  }).value ?? [];
});
