import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../providers/equipment_providers.dart';
import '../../infra/repositories/equipment_repository.dart';
import 'equipment_labels.dart';

/// Filters bottom sheet. Only offers values present in the inspection history.
class EquipmentFiltersSheet extends ConsumerStatefulWidget {
  const EquipmentFiltersSheet({
    super.key,
    required this.currentFilters,
    required this.onApplyFilters,
  });

  final EquipmentSearchFilters currentFilters;
  final ValueChanged<EquipmentSearchFilters> onApplyFilters;

  @override
  ConsumerState<EquipmentFiltersSheet> createState() =>
      _EquipmentFiltersSheetState();
}

class _EquipmentFiltersSheetState extends ConsumerState<EquipmentFiltersSheet> {
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
                            avatar: Icon(
                              equipmentAssetTypeIcon(assetType),
                              size: 18,
                            ),
                            label: Text(equipmentAssetTypeLabel(assetType)),
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
                    _FilterSection(
                      title: 'Status',
                      icon: Icons.info_outline,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: EquipmentStatus.values.map((status) {
                          final selected = _filters.status == status;
                          return FilterChip(
                            label: Text(equipmentStatusLabel(status)),
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
}

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
