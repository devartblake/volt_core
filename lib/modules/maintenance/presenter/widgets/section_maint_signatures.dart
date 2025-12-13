import 'package:flutter/material.dart';

import '../../infra/models/maintenance_record.dart';

/// Signatures + Service Status section for the maintenance form.
///
/// Binds directly to [MaintenanceRecord] signature fields and the
/// completion/follow-up flags.
class SectionMaintSignatures extends StatelessWidget {
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
            Text(
              'Signatures & Service Status',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Capture technician and customer acknowledgement, and mark the job '
                  'as completed or requiring follow-up.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Technician signature
            Text(
              'Technician Signature',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _TextFieldRow(
              label: 'Technician name',
              initialValue: model.technicianSignatureName,
              readOnly: readOnly,
              onChanged: (value) {
                model.technicianSignatureName = value.trim();
                onChanged(model);
              },
            ),
            const SizedBox(height: 8),
            _DatePickerRow(
              label: 'Technician signed on',
              current: model.technicianSignatureDate,
              readOnly: readOnly,
              onChanged: (date) {
                model.technicianSignatureDate = date;
                onChanged(model);
              },
            ),

            const SizedBox(height: 16),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 16),

            // Customer signature
            Text(
              'Customer / Authorized Representative',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _TextFieldRow(
              label: 'Customer name',
              initialValue: model.customerSignatureName,
              readOnly: readOnly,
              onChanged: (value) {
                model.customerSignatureName = value.trim();
                onChanged(model);
              },
            ),
            const SizedBox(height: 8),
            _DatePickerRow(
              label: 'Customer signed on',
              current: model.customerSignatureDate,
              readOnly: readOnly,
              onChanged: (date) {
                model.customerSignatureDate = date;
                onChanged(model);
              },
            ),

            const SizedBox(height: 16),
            Divider(color: colorScheme.outlineVariant),
            const SizedBox(height: 16),

            // Service status / flags
            Text(
              'Service Status',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),

            SwitchListTile(
              title: const Text('Job completed'),
              subtitle: const Text(
                'Mark as completed when all work for this visit has been finished.',
              ),
              value: model.completed,
              onChanged: readOnly
                  ? null
                  : (val) {
                model.completed = val;
                // If completed and follow-up was previously null, default to false
                model.requiresFollowUp = model.requiresFollowUp;
                onChanged(model);
              },
            ),
            const SizedBox(height: 4),
            SwitchListTile(
              title: const Text('Requires follow-up'),
              subtitle: const Text(
                'Enable if an additional visit or corrective action is needed.',
              ),
              value: model.requiresFollowUp,
              onChanged: readOnly
                  ? null
                  : (val) {
                model.requiresFollowUp = val;
                onChanged(model);
              },
            ),

            if (model.requiresFollowUp) ...[
              const SizedBox(height: 8),
              _TextAreaRow(
                label: 'Follow-up notes',
                hintText: 'Describe what is required on the follow-up visit',
                initialValue: model.followUpNotes ?? '',
                readOnly: readOnly,
                onChanged: (value) {
                  final trimmed = value.trim();
                  model.followUpNotes =
                  trimmed.isEmpty ? null : trimmed; // keep nullable
                  onChanged(model);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TextFieldRow extends StatelessWidget {
  final String label;
  final String initialValue;
  final bool readOnly;
  final ValueChanged<String> onChanged;

  const _TextFieldRow({
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: initialValue,
          readOnly: readOnly,
          decoration: const InputDecoration(
            hintText: 'Enter name',
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _TextAreaRow extends StatelessWidget {
  final String label;
  final String initialValue;
  final String? hintText;
  final bool readOnly;
  final ValueChanged<String> onChanged;

  const _TextAreaRow({
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.hintText,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: initialValue,
          readOnly: readOnly,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: hintText,
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _DatePickerRow extends StatelessWidget {
  final String label;
  final DateTime? current;
  final bool readOnly;
  final ValueChanged<DateTime?> onChanged;

  const _DatePickerRow({
    required this.label,
    required this.current,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final text = current == null
        ? 'Tap to select date'
        : '${current!.year.toString().padLeft(4, '0')}-'
        '${current!.month.toString().padLeft(2, '0')}-'
        '${current!.day.toString().padLeft(2, '0')}';

    return InkWell(
      onTap: readOnly
          ? null
          : () async {
        final now = DateTime.now();
        final initial = current ?? now;
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime(now.year - 5),
          lastDate: DateTime(now.year + 5),
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: current == null
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.onSurface,
                ),
              ),
            ),
            if (!readOnly)
              Icon(
                Icons.edit_calendar_outlined,
                size: 18,
                color: colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}
