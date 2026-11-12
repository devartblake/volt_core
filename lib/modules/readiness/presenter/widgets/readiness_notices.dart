import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/readiness_inputs.dart';

/// Banner shown above the data when a refresh failed but the last result is
/// still on screen.
class ReadinessErrorBanner extends StatelessWidget {
  const ReadinessErrorBanner({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: AppRadius.fieldAll,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Could not refresh. Showing the last result.',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text('Retry', style: TextStyle(color: scheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}

/// "N records could not be matched to a generator" with an info sheet.
class ReadinessUnmatchedNote extends StatelessWidget {
  const ReadinessUnmatchedNote({super.key, required this.unmatched});

  final ReadinessUnmatched unmatched;

  @override
  Widget build(BuildContext context) {
    final n = unmatched.total;
    if (n == 0) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: InkWell(
        key: const Key('unmatched-note'),
        borderRadius: AppRadius.fieldAll,
        onTap: () => showReadinessUnmatchedSheet(context, unmatched),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 20, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  n == 1
                      ? '1 record could not be matched to a generator'
                      : '$n records could not be matched to a generator',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              Text('Details', style: TextStyle(color: theme.colorScheme.primary)),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showReadinessUnmatchedSheet(
  BuildContext context,
  ReadinessUnmatched u,
) {
  final theme = Theme.of(context);
  Widget row(String label, int n) => n == 0
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text('$n $label', style: theme.textTheme.bodyLarge),
        );
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Records not matched',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'These records name a generator or site the dashboard cannot pin '
            'to one machine, so they are left out of the numbers rather than '
            'guessed. Adding a serial number or site code to them fixes it.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          row('maintenance records', u.maintenance),
          row('scheduled tasks', u.tasks),
          row('jobs with parts needs', u.jobNeeds),
        ],
      ),
    ),
  );
}
