import 'package:flutter/material.dart';
import '../../domain/entities/inspection_entity.dart';

class InspectionCard extends StatelessWidget {
  final InspectionEntity inspection;
  final VoidCallback? onTap;

  const InspectionCard({
    super.key,
    required this.inspection,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateStr =
        inspection.serviceDate.toIso8601String().split('T').first;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getGradeColor(inspection.siteGrade, theme)
                      .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.settings_input_antenna,
                  color: _getGradeColor(inspection.siteGrade, theme),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inspection.address.isEmpty
                          ? '(No address)'
                          : inspection.address,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _InfoChip(
                          icon: Icons.calendar_today,
                          label: dateStr,
                        ),
                        if (inspection.siteCode.isNotEmpty)
                          _InfoChip(
                            icon: Icons.location_on_outlined,
                            label: inspection.siteCode,
                          ),
                        if (inspection.siteGrade.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color:
                              _getGradeColor(inspection.siteGrade, theme)
                                  .withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              inspection.siteGrade,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: _getGradeColor(
                                    inspection.siteGrade, theme),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getGradeColor(String grade, ThemeData theme) {
    switch (grade.toLowerCase()) {
      case 'green':
        return Colors.green;
      case 'amber':
        return Colors.orange;
      case 'red':
        return Colors.red;
      default:
        return theme.colorScheme.primary;
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
