import 'package:flutter/material.dart';

import '../../../../../core/services/hive/hive_boxes.dart';
import '../../../../../core/theme/status_colors.dart';
import '../../../../inspections/infra/models/inspection.dart';
import '../../../../maintenance/infra/datasources/hive_boxes_maintenance.dart';
import '../../../../maintenance/infra/models/maintenance_record.dart';
import 'existing_job_card.dart';

/// Banner at the top of the "Schedule Task" page.
class ScheduleTaskHeader extends StatelessWidget {
  const ScheduleTaskHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, color: theme.colorScheme.primary, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Schedule a Task',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Create a new inspection or maintenance task, or schedule an existing job',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Numbered step title ("1. Select Task Type").
class TaskFormSectionTitle extends StatelessWidget {
  const TaskFormSectionTitle(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.primary,
      ),
    );
  }
}

/// "Create new inspection / maintenance job" card.
class NewJobActionCard extends StatelessWidget {
  const NewJobActionCard({
    super.key,
    required this.isInspection,
    required this.onTap,
  });

  final bool isInspection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final color = isInspection ? colorScheme.primary : theme.status.warning;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isInspection
                      ? Icons.fact_check_outlined
                      : Icons.build_circle_outlined,
                  color: color,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create New ${isInspection ? 'Inspection' : 'Maintenance Job'}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Start from scratch with a blank form',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreResultsHint extends StatelessWidget {
  const _MoreResultsHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'Showing first 10 results. Refine search to see more.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

/// Saved inspections matching [query] (lower-case), newest first.
class ExistingInspectionResults extends StatelessWidget {
  const ExistingInspectionResults({
    super.key,
    required this.query,
    required this.onSelect,
  });

  final String query;
  final ValueChanged<Inspection> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inspections = HiveBoxes.inspections.values.where((ins) {
      if (query.isEmpty) return true;
      return ins.siteCode.toLowerCase().contains(query) ||
          ins.address.toLowerCase().contains(query);
    }).toList()
      ..sort((a, b) => b.serviceDate.compareTo(a.serviceDate));

    if (inspections.isEmpty) {
      return const _EmptyResults(
        title: 'No inspections found',
        message: 'Try adjusting your search or create a new inspection',
      );
    }

    return Column(
      children: [
        Text(
          '${inspections.length} inspection${inspections.length == 1 ? '' : 's'} found',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ...inspections.take(10).map((inspection) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ExistingJobCard(
              title: inspection.address.isEmpty
                  ? inspection.siteCode
                  : inspection.address,
              subtitle: inspection.siteCode,
              date: inspection.serviceDate,
              grade: inspection.siteGrade,
              icon: Icons.fact_check_outlined,
              color: theme.colorScheme.primary,
              onTap: () => onSelect(inspection),
            ),
          );
        }),
        if (inspections.length > 10) const _MoreResultsHint(),
      ],
    );
  }
}

/// Saved maintenance jobs matching [query] (lower-case), newest first.
class ExistingMaintenanceResults extends StatelessWidget {
  const ExistingMaintenanceResults({
    super.key,
    required this.query,
    required this.onSelect,
  });

  final String query;
  final ValueChanged<MaintenanceRecord> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final jobs = MaintenanceBoxes.maintenance.values.where((job) {
      if (query.isEmpty) return true;
      return job.siteCode.toLowerCase().contains(query) ||
          job.address.toLowerCase().contains(query) ||
          (job.generalNotes?.toLowerCase().contains(query) ?? false);
    }).toList()
      ..sort((a, b) => (b.dateOfService ?? DateTime(2000))
          .compareTo(a.dateOfService ?? DateTime(2000)));

    if (jobs.isEmpty) {
      return const _EmptyResults(
        title: 'No maintenance jobs found',
        message: 'Try adjusting your search or create a new maintenance job',
      );
    }

    return Column(
      children: [
        Text(
          '${jobs.length} job${jobs.length == 1 ? '' : 's'} found',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ...jobs.take(10).map((job) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ExistingJobCard(
              title: job.address.isEmpty ? job.siteCode : job.address,
              subtitle: job.generalNotes?.isEmpty ?? true
                  ? job.siteCode
                  : job.generalNotes!,
              date: job.dateOfService ?? DateTime.now(),
              icon: Icons.build_circle_outlined,
              color: theme.status.warning,
              onTap: () => onSelect(job),
            ),
          );
        }),
        if (jobs.length > 10) const _MoreResultsHint(),
      ],
    );
  }
}
