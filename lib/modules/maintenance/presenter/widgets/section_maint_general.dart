import 'package:flutter/material.dart';
import '../../presenter/widgets/utils/form_fields.dart';
import '../../infra/models/maintenance_record.dart';

/// General Maintenance section for the maintenance form.
///
/// - Battery
/// - Air Filter
/// - Coolant
/// - Hoses
/// - Cannister Filters & Parts
///
/// This widget mutates [model] and calls [onChanged] whenever fields change.
///
/// Modernized UX:
/// - Header row with icon + helper text
/// - Completion chip ("Complete" / "In Progress")
/// - Read-only indicator styling
class SectionMaintGeneral extends StatelessWidget {
  final MaintenanceRecord model;
  final ValueChanged<MaintenanceRecord> onChanged;
  final bool readOnly;

  const SectionMaintGeneral({
    super.key,
    required this.model,
    required this.onChanged,
    this.readOnly = false,
  });

  bool _isComplete(MaintenanceRecord m) {
    // A practical “good enough” completion heuristic:
    //
    // Battery: at least one meaningful field or checkbox touched.
    final batteryTouched = m.batteryNeedsReplace ||
        m.batteryRecentlyReplaced ||
        m.batteryMfgDate.trim().isNotEmpty ||
        m.batteryPartNo.trim().isNotEmpty ||
        m.batteryType.trim().isNotEmpty;

    // Air filter: checkboxes or part/last replaced.
    final airTouched = m.airFilterNeedsReplace ||
        m.airFilterRecentlyReplaced ||
        m.airFilterLastReplacedDate.trim().isNotEmpty ||
        m.airFilterPartNo.trim().isNotEmpty;

    // Coolant: level or color selected.
    final coolantTouched =
        m.coolantLevel.trim().isNotEmpty || m.coolantColor.trim().isNotEmpty;

    // Hoses: any compromised/recommend checked or notes provided.
    bool hoseTouched({
      required bool compromised,
      required bool recommend,
      required String notes,
    }) =>
        compromised || recommend || notes.trim().isNotEmpty;

    final hosesTouched = hoseTouched(
      compromised: m.coolantHosesCompromised,
      recommend: m.coolantHosesRecommendChange,
      notes: m.coolantHosesInfo,
    ) ||
        hoseTouched(
          compromised: m.fuelHosesCompromised,
          recommend: m.fuelHosesRecommendChange,
          notes: m.fuelHosesInfo,
        ) ||
        hoseTouched(
          compromised: m.airIntakeHosesCompromised,
          recommend: m.airIntakeHosesRecommendChange,
          notes: m.airIntakeHosesInfo,
        ) ||
        hoseTouched(
          compromised: m.oilHosesCompromised,
          recommend: m.oilHosesRecommendChange,
          notes: m.oilHosesInfo,
        ) ||
        hoseTouched(
          compromised: m.additionalHosesCompromised,
          recommend: m.additionalHosesRecommendChange,
          notes: m.additionalHosesInfo,
        );

    // Cannisters: any selection or part number entered.
    final cannTouched = m.canLube ||
        m.canFuel ||
        m.canWaterSep ||
        m.canOil ||
        m.canOther1 ||
        m.canOther2 ||
        m.canLubePartNo.trim().isNotEmpty ||
        m.canFuelPartNo.trim().isNotEmpty ||
        m.canWaterSepPartNo.trim().isNotEmpty ||
        m.canOilPartNo.trim().isNotEmpty ||
        m.canOther1PartNo.trim().isNotEmpty ||
        m.canOther2PartNo.trim().isNotEmpty ||
        m.canOther1Label.trim().isNotEmpty ||
        m.canOther2Label.trim().isNotEmpty;

    // Consider complete if *at least* a few subsections have meaningful input.
    final touchedCount = [
      batteryTouched,
      airTouched,
      coolantTouched,
      hosesTouched,
      cannTouched,
    ].where((x) => x).length;

    return touchedCount >= 3;
  }

