import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/inspection.dart';
import '../../../settings/selection_options_provider.dart';

class SectionSiteInfo extends ConsumerStatefulWidget {
  final Inspection model;
  final ValueChanged<Inspection> onChanged;
  const SectionSiteInfo({
    super.key,
    required this.model,
    required this.onChanged,
  });

  @override
  ConsumerState<SectionSiteInfo> createState() => _SectionSiteInfoState();
}

class _SectionSiteInfoState extends ConsumerState<SectionSiteInfo> {
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

  Future<void> _promptAdd(
    String title,
    Future<void> Function(String) onAdd,
  ) async {
    final ctl = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text('Add $title'),
            content: TextField(
              controller: ctl,
              decoration: InputDecoration(labelText: title),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, ctl.text),
                child: const Text('Add'),
              ),
            ],
          ),
    );
    if (v != null && v.trim().isNotEmpty) {
      await onAdd(v.trim());
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = ref.watch(selectionOptionsReadyProvider);
    final opts = ref.watch(selectionOptionsProvider);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Site & Generator Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),

            // If still initializing, render inputs but disable dropdowns (no crash)
            if (ready.isLoading) const LinearProgressIndicator(),

            TextFormField(
              decoration: const InputDecoration(labelText: 'Site Code'),
              initialValue: m.siteCode,
              onChanged: (v) => _update(() => m.siteCode = v),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Site Grade'),
              value: m.siteGrade.isEmpty ? null : m.siteGrade,
              items: const [
                DropdownMenuItem(value: 'Green', child: Text('Green')),
                DropdownMenuItem(value: 'Amber', child: Text('Amber')),
                DropdownMenuItem(value: 'Red', child: Text('Red')),
              ],
              onChanged: (v) => _update(() => m.siteGrade = v ?? ''),
            ),
            const SizedBox(height: 8),
            TextFormField(
              decoration: const InputDecoration(labelText: 'Address'),
              initialValue: m.address,
              maxLines: 2,
              onChanged: (v) => _update(() => m.address = v),
            ),
            const SizedBox(height: 8),

            // Technician
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Technician Name',
                    ),
                    value: (m.technicianName.isEmpty) ? null : m.technicianName,
                    items: [
                      for (final t in opts.techs)
                        DropdownMenuItem(value: t, child: Text(t)),
                    ],
                    onChanged:
                        ready.isLoading
                            ? null
                            : (v) => _update(() => m.technicianName = v ?? ''),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Add technician',
                  onPressed:
                      ready.isLoading
                          ? null
                          : () => _promptAdd('Technician', opts.addTech),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Generator Make
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Generator Make',
                    ),
                    value: (m.generatorMake.isEmpty) ? null : m.generatorMake,
                    items: [
                      for (final t in opts.makes)
                        DropdownMenuItem(value: t, child: Text(t)),
                    ],
                    onChanged:
                        ready.isLoading
                            ? null
                            : (v) => _update(() => m.generatorMake = v ?? ''),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Add make',
                  onPressed:
                      ready.isLoading
                          ? null
                          : () => _promptAdd('Generator Make', opts.addMake),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Generator Model (free text)
            TextFormField(
              decoration: const InputDecoration(labelText: 'Generator Model'),
              initialValue: m.generatorModel,
              onChanged: (v) => _update(() => m.generatorModel = v),
            ),
            const SizedBox(height: 8),

            // Serial + kW
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Serial Number',
                    ),
                    initialValue: m.generatorSerial,
                    onChanged: (v) => _update(() => m.generatorSerial = v),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(labelText: 'kW Rating'),
                    initialValue: m.generatorKw,
                    onChanged: (v) => _update(() => m.generatorKw = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Engine hours
            TextFormField(
              decoration: const InputDecoration(labelText: 'Engine Hours'),
              initialValue: m.engineHours,
              onChanged: (v) => _update(() => m.engineHours = v),
            ),
            const SizedBox(height: 8),

            // Voltage
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Voltage Rating'),
                  value: (m.voltageRating.isEmpty) ? null : m.voltageRating,
                  items: [
                    for (final t in opts.voltages) DropdownMenuItem(value: t, child: Text(t)),
                  ],
                  onChanged: ready.isLoading ? null : (v) => _update(() => m.voltageRating = v ?? ''),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Add voltage',
                onPressed: ready.isLoading ? null : () => _promptAdd('Voltage Rating', opts.addVoltage),
                icon: const Icon(Icons.add),
              ),
            ]),
            const SizedBox(height: 8),

            // Fuel type
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Fuel Type'),
              value: m.fuelType.isEmpty ? null : m.fuelType,
              items: const [
                DropdownMenuItem(value: 'Diesel', child: Text('Diesel')),
                DropdownMenuItem(value: 'Gasoline', child: Text('Gasoline')),
                DropdownMenuItem(
                  value: 'NaturalGas',
                  child: Text('Natural Gas'),
                ),
                DropdownMenuItem(value: 'None', child: Text('None')),
              ],
              onChanged: (v) => _update(() => m.fuelType = v ?? ''),
            ),
          ],
        ),
      ),
    );
  }
}
