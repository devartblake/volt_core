import 'package:flutter/material.dart';

/// The app's one loading presentation.
///
/// Replaces 20-odd hand-placed `CircularProgressIndicator`s that each chose
/// their own size, padding, and centring.
///
/// * [LoadingIndicator] — centred spinner for a page or panel body.
/// * [LoadingIndicator.inline] — small spinner sized to sit next to text.
/// * [LoadingIndicator.button] — sized for inside a button, inherits its
///   foreground colour.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({
    super.key,
    this.message,
    this.size = 36,
    this.strokeWidth = 3,
    this.color,
    this.centered = true,
  });

  /// Small spinner for placing beside text or in a dense row.
  const LoadingIndicator.inline({
    super.key,
    this.color,
  })  : message = null,
        size = 16,
        strokeWidth = 2,
        centered = false;

  /// Spinner sized for inside a button; leave [color] null to inherit.
  const LoadingIndicator.button({
    super.key,
    this.color,
  })  : message = null,
        size = 20,
        strokeWidth = 2,
        centered = false;

  /// Optional label shown under the spinner (page-level use).
  final String? message;

  final double size;
  final double strokeWidth;
  final Color? color;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final spinner = SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color,
        // Announced instead of the raw progress value, which is meaningless
        // for an indeterminate spinner.
        semanticsLabel: message ?? 'Loading',
      ),
    );

    if (message == null) {
      return centered ? Center(child: spinner) : spinner;
    }

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        spinner,
        const SizedBox(height: 16),
        Text(
          message!,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    return centered ? Center(child: content) : content;
  }
}
