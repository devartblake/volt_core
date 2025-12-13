import 'package:flutter/material.dart';

import '../../infra/models/maintenance_record.dart';

class SectionMaintActions extends StatelessWidget {
  final MaintenanceRecord model;
  final ValueChanged<MaintenanceRecord> onChanged;
  final bool readOnly;

  const SectionMaintActions({
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
              'Actions Performed',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            _ActionRow(
              label: 'Oil filter changed',
              value: model.oilFilterChanged,
              notes: model.oilFilterNotes,
              readOnly: readOnly,
              onChanged: (val, notes) {
                model.oilFilterChanged = val;
                model.oilFilterNotes = notes;
                onChanged(model);
              },
            ),
            _ActionRow(
              label: 'Fuel filter replaced',
              value: model.fuelFilterReplaced,
              notes: model.fuelFilterNotes,
              readOnly: readOnly,
              onChanged: (val, notes) {
                model.fuelFilterReplaced = val;
                model.fuelFilterNotes = notes;
                onChanged(model);
              },
            ),
            _ActionRow(
              label: 'Coolant flushed',
              value: model.coolantFlushed,
              notes: model.coolantNotes,
              readOnly: readOnly,
              onChanged: (val, notes) {
                model.coolantFlushed = val;
                model.coolantNotes = notes;
                onChanged(model);
              },
            ),
            _ActionRow(
              label: 'Battery replaced',
              value: model.batteryReplaced,
              notes: model.batteryNotes,
              readOnly: readOnly,
              onChanged: (val, notes) {
                model.batteryReplaced = val;
                model.batteryNotes = notes;
                onChanged(model);
              },
            ),
            _ActionRow(
              label: 'Air filter replaced',
              value: model.airFilterReplaced,
              notes: model.airFilterNotes,
              readOnly: readOnly,
              onChanged: (val, notes) {
                model.airFilterReplaced = val;
                model.airFilterNotes = notes;
                onChanged(model);
              },
            ),
            _ActionRow(
              label: 'Belts / hoses replaced',
              value: model.beltsHosesReplaced,
              notes: model.beltsHosesNotes,
              readOnly: readOnly,
              onChanged: (val, notes) {
                model.beltsHosesReplaced = val;
                model.beltsHosesNotes = notes;
                onChanged(model);
              },
            ),
            _ActionRow(
              label: 'Block heater tested',
              value: model.blockHeaterTested,
              notes: model.blockHeaterNotes,
              readOnly: readOnly,
              onChanged: (val, notes) {
                model.blockHeaterTested = val;
                model.blockHeaterNotes = notes;
                onChanged(model);
              },
            ),
            _ActionRow(
              label: 'Racor serviced',
              value: model.racorServiced,
              notes: model.racorNotes,
              readOnly: readOnly,
              onChanged: (val, notes) {
                model.racorServiced = val;
                model.racorNotes = notes;
                onChanged(model);
              },
            ),
            _ActionRow(
              label: 'ATS / controller inspected',
              value: model.atsControllerInspected,
              notes: model.atsControllerNotes,
              readOnly: readOnly,
              onChanged: (val, notes) {
                model.atsControllerInspected = val;
                model.atsControllerNotes = notes;
                onChanged(model);
              },
            ),
            _ActionRow(
              label: 'CDVR programmed',
              value: model.cdvrProgrammed,
              notes: model.cdvrNotes,
              readOnly: readOnly,
              onChanged: (val, notes) {
                model.cdvrProgrammed = val;
                model.cdvrNotes = notes;
                onChanged(model);
              },
            ),
            _ActionRow(
              label: 'Under-voltage repaired',
              value: model.undervoltageRepaired,
              notes: model.undervoltageNotes,
              readOnly: readOnly,
              onChanged: (val, notes) {
                model.undervoltageRepaired = val;
                model.undervoltageNotes = notes;
                onChanged(model);
              },
            ),
            _ActionRow(
              label: 'Hazmat removed',
              value: model.hazmatRemoved,
              notes: model.hazmatNotes,
              readOnly: readOnly,
              onChanged: (val, notes) {
                model.hazmatRemoved = val;
                model.hazmatNotes = notes;
                onChanged(model);
              },
            ),

            const SizedBox(height: 16),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 16),

            Text(
              'Service Observations',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: model.serviceObservations,
              readOnly: readOnly,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText:
                'Summarize key observations, issues found, and recommendations...',
              ),
              onChanged: (value) {
                model.serviceObservations = value.trim();
                onChanged(model);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String label;
  final bool value;
  final String notes;
  final bool readOnly;
  final void Function(bool value, String notes) onChanged;

  const _ActionRow({
    super.key,
    required this.label,
    required this.value,
    required this.notes,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    bool localValue = value;
    String localNotes = notes;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CheckboxListTile(
            value: value,
            onChanged: readOnly
                ? null
                : (val) {
              localValue = val ?? false;
              onChanged(localValue, localNotes);
            },
            title: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
          ),
          if (!readOnly) ...[
            TextFormField(
              initialValue: notes,
              maxLines: 2,
              decoration: const InputDecoration(
                hintText: 'Notes (optional)',
                isDense: true,
              ),
              onChanged: (value) {
                localNotes = value.trim();
                onChanged(localValue, localNotes);
              },
            ),
          ] else if (notes.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Text(
                notes,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
