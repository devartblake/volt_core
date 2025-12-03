import 'package:flutter/material.dart';
import '../../data/models/inspection.dart';

class SectionPostInspection extends StatefulWidget {
  final Inspection model;
  final ValueChanged<Inspection> onChanged;
  const SectionPostInspection({super.key, required this.model, required this.onChanged});

  @override
  State<SectionPostInspection> createState() => _SectionPostInspectionState();
}

class _SectionPostInspectionState extends State<SectionPostInspection> {
  late Inspection m;

  @override
  void initState() {
    super.initState();
    m = widget.model;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Calculate completion percentage
    final checks = [
      m.gensetRunsUnderLoad,
      m.voltageFrequencyOk,
      m.exhaustOk,
      m.groundingBondingOk,
      m.controlPanelOk,
      m.safetyDevicesOk,
      m.deficienciesDocumented,
      m.loadbankDone,
      m.atsVerified,
      m.fuelStoredOver1Yr,
    ];
    final completed = checks.where((c) => c).length;
    final percentage = (completed / checks.length * 100).toInt();

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
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.checklist_rtl,
                    color: theme.colorScheme.onPrimaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Post-Inspection Checklist',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$completed of ${checks.length} items completed',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: percentage / 100,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(
                  percentage < 50
                      ? Colors.red
                      : percentage < 80
                      ? Colors.orange
                      : Colors.green,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$percentage% Complete',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            _modernSwitch(
              'Generator runs under load',
              Icons.power,
              m.gensetRunsUnderLoad,
                  (v) => m.gensetRunsUnderLoad = v,
              theme,
            ),
            const SizedBox(height: 8),
            _modernSwitch(
              'Voltage & frequency acceptable',
              Icons.electrical_services,
              m.voltageFrequencyOk,
                  (v) => m.voltageFrequencyOk = v,
              theme,
            ),
            const SizedBox(height: 8),
            _modernSwitch(
              'Exhaust condition OK',
              Icons.air,
              m.exhaustOk,
                  (v) => m.exhaustOk = v,
              theme,
            ),
            const SizedBox(height: 8),
            _modernSwitch(
              'Grounding / Bonding OK',
              Icons.bolt,
              m.groundingBondingOk,
                  (v) => m.groundingBondingOk = v,
              theme,
            ),
            const SizedBox(height: 8),
            _modernSwitch(
              'Control panel OK',
              Icons.dashboard,
              m.controlPanelOk,
                  (v) => m.controlPanelOk = v,
              theme,
            ),
            const SizedBox(height: 8),
            _modernSwitch(
              'Safety devices operational',
              Icons.security,
              m.safetyDevicesOk,
                  (v) => m.safetyDevicesOk = v,
              theme,
            ),
            const SizedBox(height: 8),
            _modernSwitch(
              'Deficiencies documented',
              Icons.description,
              m.deficienciesDocumented,
                  (v) => m.deficienciesDocumented = v,
              theme,
            ),
            const SizedBox(height: 8),
            _modernSwitch(
              'Loadbank test completed',
              Icons.science,
              m.loadbankDone,
                  (v) => m.loadbankDone = v,
              theme,
            ),
            const SizedBox(height: 8),
            _modernSwitch(
              'ATS verified',
              Icons.swap_horiz,
              m.atsVerified,
                  (v) => m.atsVerified = v,
              theme,
            ),
            const SizedBox(height: 8),
            _modernSwitch(
              'Fuel stored over 1 year',
              Icons.water_drop,
              m.fuelStoredOver1Yr,
                  (v) => m.fuelStoredOver1Yr = v,
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _modernSwitch(
      String label,
      IconData icon,
      bool val,
      ValueChanged<bool> on,
      ThemeData theme,
      ) {
    return Container(
      decoration: BoxDecoration(
        color: val
            ? theme.colorScheme.primaryContainer.withOpacity(0.3)
            : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: val
              ? theme.colorScheme.primary.withOpacity(0.5)
              : theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: SwitchListTile(
        title: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: val
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(label)),
          ],
        ),
        value: val,
        onChanged: (v) => _update(() => on(v)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _update(VoidCallback fn) {
    setState(fn);
    widget.onChanged(m);
  }
}