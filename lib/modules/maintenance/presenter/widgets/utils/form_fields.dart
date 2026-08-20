import 'package:flutter/material.dart';
import '../../../../../shared/widgets/widgets.dart';

/// Shared UI helpers for maintenance form sections.
///
/// Use these components across section_maint_*.dart files to ensure
/// consistent spacing, typography, and readOnly handling.
class FormSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const FormSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!.trim(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class FormSubsectionTitle extends StatelessWidget {
  final String text;

  const FormSubsectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class FormTextFieldRow extends StatelessWidget {
  final String label;
  final String initialValue;
  final String? hintText;
  final bool readOnly;
  final int maxLines;
  final TextInputType? keyboardType;
  final ValueChanged<String> onChanged;

  const FormTextFieldRow({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.hintText,
    this.readOnly = false,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    // Delegates to the shared kit so maintenance and inspection fields share
    // one implementation; the wrapper stays because five section widgets are
    // built around this API.
    return LabeledField(
      label: label,
      value: initialValue,
      hint: hintText,
      readOnly: readOnly,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
    );
  }
}

class FormTextAreaRow extends StatelessWidget {
  final String label;
  final String initialValue;
  final String? hintText;
  final bool readOnly;
  final int maxLines;
  final ValueChanged<String> onChanged;

  const FormTextAreaRow({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onChanged,
    this.hintText,
    this.readOnly = false,
    this.maxLines = 3,
  });

  @override
  Widget build(BuildContext context) {
    return LabeledField(
      label: label,
      value: initialValue,
      hint: hintText,
      readOnly: readOnly,
      maxLines: maxLines,
      onChanged: onChanged,
    );
  }
}

class FormDropdownRow extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final bool readOnly;
  final ValueChanged<String?> onChanged;
  final String? hintText;

  const FormDropdownRow({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    this.readOnly = false,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    return SelectionField<String>(
      label: label,
      value: value,
      options: items,
      hint: hintText ?? 'Select',
      enabled: !readOnly,
      onChanged: onChanged,
    );
  }
}

class FormCheckboxRow extends StatelessWidget {
  final String label;
  final bool value;
  final bool readOnly;
  final ValueChanged<bool?> onChanged;

  const FormCheckboxRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CheckboxListTile(
      value: value,
      onChanged: readOnly ? null : onChanged,
      title: Text(label, style: theme.textTheme.bodyMedium),
      dense: true,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}

class FormDivider extends StatelessWidget {
  const FormDivider({
    super.key,
    required Color color
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Divider(color: colorScheme.outlineVariant),
    );
  }
}
