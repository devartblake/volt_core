import 'package:flutter/material.dart';
import '../../domain/entities/inspection_entity.dart';

class SectionMaterials extends StatefulWidget {
  final InspectionEntity model;
  final ValueChanged<InspectionEntity> onChanged;

  const SectionMaterials({
    super.key,
    required this.model,
    required this.onChanged,
  });

  @override
  State<SectionMaterials> createState() => _SectionMaterialsState();
}

class _SectionMaterialsState extends State<SectionMaterials> {
  late InspectionEntity m;

  @override
  void initState() {
    super.initState();
    m = widget.model;
  }

  void _update(InspectionEntity Function(InspectionEntity) transform) {
    setState(() {
      m = transform(m);
    });
    widget.onChanged(m);
  }

  Future<void> _pickDate(
      BuildContext context,
      String? initial,
      InspectionEntity Function(InspectionEntity, String) onSavedBuilder,
      ) async {
    final now = DateTime.now();
    DateTime? init;

    try {
      if (initial != null && initial.isNotEmpty) {
        init = DateTime.tryParse(initial);
      }
    } catch (_) {
      // ignore parse errors, fall back to now
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: init ?? now,
      firstDate: DateTime(now.year - 20),
      lastDate: DateTime(now.year + 5),
    );

    if (picked != null) {
      final formatted = picked.toIso8601String().split('T').first;
      _update((curr) => onSavedBuilder(curr, formatted));
    }
  }

  Widget _modernDateRow(
      String label,
      IconData icon,
      String value,
      InspectionEntity Function(InspectionEntity, String) onSavedBuilder,
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
                  onPressed: () =>
                      _update((curr) => onSavedBuilder(curr, '')),
                  tooltip: 'Clear date',
                )
                    : null,
              ),
              initialValue: value,
              readOnly: true,
              onTap: () => _pickDate(context, value, onSavedBuilder),
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
              onPressed: () => _pickDate(context, value, onSavedBuilder),
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
                  (curr, v) => curr.copyWith(lastServiceDate: v),
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
                  (curr, v) => curr.copyWith(oilFilterChangeDate: v),
              theme,
            ),
            const SizedBox(height: 12),
            _modernDateRow(
              'Fuel Filter Change Date',
              Icons.filter_alt_outlined,
              m.fuelFilterDate,
                  (curr, v) => curr.copyWith(fuelFilterDate: v),
              theme,
            ),
            const SizedBox(height: 12),
            _modernDateRow(
              'Air Filter Change Date',
              Icons.air,
              m.airFilterDate,
                  (curr, v) => curr.copyWith(airFilterDate: v),
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
                  (curr, v) => curr.copyWith(coolantFlushDate: v),
              theme,
            ),
            const SizedBox(height: 12),
            _modernDateRow(
              'Battery Replacement Date',
              Icons.battery_charging_full,
              m.batteryReplaceDate,
                  (curr, v) => curr.copyWith(batteryReplaceDate: v),
              theme,
            ),
          ],
        ),
      ),
    );
  }
}
