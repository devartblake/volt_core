import 'package:flutter/material.dart';
import '../../data/models/maintenance_record.dart';

class SectionMaintWalkthrough extends StatelessWidget {
  final MaintenanceRecord model;
  final ValueChanged<MaintenanceRecord> onChanged;

  const SectionMaintWalkthrough({
    super.key,
    required this.model,
    required this.onChanged,
  });

  void _update(void Function() fn) {
    fn();
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
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.explore_outlined,
                    color: colorScheme.onSecondaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Initial Walkthrough & Location',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Generator location
            Text(
              'Generator Location',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Location Type',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.map_outlined),
              ),
              value: model.generatorLocation.isEmpty ? null : model.generatorLocation,
              items: const [
                DropdownMenuItem(value: 'Indoors', child: Text('Indoors')),
                DropdownMenuItem(value: 'Outdoors', child: Text('Outdoors')),
                DropdownMenuItem(value: 'Roof', child: Text('Roof')),
                DropdownMenuItem(value: 'Basement', child: Text('Basement')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (v) =>
                  _update(() => model.generatorLocation = v ?? ''),
            ),
            if (model.generatorLocation == 'Other') ...[
              const SizedBox(height: 16),
              TextFormField(
                decoration: InputDecoration(
                  labelText: 'Specify Location',
                  filled: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                initialValue: model.generatorLocationOther,
                onChanged: (v) =>
                    _update(() => model.generatorLocationOther = v),
              ),
            ],

            const SizedBox(height: 24),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 24),

            // Enclosure condition
            Text(
              'Enclosure Condition',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilterChip(
                  label: const Text('Enclosure Intact'),
                  selected: model.enclosureIntact,
                  onSelected: (v) =>
                      _update(() => model.enclosureIntact = v),
                  avatar: model.enclosureIntact
                      ? const Icon(Icons.check_circle, size: 18)
                      : null,
                  selectedColor: colorScheme.primaryContainer,
                  checkmarkColor: colorScheme.onPrimaryContainer,
                ),
                FilterChip(
                  label: const Text('Enclosure Damaged'),
                  selected: model.enclosureDamaged,
                  onSelected: (v) =>
                      _update(() => model.enclosureDamaged = v),
                  avatar: model.enclosureDamaged
                      ? const Icon(Icons.warning_amber, size: 18)
                      : null,
                  selectedColor: colorScheme.errorContainer,
                  checkmarkColor: colorScheme.onErrorContainer,
                ),
                FilterChip(
                  label: const Text('No Enclosure'),
                  selected: model.noEnclosure,
                  onSelected: (v) => _update(() => model.noEnclosure = v),
                  avatar: model.noEnclosure
                      ? const Icon(Icons.info_outline, size: 18)
                      : null,
                  selectedColor: colorScheme.tertiaryContainer,
                  checkmarkColor: colorScheme.onTertiaryContainer,
                ),
              ],
            ),

            const SizedBox(height: 24),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 24),

            // Safety & Hazards
            Row(
              children: [
                Icon(
                  Icons.health_and_safety_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Safety & Hazards',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    title: const Text('Visible damage or leaks'),
                    subtitle: Text(
                      'Check for any physical damage',
                      style: theme.textTheme.bodySmall,
                    ),
                    value: model.visibleDamageOrLeaks,
                    onChanged: (v) =>
                        _update(() => model.visibleDamageOrLeaks = v ?? false),
                  ),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    title: const Text('Area clear of debris / tripping hazards'),
                    subtitle: Text(
                      'Ensure safe working environment',
                      style: theme.textTheme.bodySmall,
                    ),
                    value: model.areaClearOfHazards,
                    onChanged: (v) =>
                        _update(() => model.areaClearOfHazards = v ?? false),
                  ),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    title: const Text('Warning / safety labels visible'),
                    subtitle: Text(
                      'Verify all safety signage',
                      style: theme.textTheme.bodySmall,
                    ),
                    value: model.warningLabelsVisible,
                    onChanged: (v) =>
                        _update(() => model.warningLabelsVisible = v ?? false),
                  ),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  CheckboxListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    title: const Text('Fire extinguisher present & accessible'),
                    subtitle: Text(
                      'Confirm emergency equipment',
                      style: theme.textTheme.bodySmall,
                    ),
                    value: model.fireExtinguisherPresent,
                    onChanged: (v) =>
                        _update(() => model.fireExtinguisherPresent = v ?? false),
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