import 'package:flutter/material.dart';
import '../../data/models/inspection.dart';

class SectionMaterials extends StatefulWidget {
  final Inspection model;
  final ValueChanged<Inspection> onChanged;
  const SectionMaterials({super.key, required this.model, required this.onChanged});

  @override
  State<SectionMaterials> createState() => _SectionMaterialsState();
}

class _SectionMaterialsState extends State<SectionMaterials> {
  late Inspection m;

  @override
  void initState() {
    super.initState();
    m = widget.model;
  }

  void _update(VoidCallback fn) {
    setState(fn);
    widget.onChanged(m);
  }

  Future<void> _pickDate(
      BuildContext context,
      String? initial,
      ValueChanged<String> onSaved,
      ) async {
    final now = DateTime.now();
    DateTime? init;
    try {
      if (initial != null && initial.isNotEmpty) {
        init = DateTime.tryParse(initial);
      }
    } catch (_) {}

    final picked = await showDatePicker(
      context: context,
      initialDate: init ?? now,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      _update(() => onSaved(picked.toIso8601String().split('T').first));
    }
  }

  Widget _modernDateRow(
      String label,
      IconData icon,
      String value,
      ValueChanged<String> onSaved,
      ThemeData theme,
      ) {
    final hasDate = value.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: hasDate
            ? theme.colorScheme.primaryContainer.withOpacity(0.2)
            : null,
        borderRadius: BorderRadius.circular(12),
        border: hasDate
            ? Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 1,
        )
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextFormField(
              decoration: InputDecoration(
                labelText: label,
                prefixIcon: Icon(icon),
                hintText: 'YYYY-MM-DD',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                suffixIcon: hasDate
                    ? IconButton(
                  icon: const Icon(Icons.clear, size: 20),
                  onPressed: () => _update(() => onSaved('')),
                  tooltip: 'Clear date',
                )
                    : null,
              ),
              initialValue: value,
              readOnly: true,
              onTap: () => _pickDate(context, value, onSaved),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              tooltip: 'Pick date',
              onPressed: () => _pickDate(context, value, onSaved),
              icon: Icon(
                Icons.calendar_today,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
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
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.build_outlined,
                    color: theme.colorScheme.onSecondaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Service / Materials Replaced',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Service History',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            _modernDateRow(
              'Last Full Service Date',
              Icons.construction,
              m.lastServiceDate,
                  (v) => m.lastServiceDate = v,
              theme,
            ),
            const SizedBox(height: 12),
            Text(
              'Filter Changes',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            _modernDateRow(
              'Oil Filter Change Date',
              Icons.oil_barrel,
              m.oilFilterChangeDate,
                  (v) => m.oilFilterChangeDate = v,
              theme,
            ),
            const SizedBox(height: 12),
            _modernDateRow(
              'Fuel Filter Change Date',
              Icons.filter_alt_outlined,
              m.fuelFilterDate,
                  (v) => m.fuelFilterDate = v,
              theme,
            ),
            const SizedBox(height: 12),
            _modernDateRow(
              'Air Filter Change Date',
              Icons.air,
              m.airFilterDate,
                  (v) => m.airFilterDate = v,
              theme,
            ),
            const SizedBox(height: 16),
            Text(
              'Component Replacements',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            _modernDateRow(
              'Coolant Flush Date',
              Icons.water_drop_outlined,
              m.coolantFlushDate,
                  (v) => m.coolantFlushDate = v,
              theme,
            ),
            const SizedBox(height: 12),
            _modernDateRow(
              'Battery Replacement Date',
              Icons.battery_charging_full,
              m.batteryReplaceDate,
                  (v) => m.batteryReplaceDate = v,
              theme,
            ),
          ],
        ),
      ),
    );
  }
}