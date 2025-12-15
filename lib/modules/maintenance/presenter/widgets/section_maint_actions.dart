import 'package:flutter/material.dart';
import '../../presenter/widgets/utils/form_fields.dart';
import '../../infra/models/maintenance_record.dart';

/// Actions performed section for the maintenance form.
///
/// Binds to “Actions Performed” fields on [MaintenanceRecord].
/// Also emits a completion flag via [onCompletionChanged] when provided.
///
/// Completion rule (simple + consistent):
/// - Complete when at least 1 action is checked.
class SectionMaintActions extends StatelessWidget {
  final MaintenanceRecord model;
  final ValueChanged<MaintenanceRecord> onChanged;
  final ValueChanged<bool>? onCompletionChanged;
  final bool readOnly;

  const SectionMaintActions({
    super.key,
    required this.model,
    required this.onChanged,
    this.onCompletionChanged,
    this.readOnly = false,
  });

  bool _isComplete(MaintenanceRecord m) {
    return m.oilFilterChanged ||
        m.fuelFilterReplaced ||
        m.coolantFlushed ||
        m.batteryReplaced ||
        m.airFilterReplaced ||
        m.beltsHosesReplaced ||
        m.blockHeaterTested ||
        m.racorServiced ||
        m.atsControllerInspected ||
        m.cdvrProgrammed ||
        m.undervoltageRepaired ||
        m.hazmatRemoved;
  }

  int _checkedCount(MaintenanceRecord m) {
    int c = 0;
    if (m.oilFilterChanged) c++;
    if (m.fuelFilterReplaced) c++;
    if (m.coolantFlushed) c++;
    if (m.batteryReplaced) c++;
    if (m.airFilterReplaced) c++;
    if (m.beltsHosesReplaced) c++;
    if (m.blockHeaterTested) c++;
    if (m.racorServiced) c++;
    if (m.atsControllerInspected) c++;
    if (m.cdvrProgrammed) c++;
    if (m.undervoltageRepaired) c++;
    if (m.hazmatRemoved) c++;
    return c;
  }

