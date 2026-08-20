import 'package:flutter/material.dart';
import '../../domain/entities/inspection_entity.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../shared/widgets/widgets.dart';

class SectionFdnyDep extends StatefulWidget {
  final InspectionEntity model;
  final ValueChanged<InspectionEntity> onChanged;

  const SectionFdnyDep({
    super.key,
    required this.model,
    required this.onChanged,
  });

  @override
  State<SectionFdnyDep> createState() => _SectionFdnyDepState();
}

class _SectionFdnyDepState extends State<SectionFdnyDep> {
  late InspectionEntity m;

  @override
  void initState() {
    super.initState();
    m = widget.model;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.verified_user_outlined,
                    color: theme.colorScheme.onTertiaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'FDNY / DEP Compliance',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Fuel Storage',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Fuel Stored Type',
                prefixIcon: const Icon(Icons.local_gas_station),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              initialValue: m.fuelStoredType.isEmpty ? null : m.fuelStoredType,
              items: const [
                DropdownMenuItem(value: 'Diesel', child: Text('Diesel')),
                DropdownMenuItem(value: 'Gasoline', child: Text('Gasoline')),
                DropdownMenuItem(value: 'None', child: Text('None')),
              ],
              onChanged: (v) => _update(
                    (curr) => curr.copyWith(fuelStoredType: v ?? ''),
              ),
            ),
            const SizedBox(height: 16),
            LabeledField(
              label: 'Fuel Quantity',
              value: m.fuelQtyGallons,
              prefixIcon: Icons.water_drop_outlined,
              suffixText: 'Gallons',
              keyboardType: TextInputType.number,
              onChanged: (v) =>
                  _update((curr) => curr.copyWith(fuelQtyGallons: v)),
            ),
            const SizedBox(height: 16),
            _modernYesNo(
              'FDNY Permit Available',
              Icons.description_outlined,
              m.fdnyPermit,
                  (v) => _update(
                    (curr) => curr.copyWith(fdnyPermit: v),
              ),
              theme,
            ),
            const SizedBox(height: 12),
            _modernYesNo(
              'C-92 On Site',
              Icons.assignment_outlined,
              m.c92OnSite,
                  (v) => _update(
                    (curr) => curr.copyWith(c92OnSite: v),
              ),
              theme,
            ),
            const SizedBox(height: 12),
            _modernYesNo(
              'Gas Cut-off Valve Present',
              Icons.settings_input_component_outlined,
              m.gasCutoffValve,
                  (v) => _update(
                    (curr) => curr.copyWith(gasCutoffValve: v),
              ),
              theme,
            ),
            const SizedBox(height: 24),
            Divider(color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'DEP Requirements',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: 'DEP Size',
              value: m.depSizeKw,
              prefixIcon: Icons.power,
              suffixText: 'kW',
              keyboardType: TextInputType.number,
              onChanged: (v) =>
                  _update((curr) => curr.copyWith(depSizeKw: v)),
            ),
            const SizedBox(height: 16),
            _modernYesNo(
              'DEP Registered (CATS)',
              Icons.app_registration_outlined,
              m.depRegisteredCats,
                  (v) => _update(
                    (curr) => curr.copyWith(depRegisteredCats: v),
              ),
              theme,
            ),
            const SizedBox(height: 12),
            _modernYesNo(
              'DEP Certificate to Operate',
              Icons.verified_outlined,
              m.depCertificateOperate,
                  (v) => _update(
                    (curr) => curr.copyWith(depCertificateOperate: v),
              ),
              theme,
            ),
            const SizedBox(height: 12),
            _modernYesNo(
              'Tier 4 Compliant',
              Icons.eco_outlined,
              m.tier4Compliant,
                  (v) => _update(
                    (curr) => curr.copyWith(tier4Compliant: v),
              ),
              theme,
            ),
            const SizedBox(height: 12),
            _modernYesNo(
              'Smoke / Stack Test',
              Icons.cloud_outlined,
              m.smokeOrStackTest,
                  (v) => _update(
                    (curr) => curr.copyWith(smokeOrStackTest: v),
              ),
              theme,
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: m.recordsKept5Years
                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                    : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: m.recordsKept5Years
                      ? theme.colorScheme.primary.withValues(alpha: 0.5)
                      : theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
              child: SwitchListTile(
                title: Row(
                  children: [
                    Icon(
                      Icons.history,
                      size: 20,
                      color: m.recordsKept5Years
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Records kept for 5 years')),
                  ],
                ),
                value: m.recordsKept5Years,
                onChanged: (v) => _update(
                      (curr) => curr.copyWith(recordsKept5Years: v),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _modernYesNo(
      String label,
      IconData icon,
      String current,
      ValueChanged<String> on,
      ThemeData theme,
      ) {
    final opts = ['Yes', 'No', 'Unknown', 'N/A'];

    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
      initialValue: opts.contains(current) ? current : null,
      items: opts.map((e) {
        Color? color;
        IconData? statusIcon;
        if (e == 'Yes') {
          color = theme.status.success;
          statusIcon = Icons.check_circle;
        } else if (e == 'No') {
          color = theme.colorScheme.error;
          statusIcon = Icons.cancel;
        } else if (e == 'Unknown') {
          color = theme.status.warning;
          statusIcon = Icons.help;
        } else {
          color = Colors.grey;
          statusIcon = Icons.remove_circle_outline;
        }

        return DropdownMenuItem(
          value: e,
          child: Row(
            children: [
              Icon(statusIcon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(e),
            ],
          ),
        );
      }).toList(),
      onChanged: (v) {
        final value = v ?? 'Unknown';
        on(value);
      },
    );
  }

  void _update(InspectionEntity Function(InspectionEntity) transform) {
    setState(() {
      m = transform(m);
    });
    widget.onChanged(m);
  }
}
