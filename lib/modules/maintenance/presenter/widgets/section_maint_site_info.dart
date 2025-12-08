import 'package:flutter/material.dart';
import '../../infra/models/maintenance_record.dart';

class SectionMaintSiteInfo extends StatelessWidget {
  final MaintenanceRecord model;
  final ValueChanged<MaintenanceRecord> onChanged;

  const SectionMaintSiteInfo({
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
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.location_on_outlined,
                    color: colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Site & Generator Information',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Site Information Section
            Text(
              'Site Details',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Site Code',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.qr_code_2_outlined),
              ),
              initialValue: model.siteCode,
              onChanged: (v) => _update(() => model.siteCode = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Address',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.place_outlined),
              ),
              initialValue: model.address,
              maxLines: 2,
              onChanged: (v) => _update(() => model.address = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Technician Name',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.person_outline),
              ),
              initialValue: model.technicianName,
              onChanged: (v) => _update(() => model.technicianName = v),
            ),

            const SizedBox(height: 24),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 24),

            // Generator Information Section
            Text(
              'Generator Specifications',
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Make',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    initialValue: model.generatorMake,
                    onChanged: (v) => _update(() => model.generatorMake = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Model',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    initialValue: model.generatorModel,
                    onChanged: (v) => _update(() => model.generatorModel = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Serial Number',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.tag_outlined),
              ),
              initialValue: model.generatorSerial,
              onChanged: (v) => _update(() => model.generatorSerial = v),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Power Rating',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixText: 'KW',
                    ),
                    initialValue: model.generatorKw,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _update(() => model.generatorKw = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Voltage',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      suffixText: 'V',
                    ),
                    initialValue: model.voltageRating,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _update(() => model.voltageRating = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Engine Hours',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.timer_outlined),
                    ),
                    initialValue: model.engineHours,
                    keyboardType: TextInputType.number,
                    onChanged: (v) => _update(() => model.engineHours = v),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Fuel Type',
                      filled: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.local_gas_station_outlined),
                    ),
                    initialValue: model.fuelType,
                    onChanged: (v) => _update(() => model.fuelType = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Last Fuel Delivery Date',
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.calendar_today_outlined),
                helperText: 'Format: YYYY-MM-DD',
              ),
              initialValue: model.lastFuelDeliveryDate,
              onChanged: (v) => _update(() => model.lastFuelDeliveryDate = v),
            ),
          ],
        ),
      ),
    );
  }
}