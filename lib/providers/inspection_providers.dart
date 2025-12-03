import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Inspection Status Enum
enum InspectionStatus {
  pending,
  inProgress,
  completed,
  failed,
  cancelled,
}

/// Inspection Model
class Inspection {
  final String id;
  final String equipmentId;
  final String equipmentName;
  final String technician;
  final DateTime scheduledDate;
  final DateTime? completedDate;
  final InspectionStatus status;
  final String? notes;
  final Map<String, dynamic>? formData;
  final List<String>? photoUrls;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Inspection({
    required this.id,
    required this.equipmentId,
    required this.equipmentName,
    required this.technician,
    required this.scheduledDate,
    this.completedDate,
    required this.status,
    this.notes,
    this.formData,
    this.photoUrls,
    required this.createdAt,
    this.updatedAt,
  });

  Inspection copyWith({
    String? id,
    String? equipmentId,
    String? equipmentName,
    String? technician,
    DateTime? scheduledDate,
    DateTime? completedDate,
    InspectionStatus? status,
    String? notes,
    Map<String, dynamic>? formData,
    List<String>? photoUrls,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Inspection(
      id: id ?? this.id,
      equipmentId: equipmentId ?? this.equipmentId,
      equipmentName: equipmentName ?? this.equipmentName,
      technician: technician ?? this.technician,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      completedDate: completedDate ?? this.completedDate,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      formData: formData ?? this.formData,
      photoUrls: photoUrls ?? this.photoUrls,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isPending => status == InspectionStatus.pending;
  bool get isCompleted => status == InspectionStatus.completed;
  bool get isOverdue =>
      isPending && scheduledDate.isBefore(DateTime.now());

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'equipmentId': equipmentId,
      'equipmentName': equipmentName,
      'technician': technician,
      'scheduledDate': scheduledDate.toIso8601String(),
      'completedDate': completedDate?.toIso8601String(),
      'status': status.name,
      'notes': notes,
      'formData': formData,
      'photoUrls': photoUrls,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Inspection.fromJson(Map<String, dynamic> json) {
    return Inspection(
      id: json['id'] as String,
      equipmentId: json['equipmentId'] as String,
      equipmentName: json['equipmentName'] as String,
      technician: json['technician'] as String,
      scheduledDate: DateTime.parse(json['scheduledDate'] as String),
      completedDate: json['completedDate'] != null
          ? DateTime.parse(json['completedDate'] as String)
          : null,
      status: InspectionStatus.values.firstWhere(
            (e) => e.name == json['status'],
        orElse: () => InspectionStatus.pending,
      ),
      notes: json['notes'] as String?,
      formData: json['formData'] as Map<String, dynamic>?,
      photoUrls: (json['photoUrls'] as List<dynamic>?)?.cast<String>(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}

/// Inspection List State Notifier
class InspectionListNotifier extends StateNotifier<AsyncValue<List<Inspection>>> {
  InspectionListNotifier() : super(const AsyncValue.loading()) {
    loadInspections();
  }

  Future<void> loadInspections() async {
    state = const AsyncValue.loading();
    try {
      // TODO: Replace with your actual infra source
      final inspections = await _loadFromDataSource();
      state = AsyncValue.data(inspections);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> addInspection(Inspection inspection) async {
    try {
      // TODO: Save to your infra source
      state.whenData((inspectionList) {
        state = AsyncValue.data([...inspectionList, inspection]);
      });
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateInspection(Inspection inspection) async {
    try {
      // TODO: Update in your infra source
      state.whenData((inspectionList) {
        final index = inspectionList.indexWhere((i) => i.id == inspection.id);
        if (index != -1) {
          final updated = [...inspectionList];
          updated[index] = inspection;
          state = AsyncValue.data(updated);
        }
      });
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> deleteInspection(String id) async {
    try {
      // TODO: Delete from your infra source
      state.whenData((inspectionList) {
        state = AsyncValue.data(
          inspectionList.where((i) => i.id != id).toList(),
        );
      });
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    await loadInspections();
  }

  // TODO: Replace with actual infra loading
  Future<List<Inspection>> _loadFromDataSource() async {
    await Future.delayed(const Duration(milliseconds: 500));

    return [
      Inspection(
        id: '1',
        equipmentId: '1',
        equipmentName: 'Generator Unit A1',
        technician: 'John Doe',
        scheduledDate: DateTime.now().add(const Duration(days: 7)),
        status: InspectionStatus.pending,
        notes: 'Regular quarterly inspection',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      ),
      Inspection(
        id: '2',
        equipmentId: '2',
        equipmentName: 'Backup Generator B2',
        technician: 'Jane Smith',
        scheduledDate: DateTime.now().subtract(const Duration(days: 2)),
        completedDate: DateTime.now().subtract(const Duration(days: 1)),
        status: InspectionStatus.completed,
        notes: 'Load test completed successfully',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      Inspection(
        id: '3',
        equipmentId: '3',
        equipmentName: 'Emergency Generator C3',
        technician: 'Mike Johnson',
        scheduledDate: DateTime.now().subtract(const Duration(days: 5)),
        status: InspectionStatus.pending,
        notes: 'Awaiting parts for full inspection',
        createdAt: DateTime.now().subtract(const Duration(days: 15)),
      ),
    ];
  }
}

/// Main inspection list provider
final inspectionListProvider =
StateNotifierProvider<InspectionListNotifier, AsyncValue<List<Inspection>>>(
      (ref) => InspectionListNotifier(),
);

/// Get inspection by ID
final inspectionByIdProvider = Provider.family<Inspection?, String>((ref, id) {
  final inspectionList = ref.watch(inspectionListProvider);
  return inspectionList.whenData((list) {
    try {
      return list.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }).value;
});

/// Get inspections by status
final inspectionsByStatusProvider =
Provider.family<List<Inspection>, InspectionStatus>((ref, status) {
  final inspectionList = ref.watch(inspectionListProvider);
  return inspectionList.whenData((list) {
    return list.where((i) => i.status == status).toList();
  }).value ?? [];
});

/// Get pending inspections
final pendingInspectionsProvider = Provider<List<Inspection>>((ref) {
  return ref.watch(inspectionsByStatusProvider(InspectionStatus.pending));
});

/// Get completed inspections
final completedInspectionsProvider = Provider<List<Inspection>>((ref) {
  return ref.watch(inspectionsByStatusProvider(InspectionStatus.completed));
});

/// Get overdue inspections
final overdueInspectionsProvider = Provider<List<Inspection>>((ref) {
  final pending = ref.watch(pendingInspectionsProvider);
  final now = DateTime.now();
  return pending.where((i) => i.scheduledDate.isBefore(now)).toList();
});

/// Get upcoming inspections (next 7 days)
final upcomingInspectionsProvider = Provider<List<Inspection>>((ref) {
  final pending = ref.watch(pendingInspectionsProvider);
  final now = DateTime.now();
  final sevenDaysFromNow = now.add(const Duration(days: 7));

  return pending.where((i) {
    return i.scheduledDate.isAfter(now) &&
        i.scheduledDate.isBefore(sevenDaysFromNow);
  }).toList();
});

/// Get inspections by equipment ID
final inspectionsByEquipmentProvider =
Provider.family<List<Inspection>, String>((ref, equipmentId) {
  final inspectionList = ref.watch(inspectionListProvider);
  return inspectionList.whenData((list) {
    return list.where((i) => i.equipmentId == equipmentId).toList();
  }).value ?? [];
});

/// Get inspection counts
final inspectionCountsProvider = Provider<Map<InspectionStatus, int>>((ref) {
  final inspectionList = ref.watch(inspectionListProvider);
  return inspectionList.whenData((list) {
    final counts = <InspectionStatus, int>{};
    for (final status in InspectionStatus.values) {
      counts[status] = list.where((i) => i.status == status).length;
    }
    return counts;
  }).value ?? {};
});

/// Get total inspection count
final totalInspectionCountProvider = Provider<int>((ref) {
  final inspectionList = ref.watch(inspectionListProvider);
  return inspectionList.whenData((list) => list.length).value ?? 0;
});

/// Get pending count
final pendingInspectionCountProvider = Provider<int>((ref) {
  final pending = ref.watch(pendingInspectionsProvider);
  return pending.length;
});

/// Get overdue count
final overdueInspectionCountProvider = Provider<int>((ref) {
  final overdue = ref.watch(overdueInspectionsProvider);
  return overdue.length;
});