import 'package:flutter/material.dart';
import '../../infra/models/maintenance_record.dart';

class SectionMaintPostService extends StatelessWidget {
  final MaintenanceRecord model;
  final ValueChanged<MaintenanceRecord> onChanged;

  const SectionMaintPostService({
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
                    color: colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.task_alt_outlined,
                    color: colorScheme.onSecondaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Post-Service Checklist',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Complete all applicable checks before closing the service',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),

            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _checklistItem(
                    context: context,
                    icon: Icons.power_outlined,
                    title: 'Verified generator runs under load',
                    value: model.postVerifyRunsUnderLoad,
                    onChanged: (v) =>
                        _update(() => model.postVerifyRunsUnderLoad = v),
                  ),
                  _divider(colorScheme),
                  _checklistItem(
                    context: context,
                    icon: Icons.electric_bolt_outlined,
                    title: 'Checked voltage & frequency',
                    value: model.postCheckVoltFreq,
                    onChanged: (v) =>
                        _update(() => model.postCheckVoltFreq = v),
                  ),
                  _divider(colorScheme),
                  _checklistItem(
                    context: context,
                    icon: Icons.wind_power_outlined,
                    title: 'Inspected exhaust system',
                    value: model.postInspectExhaust,
                    onChanged: (v) =>
                        _update(() => model.postInspectExhaust = v),
                  ),
                  _divider(colorScheme),
                  _checklistItem(
                    context: context,
                    icon: Icons.cable_outlined,
                    title: 'Verified grounding & bonding',
                    value: model.postVerifyGrounding,
                    onChanged: (v) =>
                        _update(() => model.postVerifyGrounding = v),
                  ),
                  _divider(colorScheme),
                  _checklistItem(
                    context: context,
                    icon: Icons.dashboard_outlined,
                    title: 'Checked control panel operation',
                    value: model.postCheckControlPanel,
                    onChanged: (v) =>
                        _update(() => model.postCheckControlPanel = v),
                  ),
                  _divider(colorScheme),
                  _checklistItem(
                    context: context,
                    icon: Icons.security_outlined,
                    title: 'Ensured safety devices are in place & functional',
                    value: model.postEnsureSafetyDevices,
                    onChanged: (v) =>
                        _update(() => model.postEnsureSafetyDevices = v),
                  ),
                  _divider(colorScheme),
                  _checklistItem(
                    context: context,
                    icon: Icons.description_outlined,
                    title: 'Documented all deficiencies & recommendations',
                    value: model.postDocumentDeficiencies,
                    onChanged: (v) =>
                        _update(() => model.postDocumentDeficiencies = v),
                  ),
                  _divider(colorScheme),
                  _checklistItem(
                    context: context,
                    icon: Icons.analytics_outlined,
                    title: 'Performed load-bank test (if applicable)',
                    value: model.postLoadbankTest,
                    onChanged: (v) =>
                        _update(() => model.postLoadbankTest = v),
                  ),
                  _divider(colorScheme),
                  _checklistItem(
                    context: context,
                    icon: Icons.sync_alt_outlined,
                    title: 'Verified ATS functionality',
                    value: model.postAtsFunctionality,
                    onChanged: (v) =>
                        _update(() => model.postAtsFunctionality = v),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 24),

            Row(
              children: [
                Icon(
                  Icons.local_gas_station_outlined,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Fuel Storage',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: CheckboxListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                secondary: Icon(
                  Icons.warning_amber_outlined,
                  color: colorScheme.tertiary,
                ),
                title: const Text(
                  'Fuel stored longer than recommended',
                ),
                subtitle: const Text(
                  'Consider testing/conditioning',
                  style: TextStyle(fontSize: 12),
                ),
                value: model.fuelStoredLong,
                onChanged: (v) =>
                    _update(() => model.fuelStoredLong = v ?? false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checklistItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return CheckboxListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      secondary: Icon(
        icon,
        color: value ? colorScheme.primary : colorScheme.onSurfaceVariant,
        size: 20,
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: value ? colorScheme.onSurface : null,
          fontWeight: value ? FontWeight.w500 : null,
        ),
      ),
      value: value,
      onChanged: (v) => onChanged(v ?? false),
    );
  }

  Widget _divider(ColorScheme colorScheme) {
    return Divider(
      height: 1,
      color: colorScheme.outlineVariant.withOpacity(0.5),
      indent: 56,
    );
  }
}