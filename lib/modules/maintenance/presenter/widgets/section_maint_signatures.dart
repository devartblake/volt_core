import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';
import '../../../schedule/infra/models/schedule_task.dart';
import '../../../schedule/presenter/pages/schedule_task_page.dart';
import '../../../schedule/presenter/widgets/dialogs/schedule_dialog.dart';
import '../../presenter/widgets/utils/form_fields.dart';
import '../../../../core/services/storage/file_storage_service.dart';
import '../../infra/models/maintenance_record.dart';

/// Modern signatures section with digital signature capture
///
/// Features:
/// - Digital signature pads for technician and customer
/// - Visual feedback (green borders, checkmarks) when saved
/// - Loading indicators during save operations
/// - Maintains existing completion/follow-up functionality
/// - Helper functions to avoid breaking changes
class SectionMaintSignatures extends StatefulWidget {
  final MaintenanceRecord model;
  final ValueChanged<MaintenanceRecord> onChanged;
  final bool readOnly;

  const SectionMaintSignatures({
    super.key,
    required this.model,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  State<SectionMaintSignatures> createState() => _SectionMaintSignaturesState();
}

class _SectionMaintSignaturesState extends State<SectionMaintSignatures> {
  late final SignatureController _technicianController;
  late final SignatureController _customerController;

  bool _technicianSignatureSaved = false;
  bool _customerSignatureSaved = false;
  bool _isSavingTechnician = false;
  bool _isSavingCustomer = false;

  @override
  void initState() {
    super.initState();

    _technicianController = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    _customerController = SignatureController(
      penStrokeWidth: 2,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );

    // Load existing signatures if available
    _loadExistingSignatures();
  }

  @override
  void dispose() {
    _technicianController.dispose();
    _customerController.dispose();
    super.dispose();
  }

  /// Helper: Update model and notify parent
  void _updateModel(void Function() mutation) {
    mutation();
    widget.onChanged(widget.model);
  }

  /// Helper: Load existing signatures when editing a record
  Future<void> _loadExistingSignatures() async {
    if (widget.model.id.isEmpty) return;

    try {
      // Load technician signature if path exists
      if (_hasValidPath(widget.model.technicianSignaturePath)) {
        await _loadSignatureImage(
          widget.model.id,
          'technician',
          _technicianController,
              () => setState(() => _technicianSignatureSaved = true),
        );
      }

      // Load customer signature if path exists
      if (_hasValidPath(widget.model.customerSignaturePath)) {
        await _loadSignatureImage(
          widget.model.id,
          'customer',
          _customerController,
              () => setState(() => _customerSignatureSaved = true),
        );
      }
    } catch (e) {
      debugPrint('Error loading existing signatures: $e');
    }
  }

  /// Helper: Check if signature path is valid
  bool _hasValidPath(String? path) {
    return path != null && path.isNotEmpty;
  }

  /// Helper: Load signature image from storage
  Future<void> _loadSignatureImage(
      String recordId,
      String signatureType,
      SignatureController controller,
      VoidCallback onSuccess,
      ) async {
    final file = await FileStorageService.instance
        .getMaintenanceSignature(recordId, signatureType);

    if (file != null && await file.exists()) {
      final bytes = await file.readAsBytes();
      // Note: We can't reimport the signature drawing, but we can show it was saved
      onSuccess();
    }
  }

  /// Helper: Pick date for signature
  Future<void> _pickDate({
    required BuildContext context,
    required DateTime? current,
    required ValueChanged<DateTime?> onSelected,
  }) async {
    if (widget.readOnly) return;

    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
    );

    if (result != null) {
      onSelected(result);
    }
  }

  /// Helper: Format date for display
  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  /// Save technician signature to storage
  Future<void> _saveTechnicianSignature() async {
    if (_technicianController.isEmpty) {
      _showSnackBar('Please draw a signature first', isError: true);
      return;
    }

    setState(() => _isSavingTechnician = true);

    try {
      final recordId = widget.model.id.isEmpty
          ? 'temp_${DateTime.now().millisecondsSinceEpoch}'
          : widget.model.id;

      final signatureBytes = await _technicianController.toPngBytes();
      if (signatureBytes == null) {
        throw Exception('Failed to export signature');
      }

      // Save to file storage
      final path = await FileStorageService.instance.saveMaintenanceSignature(
        jobId: recordId,
        signatureBytes: signatureBytes,
        signatureType: 'technician',
      );

      // Update model
      _updateModel(() {
        widget.model.technicianSignaturePath = path;
        widget.model.technicianSignatureBytes = signatureBytes;
      });

      setState(() {
        _technicianSignatureSaved = true;
        _isSavingTechnician = false;
      });

      _showSnackBar('Technician signature saved');
    } catch (e) {
      setState(() => _isSavingTechnician = false);
      _showSnackBar('Failed to save signature: $e', isError: true);
    }
  }

  /// Save customer signature to storage
  Future<void> _saveCustomerSignature() async {
    if (_customerController.isEmpty) {
      _showSnackBar('Please draw a signature first', isError: true);
      return;
    }

    setState(() => _isSavingCustomer = true);

    try {
      final recordId = widget.model.id.isEmpty
          ? 'temp_${DateTime.now().millisecondsSinceEpoch}'
          : widget.model.id;

      final signatureBytes = await _customerController.toPngBytes();
      if (signatureBytes == null) {
        throw Exception('Failed to export signature');
      }

      // Save to file storage
      final path = await FileStorageService.instance.saveMaintenanceSignature(
        jobId: recordId,
        signatureBytes: signatureBytes,
        signatureType: 'customer',
      );

      // Update model
      _updateModel(() {
        widget.model.customerSignaturePath = path;
        widget.model.customerSignatureBytes = signatureBytes;
      });

      setState(() {
        _customerSignatureSaved = true;
        _isSavingCustomer = false;
      });

      _showSnackBar('Customer signature saved');
    } catch (e) {
      setState(() => _isSavingCustomer = false);
      _showSnackBar('Failed to save signature: $e', isError: true);
    }
  }

  /// Helper: Show snackbar message
  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : null,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  /// Schedule maintenance
  Future<void> _handleSchedule() async {
    final scheduled = await showScheduleDialog(
      context: context,
      taskType: TaskType.maintenance,
      siteCode: widget.model.siteCode,
      address: widget.model.address,
      maintenanceId: widget.model.id,
    );

    if (scheduled == true && mounted) {
      _showSnackBar('Maintenance scheduled successfully');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.draw_outlined,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Signatures & Service Status',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Capture digital signatures and mark service completion status.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Technician signature section
            _SignatureCard(
              title: 'Technician Signature',
              icon: Icons.engineering_outlined,
              iconColor: colorScheme.primary,
              borderColor: _technicianSignatureSaved
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
              isSaved: _technicianSignatureSaved,
              isSaving: _isSavingTechnician,
              readOnly: widget.readOnly,
              nameValue: widget.model.technicianSignatureName,
              dateValue: widget.model.technicianSignatureDate,
              signatureController: _technicianController,
              onNameChanged: (value) {
                _updateModel(() {
                  widget.model.technicianSignatureName = value.trim();
                });
              },
              onDateChanged: (date) {
                _updateModel(() {
                  widget.model.technicianSignatureDate = date;
                });
              },
              onDateTap: () => _pickDate(
                context: context,
                current: widget.model.technicianSignatureDate,
                onSelected: (date) {
                  _updateModel(() {
                    widget.model.technicianSignatureDate = date;
                  });
                },
              ),
              onClear: () {
                _technicianController.clear();
                setState(() => _technicianSignatureSaved = false);
              },
              onSave: _saveTechnicianSignature,
              formatDate: _formatDate,
            ),

            const SizedBox(height: 16),

            // Customer signature section
            _SignatureCard(
              title: 'Customer / Site Representative',
              icon: Icons.business_outlined,
              iconColor: colorScheme.secondary,
              borderColor: _customerSignatureSaved
                  ? colorScheme.secondary
                  : colorScheme.outlineVariant,
              isSaved: _customerSignatureSaved,
              isSaving: _isSavingCustomer,
              readOnly: widget.readOnly,
              nameValue: widget.model.customerSignatureName,
              dateValue: widget.model.customerSignatureDate,
              signatureController: _customerController,
              savedColor: colorScheme.secondaryContainer,
              onNameChanged: (value) {
                _updateModel(() {
                  widget.model.customerSignatureName = value.trim();
                });
              },
              onDateChanged: (date) {
                _updateModel(() {
                  widget.model.customerSignatureDate = date;
                });
              },
              onDateTap: () => _pickDate(
                context: context,
                current: widget.model.customerSignatureDate,
                onSelected: (date) {
                  _updateModel(() {
                    widget.model.customerSignatureDate = date;
                  });
                },
              ),
              onClear: () {
                _customerController.clear();
                setState(() => _customerSignatureSaved = false);
              },
              onSave: _saveCustomerSignature,
              formatDate: _formatDate,
            ),

            const SizedBox(height: 20),
            FormDivider(color: colorScheme.outlineVariant),
            const SizedBox(height: 20),

            // Service status section
            Text(
              'Service Status',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),

            _ServiceStatusCard(
              model: widget.model,
              readOnly: widget.readOnly,
              onChanged: (model) => widget.onChanged(model),
            ),

            const SizedBox(height: 16),

            // Info banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.45),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Save each signature before completing the form. Signatures will be embedded in the PDF export.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // ⭐ NEW: Schedule button
            if (!widget.readOnly) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event_available),
                  label: const Text('Schedule This Maintenance'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _handleSchedule,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Modern signature card widget with signature pad
class _SignatureCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Color borderColor;
  final bool isSaved;
  final bool isSaving;
  final bool readOnly;
  final String nameValue;
  final DateTime? dateValue;
  final SignatureController signatureController;
  final Color? savedColor;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<DateTime?> onDateChanged;
  final VoidCallback onDateTap;
  final VoidCallback onClear;
  final VoidCallback onSave;
  final String Function(DateTime?) formatDate;

  const _SignatureCard({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.borderColor,
    required this.isSaved,
    required this.isSaving,
    required this.readOnly,
    required this.nameValue,
    required this.dateValue,
    required this.signatureController,
    required this.onNameChanged,
    required this.onDateChanged,
    required this.onDateTap,
    required this.onClear,
    required this.onSave,
    required this.formatDate,
    this.savedColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final effectiveSavedColor = savedColor ?? colorScheme.primaryContainer;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: borderColor,
          width: isSaved ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and status badge
          Row(
            children: [
              Icon(icon, size: 20, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: iconColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isSaved)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: effectiveSavedColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 14,
                        color: colorScheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Saved',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Name field
          TextFormField(
            initialValue: nameValue,
            readOnly: readOnly,
            decoration: InputDecoration(
              labelText: 'Name',
              hintText: 'Enter full name',
              prefixIcon: const Icon(Icons.person_outline, size: 20),
              filled: true,
            ),
            onChanged: onNameChanged,
          ),
          const SizedBox(height: 12),

          // Date field
          InkWell(
            onTap: readOnly ? null : onDateTap,
            borderRadius: BorderRadius.circular(12),
            child: IgnorePointer(
              child: TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Date Signed',
                  hintText: 'Tap to select date',
                  prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
                  suffixIcon: readOnly
                      ? null
                      : const Icon(Icons.edit_calendar_outlined, size: 20),
                  filled: true,
                ),
                controller: TextEditingController(
                  text: formatDate(dateValue),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Signature pad header
          Row(
            children: [
              Text(
                'Draw Signature',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (!readOnly)
                TextButton.icon(
                  onPressed: onClear,
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Signature pad
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Signature(
                controller: signatureController,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Save signature button
          if (!readOnly)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isSaving ? null : onSave,
                icon: isSaving
                    ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : Icon(isSaved ? Icons.check_circle : Icons.save),
                label: Text(
                  isSaving
                      ? 'Saving...'
                      : isSaved
                      ? 'Signature Saved'
                      : 'Save Signature',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: isSaved ? iconColor : null,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Service status card for completion and follow-up flags
class _ServiceStatusCard extends StatelessWidget {
  final MaintenanceRecord model;
  final bool readOnly;
  final ValueChanged<MaintenanceRecord> onChanged;

  const _ServiceStatusCard({
    required this.model,
    required this.readOnly,
    required this.onChanged,
  });

  void _updateModel(void Function() mutation) {
    mutation();
    onChanged(model);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          SwitchListTile(
            value: model.completed,
            onChanged: readOnly
                ? null
                : (val) {
              _updateModel(() {
                model.completed = val;
              });
            },
            title: Row(
              children: [
                Icon(
                  Icons.task_alt_outlined,
                  size: 20,
                  color: model.completed
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                const Text('Job Completed'),
              ],
            ),
            subtitle: const Text(
              'Mark when all work for this visit is finished',
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
          ),
          Divider(
            height: 1,
            color: colorScheme.outlineVariant,
          ),
          SwitchListTile(
            value: model.requiresFollowUp,
            onChanged: readOnly
                ? null
                : (val) {
              _updateModel(() {
                model.requiresFollowUp = val;
              });
            },
            title: Row(
              children: [
                Icon(
                  Icons.event_repeat_outlined,
                  size: 20,
                  color: model.requiresFollowUp
                      ? colorScheme.tertiary
                      : colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                const Text('Requires Follow-up'),
              ],
            ),
            subtitle: const Text(
              'Enable if additional visit or corrective action needed',
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
          ),
          if (model.requiresFollowUp) ...[
            Divider(
              height: 1,
              color: colorScheme.outlineVariant,
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextFormField(
                initialValue: model.followUpNotes ?? '',
                readOnly: readOnly,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Follow-up Notes',
                  hintText: 'Describe what is required on the follow-up visit',
                  filled: true,
                  prefixIcon: const Icon(Icons.notes_outlined),
                ),
                onChanged: (value) {
                  _updateModel(() {
                    final trimmed = value.trim();
                    model.followUpNotes = trimmed.isEmpty ? null : trimmed;
                  });
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}