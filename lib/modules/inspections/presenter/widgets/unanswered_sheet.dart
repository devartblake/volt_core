import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/inspection_unanswered.dart';

/// Chip row above the inspection form showing how many required items are
/// still unanswered. Hidden when there are none.
class UnansweredBar extends StatelessWidget {
  const UnansweredBar({super.key, required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (count == 0) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
        child: ActionChip(
          avatar: Icon(Icons.rule, size: 18, color: scheme.error),
          label: Text('$count unanswered'),
          tooltip: 'Show unanswered required items',
          onPressed: onTap,
        ),
      ),
    );
  }
}

/// Lists [items] grouped by section; returns the tapped section's key.
Future<String?> showUnansweredSheet(
    BuildContext context, List<UnansweredItem> items) {
  final groups = groupUnansweredBySection(items);
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
              child: Text(
                '${items.length} unanswered',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            for (final entry in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
                child: Text(
                  entry.value.first.sectionLabel,
                  style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                        color: Theme.of(ctx).colorScheme.primary,
                      ),
                ),
              ),
              for (final it in entry.value)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.radio_button_unchecked, size: 18),
                  title: Text(it.label),
                  onTap: () => Navigator.pop(ctx, it.sectionKey),
                ),
            ],
          ],
        ),
      ),
    ),
  );
}
