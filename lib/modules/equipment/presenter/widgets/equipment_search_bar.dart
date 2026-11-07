import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../providers/equipment_providers.dart';
import 'equipment_labels.dart';

/// Search field, filter chips and (when the field is empty) recent searches.
class EquipmentSearchBar extends StatelessWidget {
  const EquipmentSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.filters,
    required this.recentSearches,
    required this.onFiltersChanged,
    required this.onOpenFilters,
    required this.onRecentSelected,
    required this.onClearRecent,
    required this.onSubmitted,
    this.onScan,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final EquipmentSearchFilters filters;
  final List<String> recentSearches;
  final ValueChanged<EquipmentSearchFilters> onFiltersChanged;
  final VoidCallback onOpenFilters;
  final ValueChanged<String> onRecentSelected;
  final VoidCallback onClearRecent;
  final ValueChanged<String> onSubmitted;

  /// Null hides the Scan button (no camera on this platform).
  final VoidCallback? onScan;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasQuery = controller.text.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
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
          TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              hintText: 'Scan or search asset ID, serial, site, or location',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasQuery)
                    IconButton(
                      tooltip: 'Clear',
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        controller.clear();
                        focusNode.requestFocus();
                      },
                    ),
                  if (onScan != null)
                    IconButton(
                      tooltip: 'Scan',
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: onScan,
                    ),
                ],
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor:
                  colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            textInputAction: TextInputAction.search,
            onSubmitted: onSubmitted,
          ),
          const SizedBox(height: AppSpacing.md),
          _FilterRow(
            filters: filters,
            onChanged: onFiltersChanged,
            onOpenFilters: onOpenFilters,
          ),
          if (!hasQuery && recentSearches.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _RecentSearches(
              recent: recentSearches,
              onSelected: onRecentSelected,
              onClear: onClearRecent,
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentSearches extends StatelessWidget {
  const _RecentSearches({
    required this.recent,
    required this.onSelected,
    required this.onClear,
  });

  final List<String> recent;
  final ValueChanged<String> onSelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent searches',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            TextButton(onPressed: onClear, child: const Text('Clear')),
          ],
        ),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final q in recent)
              ActionChip(
                avatar: const Icon(Icons.history, size: 18),
                label: Text(q),
                onPressed: () => onSelected(q),
              ),
          ],
        ),
      ],
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.filters,
    required this.onChanged,
    required this.onOpenFilters,
  });

  final EquipmentSearchFilters filters;
  final ValueChanged<EquipmentSearchFilters> onChanged;
  final VoidCallback onOpenFilters;

  Widget _chip(IconData icon, String label, EquipmentSearchFilters cleared) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: Chip(
        avatar: Icon(icon, size: 18),
        label: Text(label),
        onDeleted: () => onChanged(cleared),
        deleteIcon: const Icon(Icons.close, size: 18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.filter_list, size: 18),
                const SizedBox(width: AppSpacing.xs),
                const Text('Filters'),
                if (filters.activeFilterCount > 0) ...[
                  const SizedBox(width: AppSpacing.xs),
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
                      '${filters.activeFilterCount}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            selected: filters.hasFilters,
            onSelected: (_) => onOpenFilters(),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (filters.make != null)
            _chip(Icons.build_outlined, filters.make!,
                filters.copyWith(clearMake: true)),
          if (filters.voltage != null)
            _chip(Icons.electrical_services_outlined, filters.voltage!,
                filters.copyWith(clearVoltage: true)),
          if (filters.assetType != null)
            _chip(
                equipmentAssetTypeIcon(filters.assetType!),
                equipmentAssetTypeLabel(filters.assetType!),
                filters.copyWith(clearAssetType: true)),
          if (filters.status != null)
            _chip(
                equipmentStatusOutlineIcon(filters.status!),
                equipmentStatusLabel(filters.status!),
                filters.copyWith(clearStatus: true)),
          if (filters.location != null)
            _chip(Icons.location_on_outlined, filters.location!,
                filters.copyWith(clearLocation: true)),
          if (filters.hasFilters)
            TextButton.icon(
              onPressed: () => onChanged(const EquipmentSearchFilters()),
              icon: const Icon(Icons.clear_all, size: 18),
              label: const Text('Clear All'),
            ),
        ],
      ),
    );
  }
}
