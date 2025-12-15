import 'package:flutter/material.dart';
import '../../presenter/widgets/utils/form_fields.dart';
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

  void _touch() => onChanged(model);

  bool _isComplete(MaintenanceRecord m) {
    // Completion heuristic: at least 3 relevant fields filled.
    final filled = <bool>[
      m.partsOilTypeQty.trim().isNotEmpty,
      m.partsCoolantTypeQty.trim().isNotEmpty,
      m.partsFilterTypes.trim().isNotEmpty,
      m.partsBatteryTypeDate.trim().isNotEmpty,
      m.partsBeltsHosesReplaced.trim().isNotEmpty,
      m.partsBlockHeaterWattage.trim().isNotEmpty,
      m.partsCdvrSerial.trim().isNotEmpty,
    ].where((x) => x).length;

    return filled >= 3;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final complete = _isComplete(model);

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
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parts & Materials Used',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Document consumables and major parts used during this service.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _StatusChip(
                      label: complete ? 'Complete' : 'In Progress',
                      icon: complete
                          ? Icons.check_circle_outline
                          : Icons.pending_outlined,
                      background: complete
                          ? colorScheme.tertiaryContainer
                          : colorScheme.surfaceContainerHighest,
                      foreground: complete
                          ? colorScheme.onTertiaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                    if (readOnly) ...[
                      const SizedBox(height: 8),
                      _StatusChip(
                        label: 'Read only',
                        icon: Icons.lock_outline,
                        background: colorScheme.surfaceContainerHighest,
                        foreground: colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            FormTextAreaRow(
              label: 'Oil type & quantity',
              hintText: 'e.g. 10W-30, 5 gallons',
              initialValue: model.partsOilTypeQty,
              readOnly: readOnly,
              onChanged: (value) {
                model.partsOilTypeQty = value.trim();
                _touch();
              },
            ),
            const SizedBox(height: 12),
            FormTextAreaRow(
              label: 'Coolant type & quantity',
              hintText: 'e.g. 50/50 premix, 4 gallons',
              initialValue: model.partsCoolantTypeQty,
              readOnly: readOnly,
              onChanged: (value) {
                model.partsCoolantTypeQty = value.trim();
                _touch();
              },
            ),
            const SizedBox(height: 12),
            FormTextAreaRow(
              label: 'Filter types (oil, fuel, air, Racor, etc.)',
              hintText: 'List filters and part numbers used in this service',
              initialValue: model.partsFilterTypes,
              readOnly: readOnly,
              onChanged: (value) {
                model.partsFilterTypes = value.trim();
                _touch();
              },
            ),
            const SizedBox(height: 12),
            FormTextAreaRow(
              label: 'Battery type / install date',
              hintText: 'e.g. Group 31 – installed 2025-03-10',
              initialValue: model.partsBatteryTypeDate,
              readOnly: readOnly,
              onChanged: (value) {
                model.partsBatteryTypeDate = value.trim();
                _touch();
              },
            ),
            const SizedBox(height: 12),
            FormTextAreaRow(
              label: 'Belts & hoses replaced',
              hintText: 'Describe belts/hoses replaced and part numbers',
              initialValue: model.partsBeltsHosesReplaced,
              readOnly: readOnly,
              onChanged: (value) {
                model.partsBeltsHosesReplaced = value.trim();
                _touch();
              },
            ),
            const SizedBox(height: 12),
            FormTextAreaRow(
              label: 'Block heater wattage / model',
              hintText: 'e.g. 1500W block heater, model ABC-123',
              initialValue: model.partsBlockHeaterWattage,
              readOnly: readOnly,
              onChanged: (value) {
                model.partsBlockHeaterWattage = value.trim();
                _touch();
              },
            ),
            const SizedBox(height: 12),
            FormTextAreaRow(
              label: 'CDVR serial / model',
              hintText: 'e.g. CDVR-XYZ, SN 123456789',
              initialValue: model.partsCdvrSerial,
              readOnly: readOnly,
              onChanged: (value) {
                model.partsCdvrSerial = value.trim();
                _touch();
              },
            ),
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

class _StatusChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;

  const _StatusChip({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: background.withOpacity(0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foreground),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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

