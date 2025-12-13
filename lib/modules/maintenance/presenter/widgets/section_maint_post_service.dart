import 'package:flutter/material.dart';

import '../../infra/models/maintenance_record.dart';

/// Post-service checklist section for the maintenance form.
///
/// Binds directly to [MaintenanceRecord] booleans and notifies via [onChanged]
/// whenever any field changes.
class SectionMaintPostService extends StatelessWidget {
  final MaintenanceRecord model;
  final ValueChanged<MaintenanceRecord> onChanged;
  final bool readOnly;

  const SectionMaintPostService({
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
              'Post-Service Checklist',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Confirm the generator and associated systems were tested and left in a safe, ready state.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            _ChecklistTile(
              label: 'Generator runs under load',
              value: model.postVerifyRunsUnderLoad,
              readOnly: readOnly,
              onChanged: (val) {
                model.postVerifyRunsUnderLoad = val;
                onChanged(model);
              },
            ),
            _ChecklistTile(
              label: 'Voltage & frequency checked',
              value: model.postCheckVoltFreq,
              readOnly: readOnly,
              onChanged: (val) {
                model.postCheckVoltFreq = val;
                onChanged(model);
              },
            ),
            _ChecklistTile(
              label: 'Exhaust system inspected',
              value: model.postInspectExhaust,
              readOnly: readOnly,
              onChanged: (val) {
                model.postInspectExhaust = val;
                onChanged(model);
              },
            ),
            _ChecklistTile(
              label: 'Grounding & bonding verified',
              value: model.postVerifyGrounding,
              readOnly: readOnly,
              onChanged: (val) {
                model.postVerifyGrounding = val;
                onChanged(model);
              },
            ),
            _ChecklistTile(
              label: 'Control panel checked',
              value: model.postCheckControlPanel,
              readOnly: readOnly,
              onChanged: (val) {
                model.postCheckControlPanel = val;
                onChanged(model);
              },
            ),
            _ChecklistTile(
              label: 'Safety devices functional',
              value: model.postEnsureSafetyDevices,
              readOnly: readOnly,
              onChanged: (val) {
                model.postEnsureSafetyDevices = val;
                onChanged(model);
              },
            ),
            _ChecklistTile(
              label: 'Deficiencies documented',
              value: model.postDocumentDeficiencies,
              readOnly: readOnly,
              onChanged: (val) {
                model.postDocumentDeficiencies = val;
                onChanged(model);
              },
            ),
            _ChecklistTile(
              label: 'Load-bank test performed (if applicable)',
              value: model.postLoadbankTest,
              readOnly: readOnly,
              onChanged: (val) {
                model.postLoadbankTest = val;
                onChanged(model);
              },
            ),
            _ChecklistTile(
              label: 'ATS functionality verified',
              value: model.postAtsFunctionality,
              readOnly: readOnly,
              onChanged: (val) {
                model.postAtsFunctionality = val;
                onChanged(model);
              },
            ),

            const SizedBox(height: 16),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 16),

            Text(
              'Fuel Storage',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Switch(
                  value: model.fuelStoredLong,
                  onChanged: readOnly
                      ? null
                      : (val) {
                    model.fuelStoredLong = val;
                    onChanged(model);
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Fuel has been stored for an extended period (check if fuel may be stale and needs treatment/replacement).',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  final String label;
  final bool value;
  final bool readOnly;
  final ValueChanged<bool> onChanged;

  const _ChecklistTile({
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
      onChanged: readOnly ? null : (val) => onChanged(val ?? false),
      title: Text(
        label,
        style: theme.textTheme.bodyMedium,
      ),
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}
