import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/hive/hive_boxes.dart';
import '../../../inspections/infra/models/inspection.dart';
import '../../../maintenance/infra/models/maintenance_record.dart';
import '../../../maintenance/infra/datasources/hive_boxes_maintenance.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../core/theme/status_colors.dart';

/// Page for scheduling a new task (inspection or maintenance)
/// Allows selection between task type and new vs existing job
class ScheduleTaskPage extends ConsumerStatefulWidget {
  const ScheduleTaskPage({super.key});

  @override
  ConsumerState<ScheduleTaskPage> createState() => _ScheduleTaskPageState();
}

class _ScheduleTaskPageState extends ConsumerState<ScheduleTaskPage> {
  // Selection state
  TaskType? _selectedType;
  JobMode? _selectedMode;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AppPage(
      title: 'Schedule Task',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(theme),
            const SizedBox(height: 32),

            // Step 1: Task Type Selection
            _buildSectionTitle(theme, '1. Select Task Type'),
            const SizedBox(height: 16),
            _buildTaskTypeSelection(theme, colorScheme),
            const SizedBox(height: 32),

            // Step 2: Job Mode Selection (only if task type selected)
            if (_selectedType != null) ...[
              _buildSectionTitle(theme, '2. Choose Job'),
              const SizedBox(height: 16),
              _buildJobModeSelection(theme, colorScheme),
              const SizedBox(height: 32),
            ],

            // Step 3: Job Selection or Creation (only if mode selected)
            if (_selectedType != null && _selectedMode != null) ...[
              if (_selectedMode == JobMode.existing)
                _buildExistingJobSelection(theme, colorScheme)
              else
                _buildNewJobAction(theme, colorScheme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
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
              Icon(
                Icons.calendar_today,
                color: theme.colorScheme.primary,
                size: 32,
              ),
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
        ),
      ],
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildTaskTypeSelection(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: _TaskTypeCard(
            icon: Icons.fact_check_outlined,
            title: 'Inspection',
            description: 'Generator compliance inspection',
            isSelected: _selectedType == TaskType.inspection,
            color: Colors.blue,
            onTap: () {
              setState(() {
                _selectedType = TaskType.inspection;
                _selectedMode = null; // Reset mode when type changes
              });
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _TaskTypeCard(
            icon: Icons.build_circle_outlined,
            title: 'Maintenance',
            description: 'Repair or service job',
            isSelected: _selectedType == TaskType.maintenance,
            color: theme.status.warning,
            onTap: () {
              setState(() {
                _selectedType = TaskType.maintenance;
                _selectedMode = null; // Reset mode when type changes
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildJobModeSelection(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: _JobModeCard(
            icon: Icons.add_circle_outline,
            title: 'New Job',
            description: 'Create from scratch',
            isSelected: _selectedMode == JobMode.newJob,
            onTap: () {
              setState(() {
                _selectedMode = JobMode.newJob;
              });
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _JobModeCard(
            icon: Icons.history,
            title: 'Existing Job',
            description: 'Schedule previous work',
            isSelected: _selectedMode == JobMode.existing,
            onTap: () {
              setState(() {
                _selectedMode = JobMode.existing;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildExistingJobSelection(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(theme, '3. Select Existing Job'),
        const SizedBox(height: 16),

        // Search bar
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: _selectedType == TaskType.inspection
                ? 'Search inspections by site code or address...'
                : 'Search maintenance jobs by site or notes...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                });
              },
            )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
        ),
        const SizedBox(height: 16),

        // Results list
        if (_selectedType == TaskType.inspection)
          _buildInspectionsList(theme)
        else
          _buildMaintenanceList(theme),
      ],
    );
  }

  Widget _buildInspectionsList(ThemeData theme) {
    final inspections = HiveBoxes.inspections.values
        .where((ins) {
      if (_searchQuery.isEmpty) return true;
      return ins.siteCode.toLowerCase().contains(_searchQuery) ||
          ins.address.toLowerCase().contains(_searchQuery);
    })
        .toList()
      ..sort((a, b) => b.serviceDate.compareTo(a.serviceDate));

    if (inspections.isEmpty) {
      return _buildEmptyState(
        theme,
        'No inspections found',
        'Try adjusting your search or create a new inspection',
        Icons.search_off,
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
            child: _ExistingJobCard(
              title: inspection.address.isEmpty
                  ? inspection.siteCode
                  : inspection.address,
              subtitle: inspection.siteCode,
              date: inspection.serviceDate,
              grade: inspection.siteGrade,
              icon: Icons.fact_check_outlined,
              color: Colors.blue,
              onTap: () => _scheduleExistingInspection(inspection),
            ),
          );
        }),
        if (inspections.length > 10)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Showing first 10 results. Refine search to see more.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMaintenanceList(ThemeData theme) {
    final maintenanceJobs = MaintenanceBoxes.maintenance.values
        .where((job) {
      if (_searchQuery.isEmpty) return true;
      return job.siteCode.toLowerCase().contains(_searchQuery) ||
          job.address.toLowerCase().contains(_searchQuery) ||
          (job.generalNotes?.toLowerCase().contains(_searchQuery) ?? false);
    })
        .toList()
      ..sort((a, b) => (b.dateOfService ?? DateTime(2000)).compareTo(a.dateOfService ?? DateTime(2000)));

    if (maintenanceJobs.isEmpty) {
      return _buildEmptyState(
        theme,
        'No maintenance jobs found',
        'Try adjusting your search or create a new maintenance job',
        Icons.search_off,
      );
    }

    return Column(
      children: [
        Text(
          '${maintenanceJobs.length} job${maintenanceJobs.length == 1 ? '' : 's'} found',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        ...maintenanceJobs.take(10).map((job) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ExistingJobCard(
              title: job.address.isEmpty ? job.siteCode : job.address,
              subtitle: job.generalNotes?.isEmpty ?? true
                  ? job.siteCode
                  : job.generalNotes!,
              date: job.dateOfService ?? DateTime.now(),
              icon: Icons.build_circle_outlined,
              color: theme.status.warning,
              onTap: () => _scheduleExistingMaintenance(job),
            ),
          );
        }),
        if (maintenanceJobs.length > 10)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Showing first 10 results. Refine search to see more.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNewJobAction(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(theme, '3. Create New Job'),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: InkWell(
            onTap: _createNewJob,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: (_selectedType == TaskType.inspection
                          ? Colors.blue
                          : theme.status.warning)
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _selectedType == TaskType.inspection
                          ? Icons.fact_check_outlined
                          : Icons.build_circle_outlined,
                      color: _selectedType == TaskType.inspection
                          ? Colors.blue
                          : theme.status.warning,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create New ${_selectedType == TaskType.inspection ? 'Inspection' : 'Maintenance Job'}',
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
                  Icon(
                    Icons.arrow_forward_ios,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(
      ThemeData theme,
      String title,
      String message,
      IconData icon,
      ) {
    return Container(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Column(
          children: [
            Icon(
              icon,
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

  // Navigation methods
  void _createNewJob() {
    if (_selectedType == TaskType.inspection) {
      context.goNamed('inspection_new');
    } else {
      context.goNamed('maintenance_new');
    }
  }

  void _scheduleExistingInspection(Inspection inspection) {
    // Date picker and schedule entry creation will be added in a future iteration.
    // For now, show a dialog informing the user and allowing navigation to the form.
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule Inspection'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Schedule inspection for: ${inspection.address}'),
            const SizedBox(height: 16),
            const Text('Date picker will be added in next iteration'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // For now, navigate to inspection form
              context.goNamed('inspection_new');
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _scheduleExistingMaintenance(MaintenanceRecord job) {
    // Date picker and schedule entry creation will be added in a future iteration.
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule Maintenance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Schedule maintenance for: ${job.address}'),
            const SizedBox(height: 16),
            const Text('Date picker will be added in next iteration'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              // For now, navigate to maintenance form
              context.goNamed('maintenance_new');
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

// Enums
enum TaskType { inspection, maintenance }
enum JobMode { newJob, existing }

// Task Type Selection Card
class _TaskTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TaskTypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: isSelected ? 4 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? color : theme.colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.1)
                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: isSelected ? color : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSelected ? color : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(height: 12),
                Icon(
                  Icons.check_circle,
                  color: color,
                  size: 24,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Job Mode Selection Card
class _JobModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isSelected;
  final VoidCallback onTap;

  const _JobModeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: isSelected ? 4 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                icon,
                size: 40,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(height: 8),
                Icon(
                  Icons.check_circle,
                  color: colorScheme.primary,
                  size: 20,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// Existing Job Card
class _ExistingJobCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final DateTime date;
  final String? grade;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ExistingJobCard({
    required this.title,
    required this.subtitle,
    required this.date,
    this.grade,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatDate(date),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (grade != null && grade!.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.gradeColor(grade!)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: theme.gradeColor(grade!)
                                    .withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              grade!,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.gradeColor(grade!),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
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

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

}