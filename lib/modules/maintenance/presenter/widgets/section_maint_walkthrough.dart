import 'package:flutter/material.dart';
import '../../infra/models/maintenance_record.dart';
import '../../../../shared/widgets/widgets.dart';

/// Modern walkthrough section with enhanced UI
class SectionMaintWalkthrough extends StatelessWidget {
  final MaintenanceRecord model;
  final ValueChanged<MaintenanceRecord> onChanged;
  final bool readOnly;

  const SectionMaintWalkthrough({
    super.key,
    required this.model,
    required this.onChanged,
    this.readOnly = false,
  });

  void _updateModel(void Function() mutation) {
    mutation();
    onChanged(model);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.explore_outlined,
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Initial Walkthrough',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Document generator location, enclosure condition, and area safety checks.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Generator Location
            Row(
              children: [
                Icon(Icons.map_outlined, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Generator Location',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _LocationChip(
                  label: 'Indoors',
                  icon: Icons.home_outlined,
                  selected: model.generatorLocation == 'Indoors',
                  onSelected: readOnly
                      ? null
                      : () => _updateModel(() => model.generatorLocation = 'Indoors'),
                ),
                _LocationChip(
                  label: 'Outdoors',
                  icon: Icons.park_outlined,
                  selected: model.generatorLocation == 'Outdoors',
                  onSelected: readOnly
                      ? null
                      : () => _updateModel(() => model.generatorLocation = 'Outdoors'),
                ),
                _LocationChip(
                  label: 'Roof',
                  icon: Icons.roofing_outlined,
                  selected: model.generatorLocation == 'Roof',
                  onSelected: readOnly
                      ? null
                      : () => _updateModel(() => model.generatorLocation = 'Roof'),
                ),
                _LocationChip(
                  label: 'Basement',
                  icon: Icons.stairs_outlined,
                  selected: model.generatorLocation == 'Basement',
                  onSelected: readOnly
                      ? null
                      : () => _updateModel(() => model.generatorLocation = 'Basement'),
                ),
                _LocationChip(
                  label: 'Other',
                  icon: Icons.more_horiz_outlined,
                  selected: model.generatorLocation == 'Other',
                  onSelected: readOnly
                      ? null
                      : () => _updateModel(() => model.generatorLocation = 'Other'),
                ),
              ],
            ),

            if (model.generatorLocation == 'Other') ...[
              const SizedBox(height: 12),
              LabeledField(
                label: 'Specify Location',
                value: model.generatorLocationOther,
                hint: 'Describe the location',
                prefixIcon: Icons.edit_location_outlined,
                readOnly: readOnly,
                onChanged: (value) => _updateModel(() =>
                model.generatorLocationOther = value.trim()),
              ),
            ],

            const SizedBox(height: 20),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 20),

            // Enclosure Condition
            Row(
              children: [
                Icon(Icons.domain_outlined, size: 18, color: colorScheme.tertiary),
                const SizedBox(width: 8),
                Text(
                  'Enclosure Condition',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.tertiary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  _CheckboxTile(
                    icon: Icons.warning_amber_outlined,
                    label: 'Enclosure damaged',
                    value: model.enclosureDamaged,
                    readOnly: readOnly,
                    warningColor: colorScheme.error,
                    onChanged: (val) {
                      _updateModel(() {
                        model.enclosureDamaged = val ?? false;
                        if (val == true) {
                          model.enclosureIntact = false;
                          model.noEnclosure = false;
                        }
                      });
                    },
                  ),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  _CheckboxTile(
                    icon: Icons.check_circle_outline,
                    label: 'Enclosure intact',
                    value: model.enclosureIntact,
                    readOnly: readOnly,
                    onChanged: (val) {
                      _updateModel(() {
                        model.enclosureIntact = val ?? false;
                        if (val == true) {
                          model.enclosureDamaged = false;
                          model.noEnclosure = false;
                        }
                      });
                    },
                  ),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  _CheckboxTile(
                    icon: Icons.info_outline,
                    label: 'No enclosure',
                    value: model.noEnclosure,
                    readOnly: readOnly,
                    onChanged: (val) {
                      _updateModel(() {
                        model.noEnclosure = val ?? false;
                        if (val == true) {
                          model.enclosureDamaged = false;
                          model.enclosureIntact = false;
                        }
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 20),

            // Area Safety Checks
            Row(
              children: [
                Icon(Icons.health_and_safety_outlined, size: 18,
                    color: colorScheme.secondary),
                const SizedBox(width: 8),
                Text(
                  'Area Safety Checks',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  _CheckboxTile(
                    icon: Icons.broken_image_outlined,
                    label: 'Visible damage or leaks',
                    value: model.visibleDamageOrLeaks,
                    readOnly: readOnly,
                    warningColor: model.visibleDamageOrLeaks
                        ? colorScheme.error
                        : null,
                    onChanged: (val) => _updateModel(() =>
                    model.visibleDamageOrLeaks = val ?? false),
                  ),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  _CheckboxTile(
                    icon: Icons.cleaning_services_outlined,
                    label: 'Area clear of hazards',
                    value: model.areaClearOfHazards,
                    readOnly: readOnly,
                    onChanged: (val) => _updateModel(() =>
                    model.areaClearOfHazards = val ?? false),
                  ),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  _CheckboxTile(
                    icon: Icons.label_outlined,
                    label: 'Warning labels visible',
                    value: model.warningLabelsVisible,
                    readOnly: readOnly,
                    onChanged: (val) => _updateModel(() =>
                    model.warningLabelsVisible = val ?? false),
                  ),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  _CheckboxTile(
                    icon: Icons.fire_extinguisher_outlined,
                    label: 'Fire extinguisher present',
                    value: model.fireExtinguisherPresent,
                    readOnly: readOnly,
                    onChanged: (val) => _updateModel(() =>
                    model.fireExtinguisherPresent = val ?? false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modern location choice chip with icon
class _LocationChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onSelected;

  const _LocationChip({
    required this.label,
    required this.icon,
    required this.selected,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selected: selected,
      onSelected: onSelected == null ? null : (_) => onSelected?.call(),
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
      side: BorderSide(
        color: selected ? colorScheme.primary : colorScheme.outlineVariant,
      ),
    );
  }
}

/// Modern checkbox tile with icon
class _CheckboxTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final bool readOnly;
  final Color? warningColor;
  final ValueChanged<bool?> onChanged;

  const _CheckboxTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.readOnly = false,
    this.warningColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final effectiveColor = warningColor ??
        (value ? colorScheme.primary : colorScheme.onSurfaceVariant);

    return Material(
      color: Colors.transparent,
      child: CheckboxListTile(
        value: value,
        onChanged: readOnly ? null : onChanged,
        title: Row(
          children: [
            Icon(icon, size: 18, color: effectiveColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: value ? colorScheme.onSurface : null,
                ),
              ),
            ),
          ],
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        dense: true,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }
}