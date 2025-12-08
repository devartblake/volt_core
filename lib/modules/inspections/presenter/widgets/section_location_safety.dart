import 'package:flutter/material.dart';
import '../../domain/entities/inspection_entity.dart';

class SectionLocationSafety extends StatefulWidget {
  final InspectionEntity model;
  final ValueChanged<InspectionEntity> onChanged;

  const SectionLocationSafety({
    super.key,
    required this.model,
    required this.onChanged,
  });

  @override
  State<SectionLocationSafety> createState() => _SectionLocationSafetyState();
}

class _SectionLocationSafetyState extends State<SectionLocationSafety> {
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
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.location_city,
                    color: theme.colorScheme.onSecondaryContainer,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Location & Safety',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Location Type',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _modernChip(
                  'Indoors',
                  Icons.home_outlined,
                  m.locIndoors,
                      (v) => _update((curr) => curr.copyWith(locIndoors: v)),
                  theme,
                ),
                _modernChip(
                  'Outdoors',
                  Icons.landscape_outlined,
                  m.locOutdoors,
                      (v) => _update((curr) => curr.copyWith(locOutdoors: v)),
                  theme,
                ),
                _modernChip(
                  'Roof',
                  Icons.roofing_outlined,
                  m.locRoof,
                      (v) => _update((curr) => curr.copyWith(locRoof: v)),
                  theme,
                ),
                _modernChip(
                  'Basement',
                  Icons.stairs_outlined,
                  m.locBasement,
                      (v) => _update((curr) => curr.copyWith(locBasement: v)),
                  theme,
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Other Location',
                prefixIcon: const Icon(Icons.place_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                hintText: 'Specify if not listed above',
              ),
              initialValue: m.locOther,
              onChanged: (v) =>
                  _update((curr) => curr.copyWith(locOther: v)),
            ),
            const SizedBox(height: 24),
            Divider(color: theme.colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'Safety Checks',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            _modernSwitch(
              'Dedicated 2-hour room',
              Icons.meeting_room_outlined,
              m.dedicatedRoom2hr,
                  (v) =>
                  _update((curr) => curr.copyWith(dedicatedRoom2hr: v)),
              theme,
            ),
            _modernSwitch(
              'Separate from main service',
              Icons.settings_input_composite_outlined,
              m.separateFromMainService,
                  (v) => _update(
                      (curr) => curr.copyWith(separateFromMainService: v)),
              theme,
            ),
            _modernSwitch(
              'Area clear of obstructions',
              Icons.check_circle_outline,
              m.areaClear,
                  (v) => _update((curr) => curr.copyWith(areaClear: v)),
              theme,
            ),
            _modernSwitch(
              'Labels & E-Stop visible',
              Icons.visibility_outlined,
              m.labelsAndEStopVisible,
                  (v) => _update(
                      (curr) => curr.copyWith(labelsAndEStopVisible: v)),
              theme,
            ),
            _modernSwitch(
              'Fire extinguisher present',
              Icons.fire_extinguisher_outlined,
              m.extinguisherPresent,
                  (v) =>
                  _update((curr) => curr.copyWith(extinguisherPresent: v)),
              theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _modernChip(
      String text,
      IconData icon,
      bool val,
      ValueChanged<bool> on,
      ThemeData theme,
      ) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(text),
        ],
      ),
      selected: val,
      onSelected: on,
      showCheckmark: true,
      selectedColor: theme.colorScheme.primaryContainer,
      checkmarkColor: theme.colorScheme.onPrimaryContainer,
      side: BorderSide(
        color: val
            ? theme.colorScheme.primary
            : theme.colorScheme.outlineVariant,
        width: 1.5,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  Widget _modernSwitch(
      String text,
      IconData icon,
      bool val,
      ValueChanged<bool> on,
      ThemeData theme,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
            Expanded(child: Text(text)),
          ],
        ),
        value: val,
        onChanged: on,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _update(InspectionEntity Function(InspectionEntity) transform) {
    setState(() {
      m = transform(m);
    });
    widget.onChanged(m);
  }
}
