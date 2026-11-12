import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../providers/equipment_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import 'equipment_detail_pane.dart';
import 'equipment_result_card.dart';

/// Results area under the search bar: empty states, the list, and at expanded
/// widths the list beside a detail pane for the selected asset.
class EquipmentResults extends StatelessWidget {
  const EquipmentResults({
    super.key,
    required this.equipment,
    required this.registryIsEmpty,
    required this.hasFilters,
    required this.twoPane,
    required this.onClearFilters,
    required this.onEditAssignment,
    required this.onOpened,
    this.selectedId,
    this.onSelect,
  });

  final List<Equipment> equipment;
  final bool registryIsEmpty;
  final bool hasFilters;

  /// Expanded width: show the detail pane and select instead of navigating.
  final bool twoPane;
  final VoidCallback onClearFilters;
  final ValueChanged<Equipment> onEditAssignment;

  /// Called when a result opens another screen.
  final VoidCallback onOpened;
  final String? selectedId;
  final ValueChanged<Equipment>? onSelect;

  @override
  Widget build(BuildContext context) {
    // Nothing has ever been inspected: explain where equipment comes from
    // rather than showing a bare "no results".
    if (registryIsEmpty) {
      return const EmptyState(
        icon: Icons.precision_manufacturing_outlined,
        title: 'No equipment yet',
        message: 'Assets appear here once they are registered or inspected. '
            'Generator inspections remain supported as the first workflow.',
      );
    }

    if (equipment.isEmpty) {
      return EquipmentNoResults(
        action: hasFilters
            ? TextButton.icon(
                onPressed: onClearFilters,
                icon: const Icon(Icons.clear_all),
                label: const Text('Clear Filters'),
              )
            : null,
      );
    }

    final list = _ResultsList(
      equipment: equipment,
      selectedId: twoPane ? selectedId : null,
      onSelect: twoPane ? onSelect : null,
      onEditAssignment: onEditAssignment,
      onOpened: onOpened,
    );

    if (!twoPane) return list;

    Equipment? selected;
    for (final e in equipment) {
      if (e.id == selectedId) selected = e;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 5, child: list),
        VerticalDivider(
          width: 1,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        Expanded(
          flex: 6,
          child: selected == null
              ? const EquipmentDetailPlaceholder()
              : EquipmentDetailPane(
                  key: ValueKey(selected.id),
                  equipment: selected,
                  onEditAssignment: selected.hasInspectionLink
                      ? null
                      : () => onEditAssignment(selected!),
                  onOpened: onOpened,
                ),
        ),
      ],
    );
  }
}

class _ResultsList extends StatelessWidget {
  const _ResultsList({
    required this.equipment,
    required this.onEditAssignment,
    required this.onOpened,
    this.selectedId,
    this.onSelect,
  });

  final List<Equipment> equipment;
  final String? selectedId;
  final ValueChanged<Equipment>? onSelect;
  final ValueChanged<Equipment> onEditAssignment;
  final VoidCallback onOpened;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            '${equipment.length} ${equipment.length == 1 ? 'result' : 'results'} found',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            itemCount: equipment.length,
            itemBuilder: (context, index) {
              final item = equipment[index];
              return EquipmentResultCard(
                equipment: item,
                selected: item.id == selectedId,
                onSelect: onSelect == null ? null : () => onSelect!(item),
                onOpened: onOpened,
                onEditAssignment: item.hasInspectionLink
                    ? null
                    : () => onEditAssignment(item),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// "No Results Found" with an optional action (clear filters).
class EquipmentNoResults extends StatelessWidget {
  const EquipmentNoResults({super.key, this.action});

  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.huge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              'No Results Found',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Try adjusting your search or filters',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
