import 'package:flutter/material.dart';

import '../../infra/models/maintenance_record.dart';

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
              'General Maintenance',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            // Battery section
            _SectionTitle('Battery'),
            const SizedBox(height: 8),
            _CheckboxRow(
              label: 'Battery needs replacement',
              value: model.batteryNeedsReplace,
              readOnly: readOnly,
              onChanged: (val) {
                model.batteryNeedsReplace = val ?? false;
                onChanged(model);
              },
            ),
            _CheckboxRow(
              label: 'Battery recently replaced',
              value: model.batteryRecentlyReplaced,
              readOnly: readOnly,
              onChanged: (val) {
                model.batteryRecentlyReplaced = val ?? false;
                onChanged(model);
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TextFieldRow(
                    label: 'Manufacture Date',
                    hintText: 'e.g. 2025-01',
                    initialValue: model.batteryMfgDate,
                    readOnly: readOnly,
                    onChanged: (value) {
                      model.batteryMfgDate = value.trim();
                      onChanged(model);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TextFieldRow(
                    label: 'Part Number',
                    hintText: 'Battery part #',
                    initialValue: model.batteryPartNo,
                    readOnly: readOnly,
                    onChanged: (value) {
                      model.batteryPartNo = value.trim();
                      onChanged(model);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _TextFieldRow(
              label: 'Battery Type',
              hintText: 'e.g. Lead Acid, NiCad',
              initialValue: model.batteryType,
              readOnly: readOnly,
              onChanged: (value) {
                model.batteryType = value.trim();
                onChanged(model);
              },
            ),

            const SizedBox(height: 16),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 16),

            // Air filter section
            _SectionTitle('Air Filter'),
            const SizedBox(height: 8),
            _CheckboxRow(
              label: 'Air filter needs replacement',
              value: model.airFilterNeedsReplace,
              readOnly: readOnly,
              onChanged: (val) {
                model.airFilterNeedsReplace = val ?? false;
                onChanged(model);
              },
            ),
            _CheckboxRow(
              label: 'Air filter recently replaced',
              value: model.airFilterRecentlyReplaced,
              readOnly: readOnly,
              onChanged: (val) {
                model.airFilterRecentlyReplaced = val ?? false;
                onChanged(model);
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TextFieldRow(
                    label: 'Last Replaced Date',
                    hintText: 'e.g. 2025-02-15',
                    initialValue: model.airFilterLastReplacedDate,
                    readOnly: readOnly,
                    onChanged: (value) {
                      model.airFilterLastReplacedDate = value.trim();
                      onChanged(model);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TextFieldRow(
                    label: 'Part Number',
                    hintText: 'Air filter part #',
                    initialValue: model.airFilterPartNo,
                    readOnly: readOnly,
                    onChanged: (value) {
                      model.airFilterPartNo = value.trim();
                      onChanged(model);
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 16),

            // Coolant section
            _SectionTitle('Coolant'),
            const SizedBox(height: 8),
            _DropdownRow(
              label: 'Coolant Level',
              value: model.coolantLevel.isEmpty ? null : model.coolantLevel,
              items: const ['Full', '50%', 'Low', 'Unknown'],
              readOnly: readOnly,
              onChanged: (value) {
                model.coolantLevel = value ?? '';
                onChanged(model);
              },
            ),
            const SizedBox(height: 8),
            _DropdownRow(
              label: 'Coolant Color',
              value: model.coolantColor.isEmpty ? null : model.coolantColor,
              items: const ['Green', 'Orange', 'Blue', 'Unknown'],
              readOnly: readOnly,
              onChanged: (value) {
                model.coolantColor = value ?? '';
                onChanged(model);
              },
            ),

            const SizedBox(height: 16),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 16),

            // Hoses section
            _SectionTitle('Hoses (Condition & Notes)'),
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
                onChanged(model);
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
                onChanged(model);
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
                onChanged(model);
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
                onChanged(model);
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
                onChanged(model);
              },
            ),

            const SizedBox(height: 16),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 16),

            // Cannister / filters section
            _SectionTitle('Cannister Filters & Parts'),
            const SizedBox(height: 8),
            _CannisterRow(
              label: 'Lube',
              selected: model.canLube,
              partNumber: model.canLubePartNo,
              readOnly: readOnly,
              onChanged: (sel, part, {label}) {
                model.canLube = sel;
                model.canLubePartNo = part;
                onChanged(model);
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
                onChanged(model);
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
                onChanged(model);
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
                onChanged(model);
              },
            ),
            _CannisterRow(
              label: model.canOther1Label.isEmpty
                  ? 'Other 1'
                  : model.canOther1Label,
              selected: model.canOther1,
              partNumber: model.canOther1PartNo,
              readOnly: readOnly,
              allowLabelEdit: true,
              initialLabel: model.canOther1Label,
              onChanged: (sel, part, {label}) {
                model.canOther1 = sel;
                model.canOther1PartNo = part;
                if (label != null) {
                  model.canOther1Label = label;
                }
                onChanged(model);
              },
            ),
            _CannisterRow(
              label: model.canOther2Label.isEmpty
                  ? 'Other 2'
                  : model.canOther2Label,
              selected: model.canOther2,
              partNumber: model.canOther2PartNo,
              readOnly: readOnly,
              allowLabelEdit: true,
              initialLabel: model.canOther2Label,
              onChanged: (sel, part, {label}) {
                model.canOther2 = sel;
                model.canOther2PartNo = part;
                if (label != null) {
                  model.canOther2Label = label;
                }
                onChanged(model);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _TextFieldRow extends StatelessWidget {
  final String label;
  final String initialValue;
  final String? hintText;
  final bool readOnly;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String> onChanged;

  const _TextFieldRow({
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.hintText,
    this.readOnly = false,
    this.maxLines = 1,
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
          maxLines: maxLines,
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

class _DropdownRow extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final bool readOnly;
  final ValueChanged<String?> onChanged;

  const _DropdownRow({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
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
        DropdownButtonFormField<String>(
          value: value,
          onChanged: readOnly ? null : onChanged,
          items: items
              .map(
                (e) => DropdownMenuItem(
              value: e,
              child: Text(e),
            ),
          )
              .toList(),
          decoration: const InputDecoration(
            hintText: 'Select',
          ),
        ),
      ],
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
      title: Text(label, style: theme.textTheme.bodyMedium),
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
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
                      : (val) =>
                      onChanged(val ?? false, recommendChange, notes),
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
                      : (val) =>
                      onChanged(compromised, val ?? false, notes),
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
    super.key,
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

    String effectiveLabel = initialLabel == null || initialLabel!.isEmpty
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
                : (val) => onChanged?.call(val ?? false, partNumber,
                label: effectiveLabel),
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
