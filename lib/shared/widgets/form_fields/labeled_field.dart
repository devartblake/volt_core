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
class LabeledField extends StatefulWidget {
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
    this.suffixText,
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
    this.dense = false,
    this.filled,
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

  /// Inline unit shown after the value ("Gallons", "kW", "hours"). Rendered as
  /// text inside the field rather than as a trailing icon.
  final String? suffixText;
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

  /// Compact variant for fields nested inside an already-padded row (a
  /// checklist row, a dialog column). Drops the outer vertical padding and
  /// tightens the decoration so the field doesn't blow out the row height.
  final bool dense;

  /// Overrides the theme's `filled` for this field. Only set it where a
  /// surrounding surface makes the default read wrong.
  final bool? filled;

  @override
  State<LabeledField> createState() => _LabeledFieldState();
}

class _LabeledFieldState extends State<LabeledField> {
  /// Owned only when running uncontrolled (`value` rather than `controller`).
  TextEditingController? _owned;

  TextEditingController? get _controller => widget.controller ?? _owned;

  bool _syncQueued = false;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _owned = TextEditingController(text: widget.value ?? '');
    }
  }

  @override
  void didUpdateWidget(covariant LabeledField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final owned = _owned;
    if (owned == null) return;

    // Adopt a value the parent changed underneath us — a restored draft, a
    // cleared field, a date just picked. Guarding on `owned.text` is what
    // keeps typing intact: while the user types, `onChanged` has already told
    // the parent, so the value coming back equals what is in the field and
    // this does nothing, leaving the cursor alone.
    final incoming = widget.value ?? '';
    if (incoming != oldWidget.value && incoming != owned.text) {
      _queueOwnedValueSync();
    }
  }

  /// [TextFormField] listens to its controller and asks its enclosing [Form]
  /// to rebuild. Updating that controller from [didUpdateWidget] can therefore
  /// mark the Form dirty while it is itself building. Apply external values at
  /// the end of the frame instead (draft restores, picker results, clears).
  void _queueOwnedValueSync() {
    if (_syncQueued) return;
    _syncQueued = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncQueued = false;
      if (!mounted) return;

      final owned = _owned;
      if (owned == null) return;

      final incoming = widget.value ?? '';
      if (incoming == owned.text) return;

      owned.value = TextEditingValue(
        text: incoming,
        selection: TextSelection.collapsed(offset: incoming.length),
      );
    });
  }

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: widget.dense ? 0 : 8),
      child: TextFormField(
        controller: _controller,
        onChanged: widget.onChanged,
        enabled: widget.enabled,
        readOnly: widget.readOnly,
        onTap: widget.onTap,
        autofocus: widget.autofocus,
        keyboardType: widget.keyboardType,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        textCapitalization: widget.textCapitalization,
        validator:
            widget.validator ??
            (widget.required
                ? (v) => (v == null || v.trim().isEmpty)
                      ? '${widget.label} is required'
                      : null
                : null),
        decoration: InputDecoration(
          labelText: widget.required ? '${widget.label} *' : widget.label,
          hintText: widget.hint,
          helperText: widget.helper,
          helperMaxLines: 2,
          isDense: widget.dense,
          filled: widget.filled,
          prefixIcon: widget.prefixIcon == null
              ? null
              : Icon(widget.prefixIcon),
          suffixIcon: widget.suffix,
          suffixText: widget.suffixText,
          labelStyle: theme.textTheme.bodyMedium,
        ),
      ),
    );
  }
}