  void _touch() => onChanged(model);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final complete = _isComplete(model);

    final content = Column(
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
                Icons.settings_outlined,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'General Maintenance',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Capture component condition, consumables, and cannister filter parts.',
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
                  icon: complete ? Icons.check_circle_outline : Icons.pending_outlined,
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
        Divider(color: colorScheme.outlineVariant),
        const SizedBox(height: 16),

        // Battery section
        const FormSubsectionTitle('Battery'),
        const SizedBox(height: 8),
        FormCheckboxRow(
          label: 'Battery needs replacement',
          value: model.batteryNeedsReplace,
          readOnly: readOnly,
          onChanged: (val) {
            model.batteryNeedsReplace = val ?? false;
            _touch();
          },
        ),
        FormCheckboxRow(
          label: 'Battery recently replaced',
          value: model.batteryRecentlyReplaced,
          readOnly: readOnly,
          onChanged: (val) {
            model.batteryRecentlyReplaced = val ?? false;
            _touch();
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FormTextFieldRow(
                label: 'Manufacture Date',
                hintText: 'e.g. 2025-01',
                initialValue: model.batteryMfgDate,
                readOnly: readOnly,
                onChanged: (value) {
                  model.batteryMfgDate = value.trim();
                  _touch();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FormTextFieldRow(
                label: 'Part Number',
                hintText: 'Battery part #',
                initialValue: model.batteryPartNo,
                readOnly: readOnly,
                onChanged: (value) {
                  model.batteryPartNo = value.trim();
                  _touch();
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        FormTextFieldRow(
          label: 'Battery Type',
          hintText: 'e.g. Lead Acid, NiCad',
          initialValue: model.batteryType,
          readOnly: readOnly,
          onChanged: (value) {
            model.batteryType = value.trim();
            _touch();
          },
        ),

        const SizedBox(height: 16),
        Divider(color: colorScheme.outlineVariant),
        const SizedBox(height: 16),

        // Air filter section
        const FormSubsectionTitle('Air Filter'),
        const SizedBox(height: 8),
        FormCheckboxRow(
          label: 'Air filter needs replacement',
          value: model.airFilterNeedsReplace,
          readOnly: readOnly,
          onChanged: (val) {
            model.airFilterNeedsReplace = val ?? false;
            _touch();
          },
        ),
        FormCheckboxRow(
          label: 'Air filter recently replaced',
          value: model.airFilterRecentlyReplaced,
          readOnly: readOnly,
          onChanged: (val) {
            model.airFilterRecentlyReplaced = val ?? false;
            _touch();
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: FormTextFieldRow(
                label: 'Last Replaced Date',
                hintText: 'e.g. 2025-02-15',
                initialValue: model.airFilterLastReplacedDate,
                readOnly: readOnly,
                onChanged: (value) {
                  model.airFilterLastReplacedDate = value.trim();
                  _touch();
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FormTextFieldRow(
                label: 'Part Number',
                hintText: 'Air filter part #',
                initialValue: model.airFilterPartNo,
                readOnly: readOnly,
                onChanged: (value) {
                  model.airFilterPartNo = value.trim();
                  _touch();
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        Divider(color: colorScheme.outlineVariant),
        const SizedBox(height: 16),

        // Coolant section
        const FormSubsectionTitle('Coolant'),
        const SizedBox(height: 8),
        FormDropdownRow(
          label: 'Coolant Level',
          value: model.coolantLevel.isEmpty ? null : model.coolantLevel,
          items: const ['Full', '50%', 'Low', 'Unknown'],
          readOnly: readOnly,
          onChanged: (value) {
            model.coolantLevel = value ?? '';
            _touch();
          },
        ),
        const SizedBox(height: 8),
        FormDropdownRow(
          label: 'Coolant Color',
          value: model.coolantColor.isEmpty ? null : model.coolantColor,
          items: const ['Green', 'Orange', 'Blue', 'Unknown'],
          readOnly: readOnly,
          onChanged: (value) {
            model.coolantColor = value ?? '';
            _touch();
          },
        ),

        const SizedBox(height: 16),
        Divider(color: colorScheme.outlineVariant),
        const SizedBox(height: 16),

        // Hoses section
        const FormSubsectionTitle('Hoses (Condition & Notes)'),
        const SizedBox(height: 8),
        _HoseRow(
          label: 'Coolant hoses compromised',
          compromised: model.coolantHosesCompromised,
          recommendChange: model.coolantHosesRecommendChange,
          notes: model.coolantHosesInfo,
          readOnly: readOnly,
          onChanged: (comp, rec, notes) {
            model.coolantHosesCompromised = comp;
            model.coolantHosesRecommendChange = rec;
            model.coolantHosesInfo = notes;
            _touch();
          },
        ),
        _HoseRow(
          label: 'Fuel hoses compromised',
          compromised: model.fuelHosesCompromised,
          recommendChange: model.fuelHosesRecommendChange,
          notes: model.fuelHosesInfo,
          readOnly: readOnly,
          onChanged: (comp, rec, notes) {
            model.fuelHosesCompromised = comp;
            model.fuelHosesRecommendChange = rec;
            model.fuelHosesInfo = notes;
            _touch();
          },
        ),
        _HoseRow(
          label: 'Air intake hoses compromised',
          compromised: model.airIntakeHosesCompromised,
          recommendChange: model.airIntakeHosesRecommendChange,
          notes: model.airIntakeHosesInfo,
          readOnly: readOnly,
          onChanged: (comp, rec, notes) {
            model.airIntakeHosesCompromised = comp;
            model.airIntakeHosesRecommendChange = rec;
            model.airIntakeHosesInfo = notes;
            _touch();
          },
        ),
        _HoseRow(
          label: 'Oil hoses compromised',
          compromised: model.oilHosesCompromised,
          recommendChange: model.oilHosesRecommendChange,
          notes: model.oilHosesInfo,
          readOnly: readOnly,
          onChanged: (comp, rec, notes) {
            model.oilHosesCompromised = comp;
            model.oilHosesRecommendChange = rec;
            model.oilHosesInfo = notes;
            _touch();
          },
        ),
        _HoseRow(
          label: 'Additional hoses compromised',
          compromised: model.additionalHosesCompromised,
          recommendChange: model.additionalHosesRecommendChange,
          notes: model.additionalHosesInfo,
          readOnly: readOnly,
          onChanged: (comp, rec, notes) {
            model.additionalHosesCompromised = comp;
            model.additionalHosesRecommendChange = rec;
            model.additionalHosesInfo = notes;
            _touch();
          },
        ),

        const SizedBox(height: 16),
        Divider(color: colorScheme.outlineVariant),
        const SizedBox(height: 16),

        // Cannister / filters section
        const FormSubsectionTitle('Cannister Filters & Parts'),
        const SizedBox(height: 8),

        // IMPORTANT: callbacks MUST match (sel, part, {label})
        _CannisterRow(
          label: 'Lube',
          selected: model.canLube,
          partNumber: model.canLubePartNo,
          readOnly: readOnly,
          onChanged: (sel, part, {label}) {
            model.canLube = sel;
            model.canLubePartNo = part;
            _touch();
          },
        ),
        _CannisterRow(
          label: 'Fuel',
          selected: model.canFuel,
          partNumber: model.canFuelPartNo,
          readOnly: readOnly,
          onChanged: (sel, part, {label}) {
            model.canFuel = sel;
            model.canFuelPartNo = part;
            _touch();
          },
        ),
        _CannisterRow(
          label: 'Water Separator',
          selected: model.canWaterSep,
          partNumber: model.canWaterSepPartNo,
          readOnly: readOnly,
          onChanged: (sel, part, {label}) {
            model.canWaterSep = sel;
            model.canWaterSepPartNo = part;
            _touch();
          },
        ),
        _CannisterRow(
          label: 'Oil',
          selected: model.canOil,
          partNumber: model.canOilPartNo,
          readOnly: readOnly,
          onChanged: (sel, part, {label}) {
            model.canOil = sel;
            model.canOilPartNo = part;
            _touch();
          },
        ),

        _CannisterRow(
          label: model.canOther1Label.isEmpty ? 'Other 1' : model.canOther1Label,
          selected: model.canOther1,
          partNumber: model.canOther1PartNo,
          readOnly: readOnly,
          allowLabelEdit: true,
          initialLabel: model.canOther1Label,
          onChanged: (sel, part, {label}) {
            model.canOther1 = sel;
            model.canOther1PartNo = part;
            if (label != null) model.canOther1Label = label;
            _touch();
          },
        ),
        _CannisterRow(
          label: model.canOther2Label.isEmpty ? 'Other 2' : model.canOther2Label,
          selected: model.canOther2,
          partNumber: model.canOther2PartNo,
          readOnly: readOnly,
          allowLabelEdit: true,
          initialLabel: model.canOther2Label,
          onChanged: (sel, part, {label}) {
            model.canOther2 = sel;
            model.canOther2PartNo = part;
            if (label != null) model.canOther2Label = label;
            _touch();
          },
        ),
      ],
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: readOnly
            ? Opacity(
          opacity: 0.92,
          child: content,
        )
            : content,
      ),
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
        border: Border.all(color: background.withValues(alpha: 0.6)),
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

class _HoseRow extends StatelessWidget {
  final String label;
  final bool compromised;
  final bool recommendChange;
  final String notes;
  final bool readOnly;

  final void Function(bool compromised, bool recommendChange, String notes)
  onChanged;

  const _HoseRow({
    required this.label,
    required this.compromised,
    required this.recommendChange,
    required this.notes,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  value: compromised,
                  onChanged: readOnly
                      ? null
                      : (val) => onChanged(val ?? false, recommendChange, notes),
                  title: const Text('Compromised'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              Expanded(
                child: CheckboxListTile(
                  value: recommendChange,
                  onChanged: readOnly
                      ? null
                      : (val) => onChanged(compromised, val ?? false, notes),
                  title: const Text('Recommend change'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
            ],
          ),
          TextFormField(
            initialValue: notes,
            readOnly: readOnly,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'Notes / observations',
            ),
            onChanged: (value) =>
                onChanged(compromised, recommendChange, value.trim()),
          ),
        ],
      ),
    );
  }
}

class _CannisterRow extends StatelessWidget {
  final String label;
  final bool selected;
  final String partNumber;
  final bool readOnly;
  final bool allowLabelEdit;
  final String? initialLabel;

  final void Function(bool selected, String partNumber, {String? label})?
  onChanged;

  const _CannisterRow({
    required this.label,
    required this.selected,
    required this.partNumber,
    required this.onChanged,
    this.readOnly = false,
    this.allowLabelEdit = false,
    this.initialLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String effectiveLabel = (initialLabel == null || initialLabel!.isEmpty)
        ? label
        : initialLabel!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: selected,
            onChanged: readOnly
                ? null
                : (val) => onChanged?.call(
              val ?? false,
              partNumber,
              label: effectiveLabel,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (allowLabelEdit)
                  TextFormField(
                    initialValue: effectiveLabel,
                    readOnly: readOnly,
                    decoration: const InputDecoration(
                      labelText: 'Label',
                      isDense: true,
                    ),
                    onChanged: (value) {
                      effectiveLabel = value.trim();
                      onChanged?.call(selected, partNumber, label: effectiveLabel);
                    },
                  )
                else
                  Text(
                    effectiveLabel,
                    style: theme.textTheme.bodyMedium,
                  ),
                const SizedBox(height: 4),
                TextFormField(
                  initialValue: partNumber,
                  readOnly: readOnly,
                  decoration: const InputDecoration(
                    labelText: 'Part Number',
                    isDense: true,
                  ),
                  onChanged: (value) {
                    onChanged?.call(selected, value.trim(), label: effectiveLabel);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
