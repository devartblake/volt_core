import 'package:flutter/material.dart';
import '../../data/models/inspection.dart';

class SectionOperationalUse extends StatefulWidget {
  final Inspection model;
  final ValueChanged<Inspection> onChanged;
  const SectionOperationalUse({super.key, required this.model, required this.onChanged});

  @override
  State<SectionOperationalUse> createState() => _SectionOperationalUseState();
}

class _SectionOperationalUseState extends State<SectionOperationalUse> {
  late Inspection m;

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
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.power_settings_new,
                    color: theme.colorScheme.onErrorContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Operational Use',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: m.emergencyOnly
                    ? theme.colorScheme.errorContainer.withOpacity(0.3)
                    : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: m.emergencyOnly
                      ? theme.colorScheme.error.withOpacity(0.5)
                      : theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
              child: SwitchListTile(
                title: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 20,
                      color: m.emergencyOnly
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(child: Text('Emergency Use Only')),
                  ],
                ),
                value: m.emergencyOnly,
                onChanged: (v) => _update(() => m.emergencyOnly = v),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Estimated Annual Runtime',
                prefixIcon: const Icon(Icons.schedule),
                suffixText: 'hours',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                helperText: 'Expected hours of operation per year',
              ),
              initialValue: m.estimatedAnnualRuntimeHours,
              keyboardType: TextInputType.number,
              onChanged: (v) => _update(() => m.estimatedAnnualRuntimeHours = v),
            ),
            const SizedBox(height: 16),
            _modernYesNo(
              'Fuel for minimum 6 hours',
              Icons.local_gas_station,
              m.fuelFor6hrs,
                  (v) => m.fuelFor6hrs = v,
              theme,
            ),
            const SizedBox(height: 24),
            Divider(color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'Additional Notes',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: InputDecoration(
                hintText: 'Add any additional observations or notes...',
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: Icon(Icons.notes),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              maxLines: 4,
              initialValue: m.notes,
              onChanged: (v) => _update(() => m.notes = v),
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
    const opts = ['Yes', 'No', 'N/A'];
    return DropdownButtonFormField<String>(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
      value: opts.contains(current) ? current : null,
      items: opts.map((e) {
        Color? color;
        IconData? statusIcon;
        if (e == 'Yes') {
          color = Colors.green;
          statusIcon = Icons.check_circle;
        } else if (e == 'No') {
          color = Colors.red;
          statusIcon = Icons.cancel;
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
      onChanged: (v) => _update(() => on(v ?? 'N/A')),
    );
  }

  void _update(VoidCallback fn) {
    setState(fn);
    widget.onChanged(m);
  }
}