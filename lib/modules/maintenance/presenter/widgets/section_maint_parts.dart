import 'package:flutter/material.dart';

import '../../infra/models/maintenance_record.dart';

/// Parts & materials section for the maintenance form.
///
/// Binds to the “Parts & Materials Used” fields on [MaintenanceRecord].
class SectionMaintParts extends StatelessWidget {
  final MaintenanceRecord model;
  final ValueChanged<MaintenanceRecord> onChanged;
  final bool readOnly;

  const SectionMaintParts({
    super.key,
    required this.model,
    required this.onChanged,
    this.readOnly = false,
  });

  bool get _isComplete {
    return model.partsOilTypeQty.trim().isNotEmpty ||
        model.partsCoolantTypeQty.trim().isNotEmpty ||
        model.partsFilterTypes.trim().isNotEmpty ||
        model.partsBatteryTypeDate.trim().isNotEmpty ||
        model.partsBeltsHosesReplaced.trim().isNotEmpty ||
        model.partsBlockHeaterWattage.trim().isNotEmpty ||
        model.partsCdvrSerial.trim().isNotEmpty;
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
            Text(
              'Parts & Materials Used',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Document the consumables and major parts used during this service. '
                  'These fields feed directly into reporting and future planning.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            _TextAreaRow(
              label: 'Oil type & quantity',
              hintText: 'e.g. 10W-30, 5 gallons',
              initialValue: model.partsOilTypeQty,
              readOnly: readOnly,
              onChanged: (value) {
                model.partsOilTypeQty = value.trim();
                onChanged(model);
              },
            ),
            const SizedBox(height: 12),
            _TextAreaRow(
              label: 'Coolant type & quantity',
              hintText: 'e.g. 50/50 premix, 4 gallons',
              initialValue: model.partsCoolantTypeQty,
              readOnly: readOnly,
              onChanged: (value) {
                model.partsCoolantTypeQty = value.trim();
                onChanged(model);
              },
            ),
            const SizedBox(height: 12),
            _TextAreaRow(
              label: 'Filter types (oil, fuel, air, Racor, etc.)',
              hintText: 'List filters and part numbers used in this service',
              initialValue: model.partsFilterTypes,
              readOnly: readOnly,
              onChanged: (value) {
                model.partsFilterTypes = value.trim();
                onChanged(model);
              },
            ),
            const SizedBox(height: 12),
            _TextFieldRow(
              label: 'Battery type / install date',
              hintText: 'e.g. Group 31 – installed 2025-03-10',
              initialValue: model.partsBatteryTypeDate,
              readOnly: readOnly,
              onChanged: (value) {
                model.partsBatteryTypeDate = value.trim();
                onChanged(model);
              },
            ),
            const SizedBox(height: 12),
            _TextAreaRow(
              label: 'Belts & hoses replaced',
              hintText: 'Describe belts/hoses replaced and part numbers',
              initialValue: model.partsBeltsHosesReplaced,
              readOnly: readOnly,
              onChanged: (value) {
                model.partsBeltsHosesReplaced = value.trim();
                onChanged(model);
              },
            ),
            const SizedBox(height: 12),
            _TextFieldRow(
              label: 'Block heater wattage / model',
              hintText: 'e.g. 1500W block heater, model ABC-123',
              initialValue: model.partsBlockHeaterWattage,
              readOnly: readOnly,
              onChanged: (value) {
                model.partsBlockHeaterWattage = value.trim();
                onChanged(model);
              },
            ),
            const SizedBox(height: 12),
            _TextFieldRow(
              label: 'CDVR serial / model',
              hintText: 'e.g. CDVR-XYZ, SN 123456789',
              initialValue: model.partsCdvrSerial,
              readOnly: readOnly,
              onChanged: (value) {
                model.partsCdvrSerial = value.trim();
                onChanged(model);
              },
            ),
            _CompletionChip(isComplete: _isComplete),
          ],
        ),
      ),
    );
  }
}

class _TextFieldRow extends StatelessWidget {
  final String label;
  final String initialValue;
  final String? hintText;
  final bool readOnly;
  final TextInputType? keyboardType;
  final ValueChanged<String> onChanged;

  const _TextFieldRow({
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.hintText,
    this.readOnly = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: initialValue,
          readOnly: readOnly,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hintText,
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _TextAreaRow extends StatelessWidget {
  final String label;
  final String initialValue;
  final String? hintText;
  final bool readOnly;
  final ValueChanged<String> onChanged;

  const _TextAreaRow({
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.hintText,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: initialValue,
          readOnly: readOnly,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: hintText,
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _CompletionChip extends StatelessWidget {
  final bool isComplete;

  const _CompletionChip({required this.isComplete});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isComplete
            ? cs.primaryContainer
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isComplete ? Icons.check_circle_outline : Icons.circle_outlined,
            size: 16,
            color: isComplete ? cs.primary : cs.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            isComplete ? 'Complete' : 'In progress',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isComplete ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

