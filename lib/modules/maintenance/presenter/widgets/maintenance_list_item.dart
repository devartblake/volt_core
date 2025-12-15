import 'package:flutter/material.dart';
import '../../domain/entities/maintenance_job_entity.dart';

class MaintenanceListItem extends StatelessWidget {
  final MaintenanceJobEntity job;
  final VoidCallback? onTap;
  final Future<void> Function()? onExportPdf;
  final Future<void> Function()? onDelete;
  final bool showCompleted;

  const MaintenanceListItem({
    super.key,
    required this.job,
    this.onTap,
    this.onExportPdf,
    this.onDelete,
    this.showCompleted = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final title = job.siteCode.isNotEmpty ? job.siteCode : 'Maintenance ${job.id}';
    final subtitle = _subtitleFor(job);
    final isCompleted = job.isCompleted;

    // FIX: Moved variable declaration outside of the Widget tree
    final meta = _metaChips(context, job);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _LeadingIcon(
                    completed: isCompleted,
                    showCompleted: showCompleted,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (showCompleted && isCompleted) ...[
                          const SizedBox(height: 6),
                          _CompletedBadge(),
                        ],
                      ],
                    ),
                  ),
                  if (onExportPdf != null) ...[
                    IconButton.filledTonal(
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      tooltip: 'Export PDF',
                      onPressed: () async {
                        await onExportPdf?.call();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('PDF export started'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (onDelete != null)
                    IconButton.filledTonal(
                      icon: const Icon(Icons.delete_outline),
                      tooltip: 'Delete',
                      style: IconButton.styleFrom(
                        foregroundColor: colorScheme.error,
                      ),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete maintenance record?'),
                            content: Text(
                              job.siteCode.isEmpty
                                  ? 'Are you sure you want to delete this maintenance record?'
                                  : 'Are you sure you want to delete the maintenance record for "${job.siteCode}"?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                style: FilledButton.styleFrom(
                                  backgroundColor: colorScheme.error,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );

                        if (confirm != true || !context.mounted) return;
                        await onDelete?.call();

                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Maintenance record deleted'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                ],
              ),
              // Use the pre-calculated 'meta' list here
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: meta,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _subtitleFor(MaintenanceJobEntity m) {
    final parts = <String>[];
    if (m.technicianName.isNotEmpty) {
      parts.add('Tech: ${m.technicianName}');
    }
    return parts.join(' • ');
  }

  List<Widget> _metaChips(BuildContext context, MaintenanceJobEntity m) {
    final chips = <Widget>[];
    if (m.address.isNotEmpty) {
      chips.add(_InfoChip(icon: Icons.place_outlined, label: m.address));
    }
    if (m.requiresFollowUp) {
      chips.add(
        _InfoChip(
          icon: Icons.priority_high,
          label: 'Follow-up required',
          emphasized: true,
        ),
      );
    }
    return chips;
  }
}

class _LeadingIcon extends StatelessWidget {
  final bool completed;
  final bool showCompleted;

  const _LeadingIcon({
    required this.completed,
    required this.showCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final bg = completed && showCompleted
        ? colorScheme.primaryContainer
        : colorScheme.primaryContainer;

    final icon = completed && showCompleted
        ? Icons.archive_outlined
        : Icons.build_circle_outlined;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        color: colorScheme.onPrimaryContainer,
        size: 24,
      ),
    );
  }
}

class _CompletedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withOpacity(0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Completed',
        style: theme.textTheme.labelSmall?.copyWith(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool emphasized;

  const _InfoChip({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bg = emphasized
        ? colorScheme.primaryContainer.withOpacity(0.5)
        : colorScheme.surfaceContainerHighest;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: emphasized ? FontWeight.w600 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
