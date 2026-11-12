import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../providers/equipment_providers.dart';
import '../../../../shared/widgets/widgets.dart';
import 'equipment_labels.dart';

/// One search result.
///
/// With no [onSelect] the card opens the inspection on tap (phone behaviour).
/// With [onSelect] (tablet two-pane) a tap selects the asset for the detail
/// pane instead, and [selected] highlights it.
class EquipmentResultCard extends StatelessWidget {
  const EquipmentResultCard({
    super.key,
    required this.equipment,
    this.onEditAssignment,
    this.onSelect,
    this.selected = false,
    this.onOpened,
  });

  final Equipment equipment;
  final VoidCallback? onEditAssignment;
  final VoidCallback? onSelect;
  final bool selected;

  /// Called when the card navigates away (so the page can remember the query).
  final VoidCallback? onOpened;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final twoPane = onSelect != null;

    VoidCallback? onTap;
    if (twoPane) {
      onTap = onSelect;
    } else if (equipment.hasInspectionLink) {
      onTap = () {
        onOpened?.call();
        context.push('/nameplate/${equipment.id}');
      };
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      elevation: 0,
      color: selected ? colorScheme.secondaryContainer : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EquipmentStatusBadge(status: equipment.status),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          equipment.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '${equipment.make} ${equipment.model}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          equipmentAssetTypeLabel(equipment.assetType),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      EquipmentStatusChip(status: equipment.status),
                      if (onEditAssignment != null)
                        IconButton(
                          tooltip: 'Edit site assignment',
                          onPressed: onEditAssignment,
                          icon: const Icon(Icons.edit_location_alt_outlined),
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: EquipmentDetailItem(
                      icon: Icons.numbers,
                      label: 'Serial',
                      value: equipment.serialNumber,
                    ),
                  ),
                  Expanded(
                    child: EquipmentDetailItem(
                      icon: Icons.electrical_services_outlined,
                      label: 'Voltage',
                      value: equipment.voltage,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              EquipmentDetailItem(
                icon: Icons.location_on_outlined,
                label: 'Location',
                value: equipment.location,
              ),
              if (equipment.siteCode.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                EquipmentDetailItem(
                  icon: Icons.location_city_outlined,
                  label: 'Site code',
                  value: equipment.siteCode,
                ),
              ],
              if (equipment.lastInspection != null) ...[
                const SizedBox(height: AppSpacing.md),
                EquipmentDetailItem(
                  icon: Icons.calendar_today_outlined,
                  label: 'Last Inspection',
                  value: equipmentRelativeDate(equipment.lastInspection!),
                ),
              ],
              if (equipment.inspectionCount > 0) ...[
                const SizedBox(height: AppSpacing.md),
                EquipmentDetailItem(
                  icon: Icons.history_outlined,
                  label: 'History',
                  value:
                      '${equipment.inspectionCount} ${equipment.inspectionCount == 1 ? 'inspection' : 'inspections'}',
                ),
                if (!twoPane) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        onOpened?.call();
                        context.push('/equipment/history/${equipment.id}');
                      },
                      icon: const Icon(Icons.history, size: 18),
                      label: const Text('View history'),
                    ),
                  ),
                ],
              ],
              if (!equipment.hasInspectionLink) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Registered asset — inspection not yet recorded',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Square status icon at the left of a card or the detail header.
class EquipmentStatusBadge extends StatelessWidget {
  const EquipmentStatusBadge({super.key, required this.status});

  final EquipmentStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = equipmentStatusColor(status, theme);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(equipmentStatusIcon(status), color: color, size: 24),
    );
  }
}

class EquipmentStatusChip extends StatelessWidget {
  const EquipmentStatusChip({super.key, required this.status});

  final EquipmentStatus status;

  @override
  Widget build(BuildContext context) => StatusChip.colored(
        label: equipmentStatusLabel(status),
        foreground: equipmentStatusColor(status, Theme.of(context)),
      );
}

/// Icon + "Label: value" row.
class EquipmentDetailItem extends StatelessWidget {
  const EquipmentDetailItem({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // One wrapping run of text, so a long label or a 1.3x font wraps instead
    // of overflowing the narrow half-width cells.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$label: ',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
