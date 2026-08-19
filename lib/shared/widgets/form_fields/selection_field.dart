import 'package:flutter/material.dart';

/// A labelled dropdown for choosing one value from a fixed list.
///
/// Handles the two cases the forms kept re-implementing: a value that is no
/// longer in the option list (shown rather than silently reset to null), and an
/// optional "Add…" affordance for user-managed option lists.
///
/// ```dart
/// SelectionField<String>(
///   label: 'Site grade',
///   value: model.siteGrade,
///   options: grades,
///   onChanged: (v) => update(siteGrade: v),
///   onAddOption: () => promptAddGrade(),
/// )
/// ```
class SelectionField<T> extends StatelessWidget {
  const SelectionField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.labelOf,
    this.hint,
    this.required = false,
    this.enabled = true,
    this.prefixIcon,
    this.onAddOption,
    this.addTooltip = 'Add option',
  });

  final String label;
  final T? value;
  final List<T> options;
  final ValueChanged<T?>? onChanged;

  /// How to render each option; defaults to `toString()`.
  final String Function(T value)? labelOf;

  final String? hint;
  final bool required;
  final bool enabled;
  final IconData? prefixIcon;

  /// When set, shows a trailing button for adding a new option.
  final VoidCallback? onAddOption;
  final String addTooltip;

  String _label(T v) => labelOf?.call(v) ?? v.toString();

  @override
  Widget build(BuildContext context) {
    // A stored value missing from the option list would make DropdownButton
    // throw, so surface it as a selectable entry instead of dropping the data.
    final items = <T>[
      ...options,
      if (value != null && !options.contains(value)) value as T,
    ];

    final field = DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      onChanged: enabled ? onChanged : null,
      validator: required
          ? (v) => v == null ? '$label is required' : null
          : null,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        prefixIcon: prefixIcon == null ? null : Icon(prefixIcon),
      ),
      items: [
        for (final option in items)
          DropdownMenuItem<T>(
            value: option,
            child: Text(_label(option), overflow: TextOverflow.ellipsis),
          ),
      ],
    );

    if (onAddOption == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: field,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: field),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: enabled ? onAddOption : null,
            icon: const Icon(Icons.add),
            tooltip: addTooltip,
          ),
        ],
      ),
    );
  }
}
