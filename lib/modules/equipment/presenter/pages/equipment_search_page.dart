import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../providers/equipment_providers.dart';
import '../../infra/repositories/equipment_repository.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/entities/equipment_entity.dart' show AssetType;
import '../../domain/asset_lookup.dart';
import '../widgets/asset_registration_sheet.dart';
import '../widgets/asset_site_assignment_sheet.dart';

/// Equipment search page
class EquipmentSearchPage extends ConsumerStatefulWidget {
  const EquipmentSearchPage({super.key});

  @override
  ConsumerState<EquipmentSearchPage> createState() =>
      _EquipmentSearchPageState();
}

class _EquipmentSearchPageState extends ConsumerState<EquipmentSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  EquipmentSearchFilters _filters = const EquipmentSearchFilters();
  String _searchQuery = '';

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

  List<Equipment> _getFilteredEquipment(List<Equipment> allEquipment) {
    return allEquipment.where((equipment) {
      // Text search
      if (_searchQuery.isNotEmpty) {
        if (!assetMatchesLookup(
          equipment.toEntity(),
          _searchQuery,
        )) {
          return false;
        }
      }

      // Filters
      if (_filters.make != null && equipment.make != _filters.make) {
        return false;
      }
      if (_filters.voltage != null && equipment.voltage != _filters.voltage) {
        return false;
      }
      if (_filters.assetType != null &&
          equipment.assetType != _filters.assetType) {
        return false;
      }
      if (_filters.status != null && equipment.status != _filters.status) {
        return false;
      }
      if (_filters.location != null &&
          equipment.location != _filters.location) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final equipmentAsync = ref.watch(equipmentListProvider);

    return AppPage(
      title: 'Equipment Search',
      fab: FloatingActionButton.extended(
        onPressed: _showRegistrationSheet,
        icon: const Icon(Icons.add),
        label: const Text('Register asset'),
      ),
      body: equipmentAsync.when(
        data: (allEquipment) {
          final filteredEquipment = _getFilteredEquipment(allEquipment);
          return Column(
            children: [
              // Search bar
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
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
                        hintText:
                            'Scan or search asset ID, serial, site, or location',
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
                        fillColor: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
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
                                const Text('Filters'),
                                if (_filters.activeFilterCount > 0) ...[
                                  const SizedBox(width: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
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
                              avatar: const Icon(
                                Icons.build_outlined,
                                size: 18,
                              ),
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
                              avatar: const Icon(
                                Icons.electrical_services_outlined,
                                size: 18,
                              ),
                              label: Text(_filters.voltage!),
                              onDeleted: () => _updateFilter(
                                _filters.copyWith(clearVoltage: true),
                              ),
                              deleteIcon: const Icon(Icons.close, size: 18),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (_filters.assetType != null) ...[
                            Chip(
                              avatar: Icon(
                                _assetTypeIcon(_filters.assetType!),
                                size: 18,
                              ),
                              label: Text(_assetTypeLabel(_filters.assetType!)),
                              onDeleted: () => _updateFilter(
                                _filters.copyWith(clearAssetType: true),
                              ),
                              deleteIcon: const Icon(Icons.close, size: 18),
                            ),
                            const SizedBox(width: 8),
                          ],
                          if (_filters.status != null) ...[
                            Chip(
                              avatar: Icon(
                                _getStatusIcon(_filters.status!),
                                size: 18,
                              ),
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
                              avatar: const Icon(
                                Icons.location_on_outlined,
                                size: 18,
                              ),
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
                child: _buildResults(
                  filteredEquipment,
                  colorScheme,
                  theme,
                  registryIsEmpty: allEquipment.isEmpty,
                ),
              ),
            ],
          );
        },
        loading: () => const LoadingIndicator(),
        error: (error, stack) => EmptyState.error(
          title: 'Could not load equipment',
          message: '$error',
        ),
      ),
    );
  }

  Widget _buildResults(
    List<Equipment> equipment,
    ColorScheme colorScheme,
    ThemeData theme, {
    required bool registryIsEmpty,
  }) {
    // Nothing has ever been inspected: explain where equipment comes from
    // rather than showing a bare "no results".
    if (registryIsEmpty) {
      return const EmptyState(
        icon: Icons.precision_manufacturing_outlined,
        title: 'No equipment yet',
        message:
            'Assets appear here once they are registered or inspected. '
            'Generator inspections remain supported as the first workflow.',
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
                onEditAssignment: equipment[index].hasInspectionLink
                    ? null
                    : () => _showAssignmentSheet(equipment[index]),
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
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
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
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[const SizedBox(height: 24), action],
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

  void _showRegistrationSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AssetRegistrationSheet(),
    );
  }

  void _showAssignmentSheet(Equipment equipment) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AssetSiteAssignmentSheet(asset: equipment.toEntity()),
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
}

/// Equipment card widget
class _EquipmentCard extends StatelessWidget {
  const _EquipmentCard({required this.equipment, required this.searchQuery, this.onEditAssignment});

  final Equipment equipment;
  final String searchQuery;
  final VoidCallback? onEditAssignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant, width: 1),
      ),
      child: InkWell(
        onTap: equipment.hasInspectionLink
            ? () => context.push('/nameplate/${equipment.id}')
            : null,
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
                      color: _statusColor(
                        equipment.status,
                        theme,
                      ).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getStatusIcon(equipment.status),
                      color: _statusColor(equipment.status, theme),
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
                        const SizedBox(height: 4),
                        Text(
                          _assetTypeLabel(equipment.assetType),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status chip
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _StatusChip(status: equipment.status),
                      if (onEditAssignment != null)
                        IconButton(
                          tooltip: 'Edit site assignment',
                          onPressed: onEditAssignment,
                          icon: const Icon(Icons.edit_location_alt_outlined),
                        ),
                    ],
                  ),
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
              if (equipment.siteCode.isNotEmpty) ...[
                const SizedBox(height: 12),
                _DetailItem(
                  icon: Icons.location_city_outlined,
                  label: 'Site code',
                  value: equipment.siteCode,
                ),
              ],
              if (equipment.lastInspection != null) ...[
                const SizedBox(height: 12),
                _DetailItem(
                  icon: Icons.calendar_today_outlined,
                  label: 'Last Inspection',
                  value: _formatDate(equipment.lastInspection!),
                ),
              ],
              if (equipment.inspectionCount > 0) ...[
                const SizedBox(height: 12),
                _DetailItem(
                  icon: Icons.history_outlined,
                  label: 'History',
                  value:
                      '${equipment.inspectionCount} ${equipment.inspectionCount == 1 ? 'inspection' : 'inspections'}',
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => context.push(
                      '/equipment/history/${equipment.id}',
                    ),
                    icon: const Icon(Icons.history, size: 18),
                    label: const Text('View history'),
                  ),
                ),
              ],
              if (!equipment.hasInspectionLink) ...[
                const SizedBox(height: 12),
                Text(
                  'Registered asset — inspection not yet recorded',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
    final theme = Theme.of(context);
    final color = _statusColor(status, theme);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
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
        Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
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
class _FiltersBottomSheet extends ConsumerStatefulWidget {
  const _FiltersBottomSheet({
    required this.currentFilters,
    required this.onApplyFilters,
  });

  final EquipmentSearchFilters currentFilters;
  final ValueChanged<EquipmentSearchFilters> onApplyFilters;

  @override
  ConsumerState<_FiltersBottomSheet> createState() =>
      _FiltersBottomSheetState();
}

class _FiltersBottomSheetState extends ConsumerState<_FiltersBottomSheet> {
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

    // Only offer filter values that exist in the inspection history, so a
    // filter can never produce an empty result by construction.
    final facets = ref
        .watch(equipmentFacetsProvider)
        .maybeWhen(data: (f) => f, orElse: () => const EquipmentFacets());
    final makes = facets.makes;
    final voltages = facets.voltages;
    final locations = facets.locations;
    final assetTypes = facets.assetTypes;

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

                    _FilterSection(
                      title: 'Asset type',
                      icon: Icons.category_outlined,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: assetTypes.map((assetType) {
                          final selected = _filters.assetType == assetType;
                          return FilterChip(
                            avatar: Icon(_assetTypeIcon(assetType), size: 18),
                            label: Text(_assetTypeLabel(assetType)),
                            selected: selected,
                            onSelected: (isSelected) {
                              setState(() {
                                _filters = _filters.copyWith(
                                  assetType: isSelected ? assetType : null,
                                  clearAssetType: !isSelected,
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
                      // RadioGroup owns the selection; per-tile groupValue and
                      // onChanged are deprecated.
                      child: RadioGroup<String>(
                        groupValue: _filters.location,
                        onChanged: (value) {
                          setState(() {
                            _filters = _filters.copyWith(location: value);
                          });
                        },
                        child: Column(
                          children: locations.map((location) {
                            return RadioListTile<String>(
                              title: Text(location),
                              value: location,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            );
                          }).toList(),
                        ),
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
            Icon(icon, size: 20, color: colorScheme.primary),
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

String _assetTypeLabel(AssetType assetType) {
  switch (assetType) {
    case AssetType.generator:
      return 'Generator';
    case AssetType.transferSwitch:
      return 'Transfer switch';
    case AssetType.switchgear:
      return 'Switchgear';
    case AssetType.panelboard:
      return 'Panelboard';
    case AssetType.transformer:
      return 'Transformer';
    case AssetType.emergencyLighting:
      return 'Emergency lighting';
    case AssetType.ups:
      return 'UPS';
    case AssetType.evCharger:
      return 'EV charger';
    case AssetType.batteryEnergyStorage:
      return 'Battery energy storage';
    case AssetType.other:
      return 'Other asset';
  }
}

IconData _assetTypeIcon(AssetType assetType) {
  switch (assetType) {
    case AssetType.generator:
      return Icons.settings_power_outlined;
    case AssetType.transferSwitch:
      return Icons.swap_horiz_outlined;
    case AssetType.switchgear:
      return Icons.electrical_services_outlined;
    case AssetType.panelboard:
      return Icons.grid_view_outlined;
    case AssetType.transformer:
      return Icons.power_outlined;
    case AssetType.emergencyLighting:
      return Icons.emergency_outlined;
    case AssetType.ups:
      return Icons.battery_charging_full_outlined;
    case AssetType.evCharger:
      return Icons.ev_station_outlined;
    case AssetType.batteryEnergyStorage:
      return Icons.battery_saver_outlined;
    case AssetType.other:
      return Icons.precision_manufacturing_outlined;
  }
}

/// Colour for an equipment status.
///
/// `_EquipmentCard` and `_StatusChip` each carried a private copy of this that
/// took a [ColorScheme], ignored it, and returned raw `Colors.*` — so the
/// status dots stayed mid-tone in dark mode.
Color _statusColor(EquipmentStatus status, ThemeData theme) {
  switch (status) {
    case EquipmentStatus.active:
      return theme.status.success;
    case EquipmentStatus.inactive:
      // Not a problem, just not in service: neutral rather than a status hue.
      return theme.colorScheme.outline;
    case EquipmentStatus.maintenance:
      return theme.status.warning;
    case EquipmentStatus.retired:
      return theme.colorScheme.error;
  }
}
