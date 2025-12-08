import 'package:flutter/material.dart';
import '../../infra/models/maintenance_record.dart';

class SectionMaintGeneral extends StatelessWidget {
  final MaintenanceRecord model;
  final ValueChanged<MaintenanceRecord> onChanged;

  const SectionMaintGeneral({
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
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.settings_outlined,
                    color: colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'General Maintenance – Battery & Air Filter',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Battery Section
            _buildSectionHeader(
              context: context,
              icon: Icons.battery_charging_full_outlined,
              title: 'Battery',
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: const Text('Battery needs replacement'),
                    subtitle: Text(
                      'Mark if battery should be replaced',
                      style: theme.textTheme.bodySmall,
                    ),
                    value: model.batteryNeedsReplace,
                    onChanged: (v) =>
                        _update(() => model.batteryNeedsReplace = v),
                  ),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: const Text('Battery recently replaced'),
                    subtitle: Text(
                      'Confirm if replacement was done',
                      style: theme.textTheme.bodySmall,
                    ),
                    value: model.batteryRecentlyReplaced,
                    onChanged: (v) =>
                        _update(() => model.batteryRecentlyReplaced = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Manufacturing Date',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.calendar_today_outlined),
                    ),
                    initialValue: model.batteryMfgDate,
                    onChanged: (v) =>
                        _update(() => model.batteryMfgDate = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Part Number',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.tag_outlined),
                    ),
                    initialValue: model.batteryPartNo,
                    onChanged: (v) =>
                        _update(() => model.batteryPartNo = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Battery Type',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.battery_std_outlined),
              ),
              value: model.batteryType.isEmpty ? null : model.batteryType,
              items: const [
                DropdownMenuItem(value: 'Lead Acid', child: Text('Lead Acid')),
                DropdownMenuItem(value: 'NiCad', child: Text('NiCad')),
                DropdownMenuItem(value: 'AGM', child: Text('AGM')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (v) =>
                  _update(() => model.batteryType = v ?? ''),
            ),

            const SizedBox(height: 24),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 24),

            // Air Filter Section
            _buildSectionHeader(
              context: context,
              icon: Icons.air_outlined,
              title: 'Air Filter',
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: const Text('Air filter needs replacement'),
                    subtitle: Text(
                      'Mark if filter should be replaced',
                      style: theme.textTheme.bodySmall,
                    ),
                    value: model.airFilterNeedsReplace,
                    onChanged: (v) =>
                        _update(() => model.airFilterNeedsReplace = v),
                  ),
                  Divider(height: 1, color: colorScheme.outlineVariant),
                  SwitchListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: const Text('Air filter recently replaced'),
                    subtitle: Text(
                      'Confirm if replacement was done',
                      style: theme.textTheme.bodySmall,
                    ),
                    value: model.airFilterRecentlyReplaced,
                    onChanged: (v) =>
                        _update(() => model.airFilterRecentlyReplaced = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Last Replaced',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.history_outlined),
                    ),
                    initialValue: model.airFilterLastReplacedDate,
                    onChanged: (v) =>
                        _update(() => model.airFilterLastReplacedDate = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Part Number',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.tag_outlined),
                    ),
                    initialValue: model.airFilterPartNo,
                    onChanged: (v) =>
                        _update(() => model.airFilterPartNo = v),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 24),

            // Coolant & Hoses Section
            _buildSectionHeader(
              context: context,
              icon: Icons.water_drop_outlined,
              title: 'Coolant & Hoses',
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Coolant Level',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    value: model.coolantLevel.isEmpty ? null : model.coolantLevel,
                    items: const [
                      DropdownMenuItem(value: 'Full', child: Text('Full')),
                      DropdownMenuItem(value: 'Approx. 50%', child: Text('Approx. 50%')),
                      DropdownMenuItem(value: 'Low', child: Text('Low')),
                    ],
                    onChanged: (v) =>
                        _update(() => model.coolantLevel = v ?? ''),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Coolant Color',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    value: model.coolantColor.isEmpty ? null : model.coolantColor,
                    items: const [
                      DropdownMenuItem(value: 'Green', child: Text('Green')),
                      DropdownMenuItem(value: 'Orange', child: Text('Orange')),
                      DropdownMenuItem(value: 'Blue', child: Text('Blue')),
                      DropdownMenuItem(value: 'Unknown', child: Text('Unknown')),
                    ],
                    onChanged: (v) =>
                        _update(() => model.coolantColor = v ?? ''),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            _hoseBlock(
              context: context,
              title: 'Coolant Hoses',
              icon: Icons.sensors_outlined,
              compromised: model.coolantHosesCompromised,
              recommendChange: model.coolantHosesRecommendChange,
              info: model.coolantHosesInfo,
              onChanged: (c, r, i) => _update(() {
                model.coolantHosesCompromised = c;
                model.coolantHosesRecommendChange = r;
                model.coolantHosesInfo = i;
              }),
            ),
            const SizedBox(height: 16),
            _hoseBlock(
              context: context,
              title: 'Fuel Hoses',
              icon: Icons.local_gas_station_outlined,
              compromised: model.fuelHosesCompromised,
              recommendChange: model.fuelHosesRecommendChange,
              info: model.fuelHosesInfo,
              onChanged: (c, r, i) => _update(() {
                model.fuelHosesCompromised = c;
                model.fuelHosesRecommendChange = r;
                model.fuelHosesInfo = i;
              }),
            ),
            const SizedBox(height: 16),
            _hoseBlock(
              context: context,
              title: 'Air Intake Hoses',
              icon: Icons.air_outlined,
              compromised: model.airIntakeHosesCompromised,
              recommendChange: model.airIntakeHosesRecommendChange,
              info: model.airIntakeHosesInfo,
              onChanged: (c, r, i) => _update(() {
                model.airIntakeHosesCompromised = c;
                model.airIntakeHosesRecommendChange = r;
                model.airIntakeHosesInfo = i;
              }),
            ),
            const SizedBox(height: 16),
            _hoseBlock(
              context: context,
              title: 'Oil Hoses',
              icon: Icons.oil_barrel_outlined,
              compromised: model.oilHosesCompromised,
              recommendChange: model.oilHosesRecommendChange,
              info: model.oilHosesInfo,
              onChanged: (c, r, i) => _update(() {
                model.oilHosesCompromised = c;
                model.oilHosesRecommendChange = r;
                model.oilHosesInfo = i;
              }),
            ),
            const SizedBox(height: 16),
            _hoseBlock(
              context: context,
              title: 'Additional Hoses',
              icon: Icons.more_horiz_outlined,
              compromised: model.additionalHosesCompromised,
              recommendChange: model.additionalHosesRecommendChange,
              info: model.additionalHosesInfo,
              onChanged: (c, r, i) => _update(() {
                model.additionalHosesCompromised = c;
                model.additionalHosesRecommendChange = r;
                model.additionalHosesInfo = i;
              }),
            ),

            const SizedBox(height: 24),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 24),

            // Cannisters / Filters Section
            _buildSectionHeader(
              context: context,
              icon: Icons.filter_alt_outlined,
              title: 'Canisters / Filters Needed',
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 12),
            _canRow(
              context: context,
              label: 'Lube Filter',
              checked: model.canLube,
              partNo: model.canLubePartNo,
              onChanged: (c, p) =>
                  _update(() {
                    model.canLube = c;
                    model.canLubePartNo = p;
                  }),
            ),
            const SizedBox(height: 12),
            _canRow(
              context: context,
              label: 'Fuel Filter',
              checked: model.canFuel,
              partNo: model.canFuelPartNo,
              onChanged: (c, p) =>
                  _update(() {
                    model.canFuel = c;
                    model.canFuelPartNo = p;
                  }),
            ),
            const SizedBox(height: 12),
            _canRow(
              context: context,
              label: 'Water Separator',
              checked: model.canWaterSep,
              partNo: model.canWaterSepPartNo,
              onChanged: (c, p) =>
                  _update(() {
                    model.canWaterSep = c;
                    model.canWaterSepPartNo = p;
                  }),
            ),
            const SizedBox(height: 12),
            _canRow(
              context: context,
              label: 'Oil Filter',
              checked: model.canOil,
              partNo: model.canOilPartNo,
              onChanged: (c, p) =>
                  _update(() {
                    model.canOil = c;
                    model.canOilPartNo = p;
                  }),
            ),
            const SizedBox(height: 12),
            _canOtherRow(
              context: context,
              label: model.canOther1Label.isEmpty ? 'Other 1' : model.canOther1Label,
              checked: model.canOther1,
              customLabel: model.canOther1Label,
              partNo: model.canOther1PartNo,
              onChanged: (c, lbl, p) => _update(() {
                model.canOther1 = c;
                model.canOther1Label = lbl;
                model.canOther1PartNo = p;
              }),
            ),
            const SizedBox(height: 12),
            _canOtherRow(
              context: context,
              label: model.canOther2Label.isEmpty ? 'Other 2' : model.canOther2Label,
              checked: model.canOther2,
              customLabel: model.canOther2Label,
              partNo: model.canOther2PartNo,
              onChanged: (c, lbl, p) => _update(() {
                model.canOther2 = c;
                model.canOther2Label = lbl;
                model.canOther2PartNo = p;
              }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required IconData icon,
    required String title,
    required ColorScheme colorScheme,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            color: colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _hoseBlock({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool compromised,
    required bool recommendChange,
    required String info,
    required void Function(bool compromised, bool recommend, String info) onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (compromised || recommendChange)
              ? colorScheme.error.withOpacity(0.3)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Compromised'),
                    value: compromised,
                    onChanged: (v) => onChanged(v ?? false, recommendChange, info),
                  ),
                ),
                Expanded(
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Recommend change'),
                    value: recommendChange,
                    onChanged: (v) => onChanged(compromised, v ?? false, info),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Notes / Observations',
                filled: true,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              initialValue: info,
              maxLines: 2,
              onChanged: (v) => onChanged(compromised, recommendChange, v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _canRow({
    required BuildContext context,
    required String label,
    required bool checked,
    required String partNo,
    required void Function(bool checked, String partNo) onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: checked
            ? colorScheme.primaryContainer.withOpacity(0.3)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: checked
              ? colorScheme.primary.withOpacity(0.3)
              : colorScheme.outlineVariant,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Checkbox(
            value: checked,
            onChanged: (v) => onChanged(v ?? false, partNo),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 180,
            child: TextFormField(
              decoration: InputDecoration(
                labelText: 'Part No.',
                filled: true,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              initialValue: partNo,
              onChanged: (v) => onChanged(checked, v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _canOtherRow({
    required BuildContext context,
    required String label,
    required bool checked,
    required String customLabel,
    required String partNo,
    required void Function(bool checked, String customLabel, String partNo) onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: checked
            ? colorScheme.tertiaryContainer.withOpacity(0.3)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: checked
              ? colorScheme.tertiary.withOpacity(0.3)
              : colorScheme.outlineVariant,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: checked,
                onChanged: (v) => onChanged(v ?? false, customLabel, partNo),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
          if (checked) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Custom Label',
                      filled: true,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    initialValue: customLabel,
                    onChanged: (v) => onChanged(checked, v, partNo),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Part No.',
                      filled: true,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    initialValue: partNo,
                    onChanged: (v) => onChanged(checked, customLabel, v),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}