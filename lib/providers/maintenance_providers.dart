import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Maintenance Status Enum
enum MaintenanceStatus {
  scheduled,
  inProgress,
  completed,
  cancelled,
  onHold,
}

/// Maintenance Priority Enum
enum MaintenancePriority {
  low,
  medium,
  high,
  urgent,
}

/// Maintenance Model
class MaintenanceJob {
  final String id;
  final String equipmentId;
  final String equipmentName;
  final String technician;
  final DateTime scheduledDate;
  final DateTime? completedDate;
  final MaintenanceStatus status;
  final MaintenancePriority priority;
  final String description;
  final String? notes;
  final List<String>? partsUsed;
  final double? cost;
  final int? durationMinutes;
  final Map<String, dynamic>? formData;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const MaintenanceJob({
    required this.id,
    required this.equipmentId,
    required this.equipmentName,
    required this.technician,
    required this.scheduledDate,
    this.completedDate,
    required this.status,
    this.priority = MaintenancePriority.medium,
    required this.description,
    this.notes,
    this.partsUsed,
    this.cost,
    this.durationMinutes,
    this.formData,
    required this.createdAt,
    this.updatedAt,
  });

  MaintenanceJob copyWith({
    String? id,
    String? equipmentId,
    String? equipmentName,
    String? technician,
    DateTime? scheduledDate,
    DateTime? completedDate,
    MaintenanceStatus? status,
    MaintenancePriority? priority,
    String? description,
    String? notes,
    List<String>? partsUsed,
    double? cost,
    int? durationMinutes,
    Map<String, dynamic>? formData,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MaintenanceJob(
      id: id ?? this.id,
      equipmentId: equipmentId ?? this.equipmentId,
      equipmentName: equipmentName ?? this.equipmentName,
      technician: technician ?? this.technician,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      completedDate: completedDate ?? this.completedDate,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      description: description ?? this.description,
      notes: notes ?? this.notes,
      partsUsed: partsUsed ?? this.partsUsed,
      cost: cost ?? this.cost,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      formData: formData ?? this.formData,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isCompleted => status == MaintenanceStatus.completed;
  bool get isScheduled => status == MaintenanceStatus.scheduled;
  bool get isOverdue =>
      isScheduled && scheduledDate.isBefore(DateTime.now());

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'equipmentId': equipmentId,
      'equipmentName': equipmentName,
      'technician': technician,
      'scheduledDate': scheduledDate.toIso8601String(),
      'completedDate': completedDate?.toIso8601String(),
      'status': status.name,
      'priority': priority.name,
      'description': description,
      'notes': notes,
      'partsUsed': partsUsed,
      'cost': cost,
      'durationMinutes': durationMinutes,
      'formData': formData,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory MaintenanceJob.fromJson(Map<String, dynamic> json) {
    return MaintenanceJob(
      id: json['id'] as String,
      equipmentId: json['equipmentId'] as String,
      equipmentName: json['equipmentName'] as String,
      technician: json['technician'] as String,
      scheduledDate: DateTime.parse(json['scheduledDate'] as String),
      completedDate: json['completedDate'] != null
          ? DateTime.parse(json['completedDate'] as String)
          : null,
      status: MaintenanceStatus.values.firstWhere(
            (e) => e.name == json['status'],
        orElse: () => MaintenanceStatus.scheduled,
      ),
      priority: MaintenancePriority.values.firstWhere(
            (e) => e.name == json['priority'],
        orElse: () => MaintenancePriority.medium,
      ),
      description: json['description'] as String,
      notes: json['notes'] as String?,
      partsUsed: (json['partsUsed'] as List<dynamic>?)?.cast<String>(),
      cost: (json['cost'] as num?)?.toDouble(),
      durationMinutes: json['durationMinutes'] as int?,
      formData: json['formData'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
    );
  }
}

/// Maintenance List State Notifier
class MaintenanceListNotifier
    extends StateNotifier<AsyncValue<List<MaintenanceJob>>> {
  MaintenanceListNotifier() : super(const AsyncValue.loading()) {
    loadMaintenanceJobs();
  }

  Future<void> loadMaintenanceJobs() async {
    state = const AsyncValue.loading();
    try {
      // TODO: Replace with your actual infra source
      final jobs = await _loadFromDataSource();
      state = AsyncValue.data(jobs);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> addMaintenanceJob(MaintenanceJob job) async {
    try {
      // TODO: Save to your infra source
      state.whenData((jobList) {
        state = AsyncValue.data([...jobList, job]);
      });
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> updateMaintenanceJob(MaintenanceJob job) async {
    try {
      // TODO: Update in your infra source
      state.whenData((jobList) {
        final index = jobList.indexWhere((j) => j.id == job.id);
        if (index != -1) {
          final updated = [...jobList];
          updated[index] = job;
          state = AsyncValue.data(updated);
        }
      });
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> deleteMaintenanceJob(String id) async {
    try {
      // TODO: Delete from your infra source
      state.whenData((jobList) {
        state = AsyncValue.data(
          jobList.where((j) => j.id != id).toList(),
        );
      });
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }

  Future<void> refresh() async {
    await loadMaintenanceJobs();
  }

  // TODO: Replace with actual infra loading
  Future<List<MaintenanceJob>> _loadFromDataSource() async {
    await Future.delayed(const Duration(milliseconds: 500));

    return [
      MaintenanceJob(
        id: '1',
        equipmentId: '1',
        equipmentName: 'Generator Unit A1',
        technician: 'John Doe',
        scheduledDate: DateTime.now().add(const Duration(days: 3)),
        status: MaintenanceStatus.scheduled,
        priority: MaintenancePriority.medium,
        description: 'Routine oil change and filter replacement',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      MaintenanceJob(
        id: '2',
        equipmentId: '2',
        equipmentName: 'Backup Generator B2',
        technician: 'Jane Smith',
        scheduledDate: DateTime.now().subtract(const Duration(days: 3)),
        completedDate: DateTime.now().subtract(const Duration(days: 2)),
        status: MaintenanceStatus.completed,
        priority: MaintenancePriority.high,
        description: 'Emergency repair - cooling system leak',
        notes: 'Replaced coolant hose and refilled system',
        partsUsed: ['Coolant hose', 'Coolant (5L)'],
        cost: 350.00,
        durationMinutes: 120,
        createdAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      MaintenanceJob(
        id: '3',
        equipmentId: '3',
        equipmentName: 'Emergency Generator C3',
        technician: 'Mike Johnson',
        scheduledDate: DateTime.now().add(const Duration(days: 1)),
        status: MaintenanceStatus.inProgress,
        priority: MaintenancePriority.urgent,
        description: 'Battery replacement and electrical testing',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }
}

/// Main maintenance list provider
final maintenanceListProvider =
StateNotifierProvider<MaintenanceListNotifier, AsyncValue<List<MaintenanceJob>>>(
      (ref) => MaintenanceListNotifier(),
);

/// Get maintenance job by ID
final maintenanceByIdProvider =
Provider.family<MaintenanceJob?, String>((ref, id) {
  final maintenanceList = ref.watch(maintenanceListProvider);
  return maintenanceList.whenData((list) {
    try {
      return list.firstWhere((j) => j.id == id);
    } catch (_) {
      return null;
    }
  }).value;
});

/// Get maintenance jobs by status
final maintenanceByStatusProvider =
Provider.family<List<MaintenanceJob>, MaintenanceStatus>((ref, status) {
  final maintenanceList = ref.watch(maintenanceListProvider);
  return maintenanceList.whenData((list) {
    return list.where((j) => j.status == status).toList();
  }).value ?? [];
});

/// Get scheduled maintenance jobs
final scheduledMaintenanceProvider = Provider<List<MaintenanceJob>>((ref) {
  return ref.watch(maintenanceByStatusProvider(MaintenanceStatus.scheduled));
});

/// Get in-progress maintenance jobs
final inProgressMaintenanceProvider = Provider<List<MaintenanceJob>>((ref) {
  return ref.watch(maintenanceByStatusProvider(MaintenanceStatus.inProgress));
});

/// Get completed maintenance jobs
final completedMaintenanceProvider = Provider<List<MaintenanceJob>>((ref) {
  return ref.watch(maintenanceByStatusProvider(MaintenanceStatus.completed));
});

/// Get overdue maintenance jobs
final overdueMaintenanceProvider = Provider<List<MaintenanceJob>>((ref) {
  final scheduled = ref.watch(scheduledMaintenanceProvider);
  final now = DateTime.now();
  return scheduled.where((j) => j.scheduledDate.isBefore(now)).toList();
});

/// Get maintenance jobs by priority
final maintenanceByPriorityProvider =
Provider.family<List<MaintenanceJob>, MaintenancePriority>((ref, priority) {
  final maintenanceList = ref.watch(maintenanceListProvider);
  return maintenanceList.whenData((list) {
    return list.where((j) => j.priority == priority).toList();
  }).value ?? [];
});

/// Get urgent maintenance jobs
final urgentMaintenanceProvider = Provider<List<MaintenanceJob>>((ref) {
  return ref.watch(maintenanceByPriorityProvider(MaintenancePriority.urgent));
});

/// Get maintenance jobs by equipment ID
final maintenanceByEquipmentProvider =
Provider.family<List<MaintenanceJob>, String>((ref, equipmentId) {
  final maintenanceList = ref.watch(maintenanceListProvider);
  return maintenanceList.whenData((list) {
    return list.where((j) => j.equipmentId == equipmentId).toList();
  }).value ?? [];
});

/// Get maintenance counts by status
final maintenanceCountsProvider =
Provider<Map<MaintenanceStatus, int>>((ref) {
  final maintenanceList = ref.watch(maintenanceListProvider);
  return maintenanceList.whenData((list) {
    final counts = <MaintenanceStatus, int>{};
    for (final status in MaintenanceStatus.values) {
      counts[status] = list.where((j) => j.status == status).length;
    }
    return counts;
  }).value ?? {};
});

/// Get total maintenance count
final totalMaintenanceCountProvider = Provider<int>((ref) {
  final maintenanceList = ref.watch(maintenanceListProvider);
  return maintenanceList.whenData((list) => list.length).value ?? 0;
});

/// Get active maintenance count (scheduled + in progress)
final activeMaintenanceCountProvider = Provider<int>((ref) {
  final scheduled = ref.watch(scheduledMaintenanceProvider);
  final inProgress = ref.watch(inProgressMaintenanceProvider);
  return scheduled.length + inProgress.length;
});

/// Get maintenance cost statistics
final maintenanceCostStatsProvider = Provider<Map<String, double>>((ref) {
  final completed = ref.watch(completedMaintenanceProvider);

  double total = 0;
  double average = 0;
  double min = 0;
  double max = 0;

  final jobsWithCost = completed.where((j) => j.cost != null).toList();

  if (jobsWithCost.isNotEmpty) {
    final costs = jobsWithCost.map((j) => j.cost!).toList();
    total = costs.reduce((a, b) => a + b);
    average = total / costs.length;
    min = costs.reduce((a, b) => a < b ? a : b);
    max = costs.reduce((a, b) => a > b ? a : b);
  }

  return {
    'total': total,
    'average': average,
    'min': min,
    'max': max,
  };
});