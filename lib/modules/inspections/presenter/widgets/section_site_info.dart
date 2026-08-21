import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/inspection_entity.dart';
import '../../../settings/presenter/controllers/selection_options_provider.dart';
import '../../../../shared/widgets/widgets.dart';

class SectionSiteInfo extends ConsumerStatefulWidget {
  final InspectionEntity model;
  final ValueChanged<InspectionEntity> onChanged;

  const SectionSiteInfo({
    super.key,
    required this.model,
    required this.onChanged,
  });

  @override
  ConsumerState<SectionSiteInfo> createState() =>
      _SectionSiteInfoState();
}

class _SectionSiteInfoState extends ConsumerState<SectionSiteInfo> {
  /// The parent's current entity, never a snapshot.
  ///
  /// This used to be a field seeded in initState and never resynced. Because
  /// every section held its own copy from first build, each section's
  /// `copyWith` was applied to the *original* entity — so whichever section
  /// the technician edited last silently discarded every other section's data
  /// and the inspection saved almost empty.
  InspectionEntity get m => widget.model;

  void _update(InspectionEntity Function(InspectionEntity) transform) {
    widget.onChanged(transform(widget.model));
  }

  Future<void> _promptAdd(
      String title,
      Future<void> Function(String) onAdd,
      ) async {
    final ctl = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
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

            // If still initializing, render inputs but show progress
            if (ready.isLoading) const LinearProgressIndicator(),

            LabeledField(
              label: 'Site Code',
              value: m.siteCode,
              required: true,
              onChanged: (v) =>
                  _update((curr) => curr.copyWith(siteCode: v)),
            ),
            SelectionField<String>(
              label: 'Site Grade',
              value: m.siteGrade.isEmpty ? null : m.siteGrade,
              options: const ['Green', 'Amber', 'Red'],
              onChanged: (v) => _update(
                  (curr) => curr.copyWith(siteGrade: v ?? '')),
            ),
            LabeledField(
              label: 'Address',
              value: m.address,
              required: true,
              maxLines: 2,
              onChanged: (v) =>
                  _update((curr) => curr.copyWith(address: v)),
            ),

            // Technician — the kit's own "add option" affordance replaces the
            // hand-built Row + IconButton this used to need.
            SelectionField<String>(
              label: 'Technician Name',
              value: m.technicianName.isEmpty ? null : m.technicianName,
              options: opts.techs,
              enabled: !ready.isLoading,
              onChanged: (v) =>
                  _update((curr) => curr.copyWith(technicianName: v ?? '')),
              onAddOption: () => _promptAdd('Technician', opts.addTech),
              addTooltip: 'Add technician',
            ),

            SelectionField<String>(
              label: 'Generator Make',
              value: m.generatorMake.isEmpty ? null : m.generatorMake,
              options: opts.makes,
              enabled: !ready.isLoading,
              onChanged: (v) =>
                  _update((curr) => curr.copyWith(generatorMake: v ?? '')),
              onAddOption: () => _promptAdd('Generator Make', opts.addMake),
              addTooltip: 'Add make',
            ),

            LabeledField(
              label: 'Generator Model',
              value: m.generatorModel,
              onChanged: (v) =>
                  _update((curr) => curr.copyWith(generatorModel: v)),
            ),

            // Serial + kW
            Row(
              children: [
                Expanded(
                  child: LabeledField(
                    label: 'Serial Number',
                    value: m.generatorSerial,
                    onChanged: (v) =>
                        _update((curr) => curr.copyWith(generatorSerial: v)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: LabeledField(
                    label: 'kW Rating',
                    value: m.generatorKw,
                    keyboardType: TextInputType.number,
                    onChanged: (v) =>
                        _update((curr) => curr.copyWith(generatorKw: v)),
                  ),
                ),
              ],
            ),

            LabeledField(
              label: 'Engine Hours',
              value: m.engineHours,
              keyboardType: TextInputType.number,
              onChanged: (v) =>
                  _update((curr) => curr.copyWith(engineHours: v)),
            ),

            SelectionField<String>(
              label: 'Voltage Rating',
              value: m.voltageRating.isEmpty ? null : m.voltageRating,
              options: opts.voltages,
              enabled: !ready.isLoading,
              onChanged: (v) =>
                  _update((curr) => curr.copyWith(voltageRating: v ?? '')),
              onAddOption: () =>
                  _promptAdd('Voltage Rating', opts.addVoltage),
              addTooltip: 'Add voltage',
            ),

            // Fuel type
            SelectionField<String>(
              label: 'Fuel Type',
              value: m.fuelType.isEmpty ? null : m.fuelType,
              options: const ['Diesel', 'Gasoline', 'NaturalGas', 'None'],
              labelOf: (v) => v == 'NaturalGas' ? 'Natural Gas' : v,
              onChanged: (v) =>
                  _update((curr) => curr.copyWith(fuelType: v ?? '')),
            ),
          ],
        ),
      ),
    );
  }
}
