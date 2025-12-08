import 'package:flutter/material.dart';
import '../../infra/models/maintenance_record.dart';

class SectionMaintActions extends StatelessWidget {
  final MaintenanceRecord model;
  final ValueChanged<MaintenanceRecord> onChanged;

  const SectionMaintActions({
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
                    Icons.build_outlined,
                    color: colorScheme.onTertiaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Maintenance Actions Performed',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _actionRow(
              context: context,
              label: 'Oil filter changed',
              value: model.oilFilterChanged,
              notes: model.oilFilterNotes,
              icon: Icons.oil_barrel_outlined,
              onChanged: (v, notes) => _update(() {
                model.oilFilterChanged = v;
                model.oilFilterNotes = notes;
              }),
            ),
            _actionRow(
              context: context,
              label: 'Fuel filter replaced',
              value: model.fuelFilterReplaced,
              notes: model.fuelFilterNotes,
              icon: Icons.filter_alt_outlined,
              onChanged: (v, notes) => _update(() {
                model.fuelFilterReplaced = v;
                model.fuelFilterNotes = notes;
              }),
            ),
            _actionRow(
              context: context,
              label: 'Coolant flushed / topped off',
              value: model.coolantFlushed,
              notes: model.coolantNotes,
              icon: Icons.water_drop_outlined,
              onChanged: (v, notes) => _update(() {
                model.coolantFlushed = v;
                model.coolantNotes = notes;
              }),
            ),
            _actionRow(
              context: context,
              label: 'Battery replaced / serviced',
              value: model.batteryReplaced,
              notes: model.batteryNotes,
              icon: Icons.battery_charging_full_outlined,
              onChanged: (v, notes) => _update(() {
                model.batteryReplaced = v;
                model.batteryNotes = notes;
              }),
            ),
            _actionRow(
              context: context,
              label: 'Air filter replaced',
              value: model.airFilterReplaced,
              notes: model.airFilterNotes,
              icon: Icons.air_outlined,
              onChanged: (v, notes) => _update(() {
                model.airFilterReplaced = v;
                model.airFilterNotes = notes;
              }),
            ),
            _actionRow(
              context: context,
              label: 'Belts / hoses replaced',
              value: model.beltsHosesReplaced,
              notes: model.beltsHosesNotes,
              icon: Icons.settings_input_component_outlined,
              onChanged: (v, notes) => _update(() {
                model.beltsHosesReplaced = v;
                model.beltsHosesNotes = notes;
              }),
            ),
            _actionRow(
              context: context,
              label: 'Block heater tested & functional',
              value: model.blockHeaterTested,
              notes: model.blockHeaterNotes,
              icon: Icons.thermostat_outlined,
              onChanged: (v, notes) => _update(() {
                model.blockHeaterTested = v;
                model.blockHeaterNotes = notes;
              }),
            ),
            _actionRow(
              context: context,
              label: 'Racor / fuel-water separator serviced',
              value: model.racorServiced,
              notes: model.racorNotes,
              icon: Icons.cleaning_services_outlined,
              onChanged: (v, notes) => _update(() {
                model.racorServiced = v;
                model.racorNotes = notes;
              }),
            ),
            _actionRow(
              context: context,
              label: 'ATS / controller inspected',
              value: model.atsControllerInspected,
              notes: model.atsControllerNotes,
              icon: Icons.electrical_services_outlined,
              onChanged: (v, notes) => _update(() {
                model.atsControllerInspected = v;
                model.atsControllerNotes = notes;
              }),
            ),
            _actionRow(
              context: context,
              label: 'CDVR programmed / calibrated',
              value: model.cdvrProgrammed,
              notes: model.cdvrNotes,
              icon: Icons.settings_outlined,
              onChanged: (v, notes) => _update(() {
                model.cdvrProgrammed = v;
                model.cdvrNotes = notes;
              }),
            ),
            _actionRow(
              context: context,
              label: 'Under-voltage issue repaired',
              value: model.undervoltageRepaired,
              notes: model.undervoltageNotes,
              icon: Icons.bolt_outlined,
              onChanged: (v, notes) => _update(() {
                model.undervoltageRepaired = v;
                model.undervoltageNotes = notes;
              }),
            ),
            _actionRow(
              context: context,
              label: 'Hazardous material removed / disposed',
              value: model.hazmatRemoved,
              notes: model.hazmatNotes,
              icon: Icons.delete_outline,
              onChanged: (v, notes) => _update(() {
                model.hazmatRemoved = v;
                model.hazmatNotes = notes;
              }),
            ),

            const SizedBox(height: 24),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 24),

            Row(
              children: [
                Icon(
                  Icons.notes_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Service Observations / Notes',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Describe any issues, recommendations, or follow-up work',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              initialValue: model.serviceObservations,
              onChanged: (v) =>
                  _update(() => model.serviceObservations = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionRow({
    required BuildContext context,
    required String label,
    required bool value,
    required String notes,
    required IconData icon,
    required void Function(bool value, String notes) onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: value
            ? colorScheme.primaryContainer.withOpacity(0.3)
            : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value
              ? colorScheme.primary.withOpacity(0.3)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            title: Row(
              children: [
                Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
            value: value,
            onChanged: (v) => onChanged(v, notes),
          ),
          if (value) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Notes',
                  filled: true,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                initialValue: notes,
                maxLines: 2,
                onChanged: (v) => onChanged(value, v),
              ),
            ),
          ],
        ],
      ),
    );
  }
}