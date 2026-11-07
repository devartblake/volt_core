import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../inspections/infra/models/inspection.dart';
import '../../../maintenance/infra/models/maintenance_record.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../../core/theme/status_colors.dart';
import '../widgets/task_form/task_form_sections.dart';
import '../widgets/task_form/task_selection_cards.dart';

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
            const ScheduleTaskHeader(),
            const SizedBox(height: 32),

            // Step 1: Task Type Selection
            const TaskFormSectionTitle('1. Select Task Type'),
            const SizedBox(height: 16),
            _buildTaskTypeSelection(theme, colorScheme),
            const SizedBox(height: 32),

            // Step 2: Job Mode Selection (only if task type selected)
            if (_selectedType != null) ...[
              const TaskFormSectionTitle('2. Choose Job'),
              const SizedBox(height: 16),
              _buildJobModeSelection(theme, colorScheme),
              const SizedBox(height: 32),
            ],

            // Step 3: Job Selection or Creation (only if mode selected)
            if (_selectedType != null && _selectedMode != null) ...[
              if (_selectedMode == JobMode.existing)
                _buildExistingJobSelection(theme, colorScheme)
              else
                _buildNewJobAction(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTaskTypeSelection(ThemeData theme, ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: TaskTypeCard(
            icon: Icons.fact_check_outlined,
            title: 'Inspection',
            description: 'Generator compliance inspection',
            isSelected: _selectedType == TaskType.inspection,
            color: Theme.of(context).colorScheme.primary,
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
          child: TaskTypeCard(
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
          child: JobModeCard(
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
          child: JobModeCard(
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
        const TaskFormSectionTitle('3. Select Existing Job'),
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
                ? IconButton(tooltip: 'Clear', 
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
          ExistingInspectionResults(
            query: _searchQuery,
            onSelect: _scheduleExistingInspection,
          )
        else
          ExistingMaintenanceResults(
            query: _searchQuery,
            onSelect: _scheduleExistingMaintenance,
          ),
      ],
    );
  }

  Widget _buildNewJobAction() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TaskFormSectionTitle('3. Create New Job'),
        const SizedBox(height: 16),
        NewJobActionCard(
          isInspection: _selectedType == TaskType.inspection,
          onTap: _createNewJob,
        ),
      ],
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
