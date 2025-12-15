import 'package:flutter/material.dart';
import '../../infra/models/maintenance_record.dart';

/// Modern site information section with enhanced UI
class SectionMaintSiteInfo extends StatelessWidget {
  final MaintenanceRecord model;
  final ValueChanged<MaintenanceRecord> onChanged;
  final bool readOnly;

  const SectionMaintSiteInfo({
    super.key,
    required this.model,
    required this.onChanged,
    this.readOnly = false,
  });

  void _updateModel(void Function() mutation) {
    mutation();
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.location_on_outlined,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Site & Generator Information',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Basic site and generator identification for this service.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Site Details Section
            _SectionLabel(
              icon: Icons.business_outlined,
              label: 'Site Details',
              color: colorScheme.primary,
            ),
            const SizedBox(height: 12),

            _ModernTextField(
              label: 'Site Code',
              hintText: 'e.g. NYC-GEN-014',
              icon: Icons.qr_code_2_outlined,
              initialValue: model.siteCode,
              readOnly: readOnly,
              onChanged: (v) => _updateModel(() => model.siteCode = v.trim()),
            ),
            const SizedBox(height: 12),

            _ModernTextField(
              label: 'Address',
              hintText: 'Street, city, state',
              icon: Icons.place_outlined,
              initialValue: model.address,
              readOnly: readOnly,
              maxLines: 2,
              onChanged: (v) => _updateModel(() => model.address = v.trim()),
            ),
            const SizedBox(height: 12),

            _ModernTextField(
              label: 'Technician Name',
              hintText: 'Assigned technician',
              icon: Icons.person_outline,
              initialValue: model.technicianName,
              readOnly: readOnly,
              onChanged: (v) => _updateModel(() => model.technicianName = v.trim()),
            ),

            const SizedBox(height: 20),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 20),

            // Generator Specifications Section
            _SectionLabel(
              icon: Icons.power_outlined,
              label: 'Generator Specifications',
              color: colorScheme.secondary,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _ModernTextField(
                    label: 'Make',
                    hintText: 'e.g. Generac',
                    icon: Icons.factory_outlined,
                    initialValue: model.generatorMake,
                    readOnly: readOnly,
                    onChanged: (v) => _updateModel(() => model.generatorMake = v.trim()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModernTextField(
                    label: 'Model',
                    hintText: 'Model number',
                    icon: Icons.tag_outlined,
                    initialValue: model.generatorModel,
                    readOnly: readOnly,
                    onChanged: (v) => _updateModel(() => model.generatorModel = v.trim()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _ModernTextField(
              label: 'Serial Number',
              hintText: 'Generator serial number',
              icon: Icons.numbers_outlined,
              initialValue: model.generatorSerial,
              readOnly: readOnly,
              onChanged: (v) => _updateModel(() => model.generatorSerial = v.trim()),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _ModernTextField(
                    label: 'Power Rating',
                    hintText: 'e.g. 150',
                    icon: Icons.bolt_outlined,
                    initialValue: model.generatorKw,
                    readOnly: readOnly,
                    suffixText: 'kW',
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _updateModel(() => model.generatorKw = v.trim()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModernTextField(
                    label: 'Voltage',
                    hintText: 'e.g. 480',
                    icon: Icons.electrical_services_outlined,
                    initialValue: model.voltageRating,
                    readOnly: readOnly,
                    suffixText: 'V',
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _updateModel(() => model.voltageRating = v.trim()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            _ModernTextField(
              label: 'Engine Hours',
              hintText: 'Current engine hours',
              icon: Icons.timer_outlined,
              initialValue: model.engineHours,
              readOnly: readOnly,
              keyboardType: TextInputType.number,
              onChanged: (v) => _updateModel(() => model.engineHours = v.trim()),
            ),
          ],
        ),
      ),
    );
  }
}

/// Modern section label with icon
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _SectionLabel({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Modern text field with icon and consistent styling
class _ModernTextField extends StatelessWidget {
  final String label;
  final String? hintText;
  final IconData? icon;
  final String initialValue;
  final bool readOnly;
  final int maxLines;
  final String? suffixText;
  final TextInputType? keyboardType;
  final ValueChanged<String> onChanged;

  const _ModernTextField({
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.hintText,
    this.icon,
    this.readOnly = false,
    this.maxLines = 1,
    this.suffixText,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: initialValue,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        suffixText: suffixText,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onChanged: onChanged,
    );
  }
}