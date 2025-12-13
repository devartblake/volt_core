import 'package:flutter/material.dart';

import '../../infra/models/maintenance_record.dart';

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
            Text(
              'Initial Walkthrough',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // Generator Location
            Text(
              'Generator Location',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ChoiceChip(
                  label: 'Indoors',
                  selected: model.generatorLocation == 'Indoors',
                  onSelected: readOnly
                      ? null
                      : () {
                    model.generatorLocation = 'Indoors';
                    onChanged(model);
                  },
                ),
                _ChoiceChip(
                  label: 'Outdoors',
                  selected: model.generatorLocation == 'Outdoors',
                  onSelected: readOnly
                      ? null
                      : () {
                    model.generatorLocation = 'Outdoors';
                    onChanged(model);
                  },
                ),
                _ChoiceChip(
                  label: 'Roof',
                  selected: model.generatorLocation == 'Roof',
                  onSelected: readOnly
                      ? null
                      : () {
                    model.generatorLocation = 'Roof';
                    onChanged(model);
                  },
                ),
                _ChoiceChip(
                  label: 'Basement',
                  selected: model.generatorLocation == 'Basement',
                  onSelected: readOnly
                      ? null
                      : () {
                    model.generatorLocation = 'Basement';
                    onChanged(model);
                  },
                ),
                _ChoiceChip(
                  label: 'Other',
                  selected: model.generatorLocation == 'Other',
                  onSelected: readOnly
                      ? null
                      : () {
                    model.generatorLocation = 'Other';
                    onChanged(model);
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (model.generatorLocation == 'Other') ...[
              TextFormField(
                initialValue: model.generatorLocationOther,
                readOnly: readOnly,
                decoration: const InputDecoration(
                  labelText: 'Location (Other)',
                  hintText: 'Describe location',
                ),
                onChanged: (value) {
                  model.generatorLocationOther = value.trim();
                  onChanged(model);
                },
              ),
            ],

            const SizedBox(height: 16),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 16),

            // Enclosure state
            Text(
              'Enclosure',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            _CheckboxRow(
              label: 'Enclosure damaged',
              value: model.enclosureDamaged,
              readOnly: readOnly,
              onChanged: (val) {
                model.enclosureDamaged = val ?? false;
                if (val == true) {
                  model.enclosureIntact = false;
                  model.noEnclosure = false;
                }
                onChanged(model);
              },
            ),
            _CheckboxRow(
              label: 'Enclosure intact',
              value: model.enclosureIntact,
              readOnly: readOnly,
              onChanged: (val) {
                model.enclosureIntact = val ?? false;
                if (val == true) {
                  model.enclosureDamaged = false;
                  model.noEnclosure = false;
                }
                onChanged(model);
              },
            ),
            _CheckboxRow(
              label: 'No enclosure',
              value: model.noEnclosure,
              readOnly: readOnly,
              onChanged: (val) {
                model.noEnclosure = val ?? false;
                if (val == true) {
                  model.enclosureDamaged = false;
                  model.enclosureIntact = false;
                }
                onChanged(model);
              },
            ),

            const SizedBox(height: 16),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 16),

            // Area safety checks
            Text(
              'Area Checks',
              style: theme.textTheme.labelMedium,
            ),
            const SizedBox(height: 8),
            _CheckboxRow(
              label: 'Visible damage or leaks',
              value: model.visibleDamageOrLeaks,
              readOnly: readOnly,
              onChanged: (val) {
                model.visibleDamageOrLeaks = val ?? false;
                onChanged(model);
              },
            ),
            _CheckboxRow(
              label: 'Area clear of hazards',
              value: model.areaClearOfHazards,
              readOnly: readOnly,
              onChanged: (val) {
                model.areaClearOfHazards = val ?? false;
                onChanged(model);
              },
            ),
            _CheckboxRow(
              label: 'Warning labels visible',
              value: model.warningLabelsVisible,
              readOnly: readOnly,
              onChanged: (val) {
                model.warningLabelsVisible = val ?? false;
                onChanged(model);
              },
            ),
            _CheckboxRow(
              label: 'Fire extinguisher present',
              value: model.fireExtinguisherPresent,
              readOnly: readOnly,
              onChanged: (val) {
                model.fireExtinguisherPresent = val ?? false;
                onChanged(model);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onSelected;

  const _ChoiceChip({
    required this.label,
    required this.selected,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected == null ? null : (_) => onSelected?.call(),
      selectedColor: colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: selected
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _CheckboxRow extends StatelessWidget {
  final String label;
  final bool value;
  final bool readOnly;
  final ValueChanged<bool?> onChanged;

  const _CheckboxRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CheckboxListTile(
      value: value,
      onChanged: readOnly ? null : onChanged,
      title: Text(
        label,
        style: theme.textTheme.bodyMedium,
      ),
      contentPadding: EdgeInsets.zero,
      dense: true,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}
