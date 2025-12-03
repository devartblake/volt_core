import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Equipment/Nameplate model (adjust based on your actual model)
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
}

enum EquipmentStatus {
  active,
  inactive,
  maintenance,
  retired,
}

/// Search filters model
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
}

/// Equipment search page
class EquipmentSearchPage extends ConsumerStatefulWidget {
  const EquipmentSearchPage({super.key});

  @override
  ConsumerState<EquipmentSearchPage> createState() => _EquipmentSearchPageState();
}

class _EquipmentSearchPageState extends ConsumerState<EquipmentSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  EquipmentSearchFilters _filters = const EquipmentSearchFilters();
  String _searchQuery = '';
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
  }

  void _updateFilter(EquipmentSearchFilters newFilters) {
    setState(() {
      _filters = newFilters;
    });
  }

  void _clearFilters() {
    setState(() {
      _filters = const EquipmentSearchFilters();
    });
  }

  List<Equipment> _getFilteredEquipment() {
    // TODO: Replace with actual data from your provider
    // Example: ref.watch(equipmentProvider)
    final allEquipment = _getDummyEquipment();

    return allEquipment.where((equipment) {
      // Text search
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesName = equipment.name.toLowerCase().contains(query);
        final matchesMake = equipment.make.toLowerCase().contains(query);
        final matchesModel = equipment.model.toLowerCase().contains(query);
        final matchesSerial = equipment.serialNumber.toLowerCase().contains(query);
        final matchesLocation = equipment.location.toLowerCase().contains(query);

        if (!matchesName && !matchesMake && !matchesModel && !matchesSerial && !matchesLocation) {
          return false;
        }
      }

      // Filters
      if (_filters.make != null && equipment.make != _filters.make) return false;
      if (_filters.voltage != null && equipment.voltage != _filters.voltage) return false;
      if (_filters.status != null && equipment.status != _filters.status) return false;
      if (_filters.location != null && equipment.location != _filters.location) return false;

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final filteredEquipment = _getFilteredEquipment();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Equipment Search'),
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        )
            : null,
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search input
                TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  decoration: InputDecoration(
                    hintText: 'Search by name, make, model, serial, or location',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _searchFocus.requestFocus();
                      },
                    )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  ),
                  textInputAction: TextInputAction.search,
                ),
                const SizedBox(height: 12),

                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Filter button
                      FilterChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.filter_list, size: 18),
                            const SizedBox(width: 4),
                            Text('Filters'),
                            if (_filters.activeFilterCount > 0) ...[
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${_filters.activeFilterCount}',
                                  style: TextStyle(
                                    color: colorScheme.onPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        selected: _filters.hasFilters,
                        onSelected: (_) => _showFiltersBottomSheet(),
                      ),
                      const SizedBox(width: 8),

                      // Active filter chips
                      if (_filters.make != null) ...[
                        Chip(
                          avatar: const Icon(Icons.build_outlined, size: 18),
                          label: Text(_filters.make!),
                          onDeleted: () => _updateFilter(
                            _filters.copyWith(clearMake: true),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 18),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (_filters.voltage != null) ...[
                        Chip(
                          avatar: const Icon(Icons.electrical_services_outlined, size: 18),
                          label: Text(_filters.voltage!),
                          onDeleted: () => _updateFilter(
                            _filters.copyWith(clearVoltage: true),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 18),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (_filters.status != null) ...[
                        Chip(
                          avatar: Icon(_getStatusIcon(_filters.status!), size: 18),
                          label: Text(_getStatusLabel(_filters.status!)),
                          onDeleted: () => _updateFilter(
                            _filters.copyWith(clearStatus: true),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 18),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (_filters.location != null) ...[
                        Chip(
                          avatar: const Icon(Icons.location_on_outlined, size: 18),
                          label: Text(_filters.location!),
                          onDeleted: () => _updateFilter(
                            _filters.copyWith(clearLocation: true),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 18),
                        ),
                        const SizedBox(width: 8),
                      ],

                      // Clear all
                      if (_filters.hasFilters)
                        TextButton.icon(
                          onPressed: _clearFilters,
                          icon: const Icon(Icons.clear_all, size: 18),
                          label: const Text('Clear All'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: _buildResults(filteredEquipment, colorScheme, theme),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(List<Equipment> equipment, ColorScheme colorScheme, ThemeData theme) {
    if (_searchQuery.isEmpty && !_filters.hasFilters) {
      return _buildEmptyState(
        icon: Icons.search,
        title: 'Start Searching',
        message: 'Enter a search term or apply filters to find equipment',
        colorScheme: colorScheme,
      );
    }

    if (equipment.isEmpty) {
      return _buildEmptyState(
        icon: Icons.search_off,
        title: 'No Results Found',
        message: 'Try adjusting your search or filters',
        colorScheme: colorScheme,
        action: _filters.hasFilters
            ? TextButton.icon(
          onPressed: _clearFilters,
          icon: const Icon(Icons.clear_all),
          label: const Text('Clear Filters'),
        )
            : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Results count
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${equipment.length} ${equipment.length == 1 ? 'result' : 'results'} found',
            style: theme.textTheme.titleSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),

        // Results list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            itemCount: equipment.length,
            itemBuilder: (context, index) {
              return _EquipmentCard(
                equipment: equipment[index],
                searchQuery: _searchQuery,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    required ColorScheme colorScheme,
    Widget? action,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: 24),
              action,
            ],
          ],
        ),
      ),
    );
  }

  void _showFiltersBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FiltersBottomSheet(
        currentFilters: _filters,
        onApplyFilters: (filters) {
          _updateFilter(filters);
          Navigator.pop(context);
        },
      ),
    );
  }

  IconData _getStatusIcon(EquipmentStatus status) {
    switch (status) {
      case EquipmentStatus.active:
        return Icons.check_circle_outline;
      case EquipmentStatus.inactive:
        return Icons.pause_circle_outline;
      case EquipmentStatus.maintenance:
        return Icons.build_circle_outlined;
      case EquipmentStatus.retired:
        return Icons.cancel_outlined;
    }
  }

  String _getStatusLabel(EquipmentStatus status) {
    switch (status) {
      case EquipmentStatus.active:
        return 'Active';
      case EquipmentStatus.inactive:
        return 'Inactive';
      case EquipmentStatus.maintenance:
        return 'Maintenance';
      case EquipmentStatus.retired:
        return 'Retired';
    }
  }

  // TODO: Replace with actual data source
  List<Equipment> _getDummyEquipment() {
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
  }
}

/// Equipment card widget
class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({
    required this.equipment,
    required this.searchQuery,
  });

  final Equipment equipment;
  final String searchQuery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to equipment detail
          // TODO: Update with your actual navigation
          context.push('/nameplate/${equipment.id}');
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status indicator
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getStatusColor(equipment.status, colorScheme).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getStatusIcon(equipment.status),
                      color: _getStatusColor(equipment.status, colorScheme),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Equipment info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          equipment.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${equipment.make} ${equipment.model}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status chip
                  _StatusChip(status: equipment.status),
                ],
              ),

              const SizedBox(height: 16),

              // Details grid
              Row(
                children: [
                  Expanded(
                    child: _DetailItem(
                      icon: Icons.numbers,
                      label: 'Serial',
                      value: equipment.serialNumber,
                    ),
                  ),
                  Expanded(
                    child: _DetailItem(
                      icon: Icons.electrical_services_outlined,
                      label: 'Voltage',
                      value: equipment.voltage,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _DetailItem(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: equipment.location,
              ),
              if (equipment.lastInspection != null) ...[
                const SizedBox(height: 12),
                _DetailItem(
                  icon: Icons.calendar_today_outlined,
                  label: 'Last Inspection',
                  value: _formatDate(equipment.lastInspection!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(EquipmentStatus status, ColorScheme colorScheme) {
    switch (status) {
      case EquipmentStatus.active:
        return Colors.green;
      case EquipmentStatus.inactive:
        return Colors.grey;
      case EquipmentStatus.maintenance:
        return Colors.orange;
      case EquipmentStatus.retired:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(EquipmentStatus status) {
    switch (status) {
      case EquipmentStatus.active:
        return Icons.check_circle;
      case EquipmentStatus.inactive:
        return Icons.pause_circle;
      case EquipmentStatus.maintenance:
        return Icons.build_circle;
      case EquipmentStatus.retired:
        return Icons.cancel;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 30) return '$difference days ago';
    if (difference < 365) return '${(difference / 30).floor()} months ago';
    return '${(difference / 365).floor()} years ago';
  }
}

/// Status chip widget
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final EquipmentStatus status;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = _getStatusColor(status, colorScheme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        _getStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Color _getStatusColor(EquipmentStatus status, ColorScheme colorScheme) {
    switch (status) {
      case EquipmentStatus.active:
        return Colors.green;
      case EquipmentStatus.inactive:
        return Colors.grey;
      case EquipmentStatus.maintenance:
        return Colors.orange;
      case EquipmentStatus.retired:
        return Colors.red;
    }
  }

  String _getStatusLabel(EquipmentStatus status) {
    switch (status) {
      case EquipmentStatus.active:
        return 'Active';
      case EquipmentStatus.inactive:
        return 'Inactive';
      case EquipmentStatus.maintenance:
        return 'Maintenance';
      case EquipmentStatus.retired:
        return 'Retired';
    }
  }
}

/// Detail item widget
class _DetailItem extends StatelessWidget {
  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Filters bottom sheet
class _FiltersBottomSheet extends StatefulWidget {
  const _FiltersBottomSheet({
    required this.currentFilters,
    required this.onApplyFilters,
  });

  final EquipmentSearchFilters currentFilters;
  final ValueChanged<EquipmentSearchFilters> onApplyFilters;

  @override
  State<_FiltersBottomSheet> createState() => _FiltersBottomSheetState();
}

class _FiltersBottomSheetState extends State<_FiltersBottomSheet> {
  late EquipmentSearchFilters _filters;

  @override
  void initState() {
    super.initState();
    _filters = widget.currentFilters;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // TODO: Replace with actual data from your providers
    final makes = ['Caterpillar', 'Cummins', 'Generac', 'Kohler'];
    final voltages = ['120V', '208V', '240V', '480V'];
    final locations = ['Building A - Basement', 'Building B - Roof', 'Building C - Generator Room'];

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.filter_list, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      'Filters',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _filters = const EquipmentSearchFilters();
                        });
                      },
                      child: const Text('Clear All'),
                    ),
                  ],
                ),
              ),

              // Filter options
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Make filter
                    _FilterSection(
                      title: 'Make',
                      icon: Icons.build_outlined,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: makes.map((make) {
                          final selected = _filters.make == make;
                          return FilterChip(
                            label: Text(make),
                            selected: selected,
                            onSelected: (isSelected) {
                              setState(() {
                                _filters = _filters.copyWith(
                                  make: isSelected ? make : null,
                                  clearMake: !isSelected,
                                );
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Voltage filter
                    _FilterSection(
                      title: 'Voltage',
                      icon: Icons.electrical_services_outlined,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: voltages.map((voltage) {
                          final selected = _filters.voltage == voltage;
                          return FilterChip(
                            label: Text(voltage),
                            selected: selected,
                            onSelected: (isSelected) {
                              setState(() {
                                _filters = _filters.copyWith(
                                  voltage: isSelected ? voltage : null,
                                  clearVoltage: !isSelected,
                                );
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Status filter
                    _FilterSection(
                      title: 'Status',
                      icon: Icons.info_outline,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: EquipmentStatus.values.map((status) {
                          final selected = _filters.status == status;
                          return FilterChip(
                            label: Text(_getStatusLabel(status)),
                            selected: selected,
                            onSelected: (isSelected) {
                              setState(() {
                                _filters = _filters.copyWith(
                                  status: isSelected ? status : null,
                                  clearStatus: !isSelected,
                                );
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Location filter
                    _FilterSection(
                      title: 'Location',
                      icon: Icons.location_on_outlined,
                      child: Column(
                        children: locations.map((location) {
                          final selected = _filters.location == location;
                          return RadioListTile<String>(
                            title: Text(location),
                            value: location,
                            groupValue: _filters.location,
                            onChanged: (value) {
                              setState(() {
                                _filters = _filters.copyWith(
                                  location: value,
                                );
                              });
                            },
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),

              // Apply button
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => widget.onApplyFilters(_filters),
                    icon: const Icon(Icons.check),
                    label: Text(
                      'Apply Filters${_filters.activeFilterCount > 0 ? ' (${_filters.activeFilterCount})' : ''}',
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getStatusLabel(EquipmentStatus status) {
    switch (status) {
      case EquipmentStatus.active:
        return 'Active';
      case EquipmentStatus.inactive:
        return 'Inactive';
      case EquipmentStatus.maintenance:
        return 'Maintenance';
      case EquipmentStatus.retired:
        return 'Retired';
    }
  }
}

/// Filter section widget
class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}