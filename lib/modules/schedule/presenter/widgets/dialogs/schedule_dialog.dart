import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/entities/task_schedule_entity.dart';
import '../../../infra/repositories/schedule_repository_impl.dart';
import '../../pages/schedule_task_page.dart';
import '../../../../../core/theme/status_colors.dart';

/// Shows a dialog to schedule a task
/// Returns true if task was scheduled successfully
Future<bool?> showScheduleDialog({
  required BuildContext context,
  required TaskType taskType,
  required String siteCode,
  required String address,
  String? inspectionId,
  String? maintenanceId,
  String? siteGrade,
}) async {
  return await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => ScheduleTaskDialog(
      taskType: taskType,
      siteCode: siteCode,
      address: address,
      inspectionId: inspectionId,
      maintenanceId: maintenanceId,
      siteGrade: siteGrade,
    ),
  );
}

class ScheduleTaskDialog extends ConsumerStatefulWidget {
  final TaskType taskType;
  final String siteCode;
  final String address;
  final String? inspectionId;
  final String? maintenanceId;
  final String? siteGrade;

  const ScheduleTaskDialog({
    super.key,
    required this.taskType,
    required this.siteCode,
    required this.address,
    this.inspectionId,
    this.maintenanceId,
    this.siteGrade,
  });

  @override
  ConsumerState<ScheduleTaskDialog> createState() =>
      _ScheduleTaskDialogState();
}

class _ScheduleTaskDialogState extends ConsumerState<ScheduleTaskDialog> {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  final _notesController = TextEditingController();
  final _technicianController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _notesController.dispose();
    _technicianController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: widget.taskType == TaskType.inspection
                  ? Colors.blue
                  : Colors.orange,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: widget.taskType == TaskType.inspection
                  ? Colors.blue
                  : Colors.orange,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _handleSchedule() async {
    setState(() => _isSaving = true);

    try {
      final now = DateTime.now();
      final scheduledAt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );
      final task = TaskScheduleEntity(
        id: const Uuid().v4(),
        tenantId: '',
        title: widget.siteCode.isNotEmpty ? widget.siteCode : widget.address,
        scheduledAt: scheduledAt,
        scheduledDate: _selectedDate,
        status: 'scheduled',
        sourceType: widget.taskType == TaskType.inspection
            ? 'inspection'
            : 'maintenance',
        sourceId: widget.inspectionId ?? widget.maintenanceId,
        inspectionId: widget.inspectionId,
        siteCode: widget.siteCode,
        address: widget.address,
        siteGrade: widget.siteGrade ?? '',
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        assignedToUserId: _technicianController.text.trim().isEmpty
            ? null
            : _technicianController.text.trim(),
        createdAt: now,
        updatedAt: now,
      );

      // Saving through the repository keeps one write path: local Hive save,
      // cloud sync enqueue, and the reminder are all handled there.
      await ref.read(scheduleRepositoryProvider).saveTask(task);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Task scheduled for ${_formatDate(_selectedDate)} at ${_selectedTime.format(context)}',
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Error scheduling task: $e')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      setState(() => _isSaving = false);
    }
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taskColor = widget.taskType == TaskType.inspection
        ? Colors.blue
        : theme.status.warning;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: taskColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    widget.taskType == TaskType.inspection
                        ? Icons.fact_check
                        : Icons.build_circle,
                    color: taskColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Schedule ${widget.taskType == TaskType.inspection ? 'Inspection' : 'Maintenance'}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.address.isEmpty ? widget.siteCode : widget.address,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Date & Time Selection
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_formatDate(_selectedDate)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isSaving ? null : _selectDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time),
                    label: Text(_selectedTime.format(context)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _isSaving ? null : _selectTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Technician (optional)
            TextField(
              controller: _technicianController,
              decoration: InputDecoration(
                labelText: 'Assigned Technician (Optional)',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              enabled: !_isSaving,
            ),
            const SizedBox(height: 16),

            // Notes (optional)
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Notes (Optional)',
                prefixIcon: const Icon(Icons.notes),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              enabled: !_isSaving,
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving
                        ? null
                        : () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: _isSaving ? null : _handleSchedule,
                    icon: _isSaving
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.schedule),
                    label: Text(_isSaving ? 'Scheduling...' : 'Schedule'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: taskColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
