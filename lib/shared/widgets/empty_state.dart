import 'package:flutter/material.dart';

/// The app's one empty-state presentation.
///
/// Every list previously hand-rolled its own "nothing here" block, so icon
/// sizes, copy tone, and spacing drifted from screen to screen — and several
/// lists showed a blank area instead. Use this everywhere, including for error
/// and offline states ([EmptyState.error] / [EmptyState.offline]).
///
/// ```dart
/// EmptyState(
///   icon: Icons.assignment_outlined,
///   title: 'No inspections yet',
///   message: 'Inspections you create will appear here.',
///   action: FilledButton.icon(onPressed: ..., label: Text('New inspection')),
/// )
/// ```
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.compact = false,
    this.isError = false,
  });

  /// Failure variant — same layout, error colouring. Pair with a retry action.
  const EmptyState.error({
    super.key,
    this.icon = Icons.error_outline,
    this.title = 'Something went wrong',
    this.message,
    this.action,
    this.compact = false,
  }) : isError = true;

  /// Offline variant, for content that needs a connection.
  const EmptyState.offline({
    super.key,
    this.icon = Icons.cloud_off_outlined,
    this.title = 'You are offline',
    this.message = 'Changes are saved on this device and will sync when the '
        'connection returns.',
    this.action,
    this.compact = false,
  }) : isError = false;

  final IconData icon;
  final String title;
  final String? message;

  /// Optional primary action — usually the thing that would fill this list.
  final Widget? action;

  /// Tighter layout for use inside a card or section rather than a full page.
  final bool compact;

  /// Colours the icon with the error tone.
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = isError ? scheme.error : scheme.onSurfaceVariant;

    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 24,
          vertical: compact ? 16 : 32,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: compact ? 40 : 64,
              color: tone.withValues(alpha: 0.55),
            ),
            SizedBox(height: compact ? 12 : 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: (compact
                      ? theme.textTheme.titleSmall
                      : theme.textTheme.titleMedium)
                  ?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[
              SizedBox(height: compact ? 16 : 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
