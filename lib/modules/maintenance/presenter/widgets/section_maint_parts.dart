import 'package:flutter/material.dart';
import '../../infra/models/maintenance_record.dart';

class SectionMaintParts extends StatelessWidget {
  final MaintenanceRecord model;
  final ValueChanged<MaintenanceRecord> onChanged;

  const SectionMaintParts({
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
                    color: colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.inventory_2_outlined,
                    color: colorScheme.onTertiaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Parts & Materials Used',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Document all parts and materials used during service',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            _partField(
              context: context,
              icon: Icons.oil_barrel_outlined,
              label: 'Oil',
              hint: 'type & quantity',
              value: model.partsOilTypeQty,
              onChanged: (v) => _update(() => model.partsOilTypeQty = v),
            ),
            const SizedBox(height: 16),
            _partField(
              context: context,
              icon: Icons.water_drop_outlined,
              label: 'Coolant',
              hint: 'type & quantity',
              value: model.partsCoolantTypeQty,
              onChanged: (v) => _update(() => model.partsCoolantTypeQty = v),
            ),
            const SizedBox(height: 16),
            _partField(
              context: context,
              icon: Icons.filter_alt_outlined,
              label: 'Filters',
              hint: 'types installed',
              value: model.partsFilterTypes,
              onChanged: (v) => _update(() => model.partsFilterTypes = v),
            ),
            const SizedBox(height: 16),
            _partField(
              context: context,
              icon: Icons.battery_charging_full_outlined,
              label: 'Battery',
              hint: 'type / install date',
              value: model.partsBatteryTypeDate,
              onChanged: (v) => _update(() => model.partsBatteryTypeDate = v),
            ),
            const SizedBox(height: 16),
            _partField(
              context: context,
              icon: Icons.settings_input_component_outlined,
              label: 'Belts / Hoses',
              hint: 'replaced items',
              value: model.partsBeltsHosesReplaced,
              onChanged: (v) => _update(() => model.partsBeltsHosesReplaced = v),
            ),
            const SizedBox(height: 16),
            _partField(
              context: context,
              icon: Icons.thermostat_outlined,
              label: 'Block Heater',
              hint: 'wattage / details',
              value: model.partsBlockHeaterWattage,
              onChanged: (v) => _update(() => model.partsBlockHeaterWattage = v),
            ),
            const SizedBox(height: 16),
            _partField(
              context: context,
              icon: Icons.memory_outlined,
              label: 'CDVR',
              hint: 'serial / part info',
              value: model.partsCdvrSerial,
              onChanged: (v) => _update(() => model.partsCdvrSerial = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _partField({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String hint,
    required String value,
    required void Function(String) onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              decoration: InputDecoration(
                hintText: hint,
                filled: true,
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              initialValue: value,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}