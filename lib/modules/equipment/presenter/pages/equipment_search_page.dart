import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../providers/equipment_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/asset_lookup.dart';
import '../asset_code_scanner.dart';
import '../recent_equipment_searches_provider.dart';
import '../widgets/asset_registration_sheet.dart';
import '../widgets/asset_site_assignment_sheet.dart';
import '../widgets/equipment_filters_sheet.dart';
import '../widgets/equipment_results.dart';
import '../widgets/equipment_search_bar.dart';

/// Width of the page body at which the list and detail pane sit side by side.
const double _twoPaneMaxContentWidth = 1280;

/// Equipment search page: search bar + filters on top, results below (with a
/// detail pane beside them on tablets).
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
  String? _selectedId;

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

  void _rememberQuery() {
    ref.read(recentEquipmentSearchesProvider.notifier).add(_searchQuery);
  }

  void _useRecent(String query) {
    _searchController.value = TextEditingValue(
      text: query,
      selection: TextSelection.collapsed(offset: query.length),
    );
    ref.read(recentEquipmentSearchesProvider.notifier).add(query);
  }

  Future<void> _scan() async {
    final scanned = await ref.read(assetCodeScannerProvider).scan(context);
    if (!mounted || scanned == null || scanned.trim().isEmpty) return;
    _useRecent(scanned.trim());
  }

  List<Equipment> _getFilteredEquipment(List<Equipment> allEquipment) {
    return allEquipment.where((equipment) {
      if (_searchQuery.isNotEmpty) {
        if (!assetMatchesLookup(equipment.toEntity(), _searchQuery)) {
          return false;
        }
      }

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
    final equipmentAsync = ref.watch(equipmentListProvider);
    final recent = ref.watch(recentEquipmentSearchesProvider);
    final scanner = ref.watch(assetCodeScannerProvider);
    final twoPane =
        AppBreakpoints.ofContext(context) == WindowSize.expanded;

    return AppPage(
      title: 'Asset Search',
      maxContentWidth:
          twoPane ? _twoPaneMaxContentWidth : kDefaultMaxContentWidth,
      fab: FloatingActionButton.extended(
        onPressed: _showRegistrationSheet,
        icon: const Icon(Icons.add),
        label: const Text('Register asset'),
      ),
      body: equipmentAsync.when(
        data: (allEquipment) {
          final filtered = _getFilteredEquipment(allEquipment);
          return Column(
            children: [
              EquipmentSearchBar(
                controller: _searchController,
                focusNode: _searchFocus,
                filters: _filters,
                recentSearches: recent,
                onFiltersChanged: _updateFilter,
                onOpenFilters: _showFiltersBottomSheet,
                onRecentSelected: _useRecent,
                onClearRecent: () => ref
                    .read(recentEquipmentSearchesProvider.notifier)
                    .clear(),
                onSubmitted: (_) => _rememberQuery(),
                onScan: scanner.isSupported ? _scan : null,
              ),
              Expanded(
                child: EquipmentResults(
                  equipment: filtered,
                  registryIsEmpty: allEquipment.isEmpty,
                  hasFilters: _filters.hasFilters,
                  twoPane: twoPane,
                  selectedId: _selectedId,
                  onSelect: (e) {
                    _rememberQuery();
                    setState(() => _selectedId = e.id);
                  },
                  onClearFilters: () =>
                      _updateFilter(const EquipmentSearchFilters()),
                  onEditAssignment: _showAssignmentSheet,
                  onOpened: _rememberQuery,
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

  void _showFiltersBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => EquipmentFiltersSheet(
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
}