  void _emit() {
    onChanged(model);
    onCompletionChanged?.call(_isComplete(model));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final complete = _isComplete(model);
    final checked = _checkedCount(model);

    // Emit initial completion (helps parent controllers keep flags in sync on first paint)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onCompletionChanged?.call(complete);
    });

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
            _SectionHeader(
              title: 'Actions Performed',
              subtitle:
              'Check what was performed during service. Add notes where applicable.',
              complete: complete,
              completeLabel: complete ? 'Complete' : 'Incomplete',
              trailingText: checked > 0 ? '$checked selected' : null,
            ),
            const SizedBox(height: 16),

            _ActionTile(
              title: 'Oil filter changed',
              value: model.oilFilterChanged,
              notes: model.oilFilterNotes,
              readOnly: readOnly,
              onToggle: (v) {
                model.oilFilterChanged = v;
                if (!v) model.oilFilterNotes = '';
                _emit();
              },
              onNotes: (t) {
                model.oilFilterNotes = t;
                _emit();
              },
            ),
            _ActionTile(
              title: 'Fuel filter replaced',
              value: model.fuelFilterReplaced,
              notes: model.fuelFilterNotes,
              readOnly: readOnly,
              onToggle: (v) {
                model.fuelFilterReplaced = v;
                if (!v) model.fuelFilterNotes = '';
                _emit();
              },
              onNotes: (t) {
                model.fuelFilterNotes = t;
                _emit();
              },
            ),
            _ActionTile(
              title: 'Coolant flushed',
              value: model.coolantFlushed,
              notes: model.coolantNotes,
              readOnly: readOnly,
              onToggle: (v) {
                model.coolantFlushed = v;
                if (!v) model.coolantNotes = '';
                _emit();
              },
              onNotes: (t) {
                model.coolantNotes = t;
                _emit();
              },
            ),
            _ActionTile(
              title: 'Battery replaced',
              value: model.batteryReplaced,
              notes: model.batteryNotes,
              readOnly: readOnly,
              onToggle: (v) {
                model.batteryReplaced = v;
                if (!v) model.batteryNotes = '';
                _emit();
              },
              onNotes: (t) {
                model.batteryNotes = t;
                _emit();
              },
            ),
            _ActionTile(
              title: 'Air filter replaced',
              value: model.airFilterReplaced,
              notes: model.airFilterNotes,
              readOnly: readOnly,
              onToggle: (v) {
                model.airFilterReplaced = v;
                if (!v) model.airFilterNotes = '';
                _emit();
              },
              onNotes: (t) {
                model.airFilterNotes = t;
                _emit();
              },
            ),
            _ActionTile(
              title: 'Belts / hoses replaced',
              value: model.beltsHosesReplaced,
              notes: model.beltsHosesNotes,
              readOnly: readOnly,
              onToggle: (v) {
                model.beltsHosesReplaced = v;
                if (!v) model.beltsHosesNotes = '';
                _emit();
              },
              onNotes: (t) {
                model.beltsHosesNotes = t;
                _emit();
              },
            ),
            _ActionTile(
              title: 'Block heater tested',
              value: model.blockHeaterTested,
              notes: model.blockHeaterNotes,
              readOnly: readOnly,
              onToggle: (v) {
                model.blockHeaterTested = v;
                if (!v) model.blockHeaterNotes = '';
                _emit();
              },
              onNotes: (t) {
                model.blockHeaterNotes = t;
                _emit();
              },
            ),
            _ActionTile(
              title: 'Racor serviced',
              value: model.racorServiced,
              notes: model.racorNotes,
              readOnly: readOnly,
              onToggle: (v) {
                model.racorServiced = v;
                if (!v) model.racorNotes = '';
                _emit();
              },
              onNotes: (t) {
                model.racorNotes = t;
                _emit();
              },
            ),
            _ActionTile(
              title: 'ATS / controller inspected',
              value: model.atsControllerInspected,
              notes: model.atsControllerNotes,
              readOnly: readOnly,
              onToggle: (v) {
                model.atsControllerInspected = v;
                if (!v) model.atsControllerNotes = '';
                _emit();
              },
              onNotes: (t) {
                model.atsControllerNotes = t;
                _emit();
              },
            ),
            _ActionTile(
              title: 'CDVR programmed',
              value: model.cdvrProgrammed,
              notes: model.cdvrNotes,
              readOnly: readOnly,
              onToggle: (v) {
                model.cdvrProgrammed = v;
                if (!v) model.cdvrNotes = '';
                _emit();
              },
              onNotes: (t) {
                model.cdvrNotes = t;
                _emit();
              },
            ),
            _ActionTile(
              title: 'Under-voltage repaired',
              value: model.undervoltageRepaired,
              notes: model.undervoltageNotes,
              readOnly: readOnly,
              onToggle: (v) {
                model.undervoltageRepaired = v;
                if (!v) model.undervoltageNotes = '';
                _emit();
              },
              onNotes: (t) {
                model.undervoltageNotes = t;
                _emit();
              },
            ),
            _ActionTile(
              title: 'Hazmat removed',
              value: model.hazmatRemoved,
              notes: model.hazmatNotes,
              readOnly: readOnly,
              onToggle: (v) {
                model.hazmatRemoved = v;
                if (!v) model.hazmatNotes = '';
                _emit();
              },
              onNotes: (t) {
                model.hazmatNotes = t;
                _emit();
              },
            ),

            const SizedBox(height: 8),
            FormDivider(color: colorScheme.outlineVariant),
            const SizedBox(height: 12),

            Text(
              'Tip: If you checked an item, add notes for part numbers, quantities, or observations.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool complete;
  final String completeLabel;
  final String? trailingText;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.complete,
    required this.completeLabel,
    this.trailingText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
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
            _CompletionPill(
              complete: complete,
              label: completeLabel,
            ),
            if (trailingText != null) ...[
              const SizedBox(height: 6),
              Text(
                trailingText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _CompletionPill extends StatelessWidget {
  final bool complete;
  final String label;

  const _CompletionPill({
    required this.complete,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final bg = complete
        ? colorScheme.primaryContainer
        : colorScheme.surfaceContainerHighest;
    final fg = complete
        ? colorScheme.onPrimaryContainer
        : colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            complete ? Icons.check_circle_outline : Icons.info_outline,
            size: 16,
            color: fg,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String title;
  final bool value;
  final String notes;
  final bool readOnly;
  final ValueChanged<bool> onToggle;
  final ValueChanged<String> onNotes;

  const _ActionTile({
    required this.title,
    required this.value,
    required this.notes,
    required this.readOnly,
    required this.onToggle,
    required this.onNotes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: value
              ? colorScheme.primaryContainer.withOpacity(0.25)
              : colorScheme.surfaceContainerHighest.withOpacity(0.35),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Checkbox(
                  value: value,
                  onChanged: readOnly ? null : (v) => onToggle(v ?? false),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (value) ...[
              const SizedBox(height: 8),
              TextFormField(
                initialValue: notes,
                readOnly: readOnly,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Part numbers, quantities, observations',
                  isDense: true,
                ),
                onChanged: (t) => onNotes(t.trim()),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
