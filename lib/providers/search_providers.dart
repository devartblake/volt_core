import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'equipment_providers.dart';

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
      make.hashCode ^
      voltage.hashCode ^
      status.hashCode ^
      location.hashCode;
}

/// Search query provider
final equipmentSearchQueryProvider = StateProvider<String>((ref) => '');

/// Search filters provider
final equipmentSearchFiltersProvider =
StateProvider<EquipmentSearchFilters>((ref) {
  return const EquipmentSearchFilters();
});

/// Filtered equipment provider
/// Combines search query and filters to return filtered results
final filteredEquipmentProvider = Provider<List<Equipment>>((ref) {
  final allEquipment = ref.watch(equipmentListProvider);
  final searchQuery = ref.watch(equipmentSearchQueryProvider);
  final filters = ref.watch(equipmentSearchFiltersProvider);

  return allEquipment.when(
    data: (equipmentList) {
      return equipmentList.where((equipment) {
        // Text search
        if (searchQuery.isNotEmpty) {
          final query = searchQuery.toLowerCase();
          final matchesName = equipment.name.toLowerCase().contains(query);
          final matchesMake = equipment.make.toLowerCase().contains(query);
          final matchesModel = equipment.model.toLowerCase().contains(query);
          final matchesSerial =
          equipment.serialNumber.toLowerCase().contains(query);
          final matchesLocation =
          equipment.location.toLowerCase().contains(query);

          if (!matchesName &&
              !matchesMake &&
              !matchesModel &&
              !matchesSerial &&
              !matchesLocation) {
            return false;
          }
        }

        // Filters
        if (filters.make != null && equipment.make != filters.make) {
          return false;
        }
        if (filters.voltage != null && equipment.voltage != filters.voltage) {
          return false;
        }
        if (filters.status != null && equipment.status != filters.status) {
          return false;
        }
        if (filters.location != null &&
            equipment.location != filters.location) {
          return false;
        }

        return true;
      }).toList();
    },
    loading: () => [],
    error: (_, __) => [],
  );
});

/// Search result count provider
final searchResultCountProvider = Provider<int>((ref) {
  final filtered = ref.watch(filteredEquipmentProvider);
  return filtered.length;
});

/// Has active search provider
final hasActiveSearchProvider = Provider<bool>((ref) {
  final query = ref.watch(equipmentSearchQueryProvider);
  final filters = ref.watch(equipmentSearchFiltersProvider);
  return query.isNotEmpty || filters.hasFilters;
});

/// Search history provider (stores recent searches)
class SearchHistoryNotifier extends StateNotifier<List<String>> {
  SearchHistoryNotifier() : super([]);

  static const int maxHistoryItems = 10;

  void addSearch(String query) {
    if (query.isEmpty) return;

    // Remove if already exists
    state = state.where((s) => s != query).toList();

    // Add to beginning
    state = [query, ...state];

    // Limit to max items
    if (state.length > maxHistoryItems) {
      state = state.sublist(0, maxHistoryItems);
    }
  }

  void removeSearch(String query) {
    state = state.where((s) => s != query).toList();
  }

  void clearHistory() {
    state = [];
  }
}

final searchHistoryProvider =
StateNotifierProvider<SearchHistoryNotifier, List<String>>((ref) {
  return SearchHistoryNotifier();
});

/// Saved filter presets provider
class FilterPreset {
  final String id;
  final String name;
  final EquipmentSearchFilters filters;

  const FilterPreset({
    required this.id,
    required this.name,
    required this.filters,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'filters': filters.toJson(),
    };
  }

  factory FilterPreset.fromJson(Map<String, dynamic> json) {
    return FilterPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      filters: EquipmentSearchFilters.fromJson(
        json['filters'] as Map<String, dynamic>,
      ),
    );
  }
}

class SavedFiltersNotifier extends StateNotifier<List<FilterPreset>> {
  SavedFiltersNotifier() : super(_defaultPresets);

  static const List<FilterPreset> _defaultPresets = [
    FilterPreset(
      id: 'active',
      name: 'Active Equipment',
      filters: EquipmentSearchFilters(status: EquipmentStatus.active),
    ),
    FilterPreset(
      id: 'maintenance',
      name: 'In Maintenance',
      filters: EquipmentSearchFilters(status: EquipmentStatus.maintenance),
    ),
  ];

  void addPreset(FilterPreset preset) {
    state = [...state, preset];
  }

  void removePreset(String id) {
    state = state.where((p) => p.id != id).toList();
  }

  void updatePreset(FilterPreset preset) {
    final index = state.indexWhere((p) => p.id == preset.id);
    if (index != -1) {
      final updated = [...state];
      updated[index] = preset;
      state = updated;
    }
  }
}

final savedFiltersProvider =
StateNotifierProvider<SavedFiltersNotifier, List<FilterPreset>>((ref) {
  return SavedFiltersNotifier();
});

/// Quick filter providers for common searches
final activeEquipmentProvider = Provider<List<Equipment>>((ref) {
  final allEquipment = ref.watch(equipmentListProvider);
  return allEquipment.whenData((list) {
    return list.where((e) => e.status == EquipmentStatus.active).toList();
  }).value ?? [];
});

final maintenanceEquipmentProvider = Provider<List<Equipment>>((ref) {
  final allEquipment = ref.watch(equipmentListProvider);
  return allEquipment.whenData((list) {
    return list.where((e) => e.status == EquipmentStatus.maintenance).toList();
  }).value ?? [];
});

final recentlyInspectedProvider = Provider<List<Equipment>>((ref) {
  final allEquipment = ref.watch(equipmentListProvider);
  return allEquipment.whenData((list) {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    return list.where((e) {
      return e.lastInspection != null &&
          e.lastInspection!.isAfter(sevenDaysAgo);
    }).toList();
  }).value ?? [];
});

/// Search suggestions provider
/// Returns equipment that partially match the current query
final searchSuggestionsProvider = Provider<List<Equipment>>((ref) {
  final query = ref.watch(equipmentSearchQueryProvider);
  if (query.isEmpty || query.length < 2) return [];

  final allEquipment = ref.watch(equipmentListProvider);
  return allEquipment.when(
    data: (equipmentList) {
      final q = query.toLowerCase();
      return equipmentList.where((e) {
        return e.name.toLowerCase().contains(q) ||
            e.make.toLowerCase().contains(q) ||
            e.model.toLowerCase().contains(q) ||
            e.serialNumber.toLowerCase().contains(q);
      }).take(5).toList(); // Limit to 5 suggestions
    },
    loading: () => [],
    error: (_, __) => [],
  );
});