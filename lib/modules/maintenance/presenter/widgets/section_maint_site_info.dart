import 'package:flutter/material.dart';

import '../../infra/models/maintenance_record.dart';

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
            Text(
              'Site & Generator Information',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _TextFieldRow(
              label: 'Site Code',
              hintText: 'e.g. K495-01',
              initialValue: model.siteCode,
              readOnly: readOnly,
              onChanged: (value) {
                model.siteCode = value.trim();
                onChanged(model);
              },
            ),
            const SizedBox(height: 12),
            _TextFieldRow(
              label: 'Address',
              hintText: 'Site address',
              initialValue: model.address,
              maxLines: 2,
              readOnly: readOnly,
              onChanged: (value) {
                model.address = value.trim();
                onChanged(model);
              },
            ),
            const SizedBox(height: 12),
            _DateFieldRow(
              label: 'Date of Service',
              value: model.dateOfService,
              readOnly: readOnly,
              onChanged: (value) {
                model.dateOfService = value;
                onChanged(model);
              },
            ),
            const SizedBox(height: 16),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 16),
            _TextFieldRow(
              label: 'Technician Name',
              hintText: 'Who performed the service?',
              initialValue: model.technicianName,
              readOnly: readOnly,
              onChanged: (value) {
                model.technicianName = value.trim();
                onChanged(model);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TextFieldRow(
                    label: 'Generator Make',
                    hintText: 'e.g. Kohler',
                    initialValue: model.generatorMake,
                    readOnly: readOnly,
                    onChanged: (value) {
                      model.generatorMake = value.trim();
                      onChanged(model);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TextFieldRow(
                    label: 'Generator Model',
                    hintText: 'e.g. 250REOZJE',
                    initialValue: model.generatorModel,
                    readOnly: readOnly,
                    onChanged: (value) {
                      model.generatorModel = value.trim();
                      onChanged(model);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TextFieldRow(
                    label: 'Serial Number',
                    hintText: 'Generator serial',
                    initialValue: model.generatorSerial,
                    readOnly: readOnly,
                    onChanged: (value) {
                      model.generatorSerial = value.trim();
                      onChanged(model);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TextFieldRow(
                    label: 'kW Rating',
                    hintText: 'e.g. 250',
                    initialValue: model.generatorKw,
                    readOnly: readOnly,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      model.generatorKw = value.trim();
                      onChanged(model);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TextFieldRow(
                    label: 'Engine Hours',
                    hintText: 'e.g. 1234',
                    initialValue: model.engineHours,
                    readOnly: readOnly,
                    keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) {
                      model.engineHours = value.trim();
                      onChanged(model);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TextFieldRow(
                    label: 'Voltage Rating',
                    hintText: 'e.g. 120/208V',
                    initialValue: model.voltageRating,
                    readOnly: readOnly,
                    onChanged: (value) {
                      model.voltageRating = value.trim();
                      onChanged(model);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TextFieldRow(
                    label: 'Fuel Type',
                    hintText: 'e.g. Diesel',
                    initialValue: model.fuelType,
                    readOnly: readOnly,
                    onChanged: (value) {
                      model.fuelType = value.trim();
                      onChanged(model);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TextFieldRow(
                    label: 'Last Fuel Delivery',
                    hintText: 'e.g. 2025-03-01',
                    initialValue: model.lastFuelDeliveryDate,
                    readOnly: readOnly,
                    onChanged: (value) {
                      model.lastFuelDeliveryDate = value.trim();
                      onChanged(model);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TextFieldRow extends StatelessWidget {
  final String label;
  final String? hintText;
  final String initialValue;
  final bool readOnly;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String> onChanged;

  const _TextFieldRow({
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.hintText,
    this.readOnly = false,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: initialValue,
          readOnly: readOnly,
          maxLines: maxLines,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hintText,
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _DateFieldRow extends StatelessWidget {
  final String label;
  final DateTime? value;
  final bool readOnly;
  final ValueChanged<DateTime?> onChanged;

  const _DateFieldRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final text = value == null
        ? ''
        : '${value!.year.toString().padLeft(4, '0')}-'
        '${value!.month.toString().padLeft(2, '0')}-'
        '${value!.day.toString().padLeft(2, '0')}';

    Future<void> _pick() async {
      if (readOnly) return;

      final now = DateTime.now();
      final initial = value ?? now;
      final picked = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(now.year - 5),
        lastDate: DateTime(now.year + 5),
      );
      if (picked != null) {
        onChanged(picked);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelMedium,
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: _pick,
          child: IgnorePointer(
            child: TextFormField(
              initialValue: text,
              readOnly: true,
              decoration: const InputDecoration(
                suffixIcon: Icon(Icons.calendar_today_outlined),
                hintText: 'Select date',
              ),
            ),
          ),
        ),
      ],
    );
  }
}
