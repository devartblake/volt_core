import 'package:flutter/material.dart';

/// A labelled text input with the app's standard spacing and validation copy.
///
/// Wraps [TextFormField] so screens don't each re-declare border radius,
/// density, and helper-text styling. Field decoration itself still comes from
/// `WidgetsTheme.inputDecoration`, so this stays theme-driven.
///
/// ```dart
/// LabeledField(
///   label: 'Site code',
///   value: model.siteCode,
///   onChanged: (v) => update(siteCode: v),
///   required: true,
/// )
/// ```
class LabeledField extends StatelessWidget {
  const LabeledField({
    super.key,
    required this.label,
    this.value,
    this.controller,
    this.onChanged,
    this.hint,
    this.helper,
    this.prefixIcon,
    this.suffix,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.required = false,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
    this.validator,
    this.textCapitalization = TextCapitalization.none,
    this.autofocus = false,
  }) : assert(
          value == null || controller == null,
          'Provide either value or controller, not both.',
        );

  final String label;

  /// Initial text when running uncontrolled. Mutually exclusive with
  /// [controller].
  final String? value;
  final TextEditingController? controller;

  final ValueChanged<String>? onChanged;
  final String? hint;
  final String? helper;
  final IconData? prefixIcon;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final int maxLines;
  final int? minLines;

  /// Marks the field required: adds an asterisk and a default validator.
  final bool required;

  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;
  final TextCapitalization textCapitalization;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        initialValue: controller == null ? value : null,
        controller: controller,
        onChanged: onChanged,
        enabled: enabled,
        readOnly: readOnly,
        onTap: onTap,
        autofocus: autofocus,
        keyboardType: keyboardType,
        maxLines: maxLines,
        minLines: minLines,
        textCapitalization: textCapitalization,
        validator: validator ??
            (required
                ? (v) => (v == null || v.trim().isEmpty)
                    ? '$label is required'
                    : null
                : null),
        decoration: InputDecoration(
          labelText: required ? '$label *' : label,
          hintText: hint,
          helperText: helper,
          helperMaxLines: 2,
          prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
          suffixIcon: suffix,
          labelStyle: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}
