import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../providers/equipment_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../materials/presenter/materials_section_card.dart'
    show showGeneratorPartsProfile;
import '../../domain/entities/equipment_entity.dart' show AssetType;
import 'equipment_labels.dart';
import 'equipment_result_card.dart';

/// Right-hand pane of the tablet layout: the selected asset's summary and the
/// actions that otherwise take a tap on the card.
class EquipmentDetailPane extends StatelessWidget {
  const EquipmentDetailPane({
    super.key,
    required this.equipment,
    required this.onOpened,
    this.onEditAssignment,
  });

  final Equipment equipment;
  final VoidCallback onOpened;
  final VoidCallback? onEditAssignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final e = equipment;

    return SingleChildScrollView(
      // Bottom room so the actions can scroll clear of the page FAB.
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xl,
        AppSpacing.xl,
        96,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EquipmentStatusBadge(status: e.status),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      equipmentAssetTypeLabel(e.assetType),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              EquipmentStatusChip(status: e.status),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _Field(label: 'Make / model', value: '${e.make} ${e.model}'),
          _Field(label: 'Serial', value: e.serialNumber),
          _Field(label: 'Voltage', value: e.voltage),
          _Field(label: 'Location', value: e.location),
          if (e.siteCode.isNotEmpty) _Field(label: 'Site', value: e.siteCode),
          _Field(label: 'Status', value: equipmentStatusLabel(e.status)),
          if (e.lastInspection != null)
            _Field(
              label: 'Last inspection',
              value: equipmentRelativeDate(e.lastInspection!),
            ),
          if (e.inspectionCount > 0)
            _Field(
              label: 'History',
              value:
                  '${e.inspectionCount} ${e.inspectionCount == 1 ? 'inspection' : 'inspections'}',
            ),
          if (!e.hasInspectionLink)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text(
                'Registered asset — inspection not yet recorded',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              if (e.hasInspectionLink)
                FilledButton.icon(
                  onPressed: () {
                    onOpened();
                    context.push('/nameplate/${e.id}');
                  },
                  icon: const Icon(Icons.assignment_outlined),
                  label: const Text('Open inspection'),
                ),
              if (e.inspectionCount > 0)
                OutlinedButton.icon(
                  onPressed: () {
                    onOpened();
                    context.push('/equipment/history/${e.id}');
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('Open full history'),
                ),
              if (e.assetType == AssetType.generator)
                OutlinedButton.icon(
                  onPressed: () => showGeneratorPartsProfile(
                    context,
                    make: e.make,
                    model: e.model,
                    serial: e.serialNumber,
                  ),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Parts profile'),
                ),
              if (onEditAssignment != null)
                OutlinedButton.icon(
                  onPressed: onEditAssignment,
                  icon: const Icon(Icons.edit_location_alt_outlined),
                  label: const Text('Edit site assignment'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shown on the right until an asset is selected.
class EquipmentDetailPlaceholder extends StatelessWidget {
  const EquipmentDetailPlaceholder({super.key});

  @override
  Widget build(BuildContext context) => const EmptyState(
        icon: Icons.touch_app_outlined,
        title: 'Select an asset',
        message: 'Pick a result to see its details and actions here.',
      );
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value.isEmpty ? '—' : value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
