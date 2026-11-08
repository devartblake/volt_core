import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../materials/infra/materials_repository.dart';
import '../../domain/entities/inspection_entity.dart';
import '../../domain/inspection_completion.dart';
import '../../domain/inspection_unanswered.dart';

/// Chip above the inspection form: "Not finished: 2 things left" or
/// "Ready to finish". Opens [showFinishSheet]. Never blocks saving.
class FinishBar extends StatelessWidget {
  const FinishBar({super.key, required this.completion, required this.onTap});

  final InspectionCompletion completion;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = completion.isFinished;
    final n = completion.remainingCount;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, 0),
        child: ActionChip(
          avatar: Icon(
            done ? Icons.check_circle_outline : Icons.rule,
            size: 18,
            color: done ? theme.status.success : theme.colorScheme.error,
          ),
          label: Text(done
              ? 'Ready to finish'
              : 'Not finished: $n ${n == 1 ? 'thing' : 'things'} left'),
          tooltip: 'Show what is needed to finish this inspection',
          onPressed: onTap,
        ),
      ),
    );
  }
}

/// What a tapped row in the sheet should scroll to: a form section id
/// (`postInspection`, `materials`, `siteInfo`, ...).
Future<String?> showFinishSheet(
  BuildContext context,
  InspectionCompletion completion,
  List<UnansweredItem> alsoMissing,
) {
  final groups = groupUnansweredBySection(
      alsoMissing.where((i) => i.sectionKey != 'postInspection').toList());
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      Widget header(String text) => Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
            child: Text(text,
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.primary)),
          );
      Widget row(bool ok, String text, String target, {String? subtitle}) =>
          ListTile(
            dense: true,
            leading: Icon(
              ok ? Icons.check_circle : Icons.cancel,
              size: 20,
              color: ok ? theme.status.success : theme.colorScheme.error,
            ),
            title: Text(text),
            subtitle: subtitle == null ? null : Text(subtitle),
            onTap: () => Navigator.pop(ctx, target),
          );
      return SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xs),
                child: Text(
                  completion.isFinished
                      ? 'Ready to finish'
                      : 'To finish this inspection',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  'You can save a draft at any time. These only decide '
                  'whether it counts as finished.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
              header('Checklist'),
              row(
                completion.checklistMet,
                'Post-inspection checklist ${completion.checklistAnswered} of '
                '${completion.checklistTotal} done',
                'postInspection',
                subtitle: '${completion.checklistNeeded} needed (half)',
              ),
              header('Parts & Materials: part numbers'),
              for (final e in completion.parts.entries)
                row(e.value, e.key.label, 'materials',
                    subtitle: e.value ? null : 'No part number yet'),
              if (groups.isNotEmpty) ...[
                header('Also missing (does not block finishing)'),
                for (final entry in groups.entries)
                  for (final it in entry.value)
                    ListTile(
                      dense: true,
                      leading:
                          const Icon(Icons.radio_button_unchecked, size: 18),
                      title: Text(it.label),
                      subtitle: Text(it.sectionLabel),
                      onTap: () => Navigator.pop(ctx, it.sectionKey),
                    ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// "Not finished" / "Finished" pill for list rows and the detail page,
/// computed from the saved record and its saved parts. Shows nothing while
/// the parts are still loading.
class InspectionFinishChip extends ConsumerWidget {
  const InspectionFinishChip(
      {super.key, required this.inspection, this.showReasons = false});

  final InspectionEntity inspection;

  /// Also list every reason below the chip (detail page).
  final bool showReasons;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref
        .watch(materialItemsProvider(
            MaterialOwner.inspection(id: inspection.id)))
        .value;
    if (items == null) return const SizedBox.shrink();
    final c = InspectionCompletion.of(inspection, items);
    if (c.isFinished) {
      return const StatusChip(
          label: 'Finished',
          tone: StatusTone.success,
          icon: Icons.check_circle_outline);
    }
    final chip = Tooltip(
      message: c.reasons.first,
      child: const StatusChip(
          label: 'Not finished',
          tone: StatusTone.warning,
          icon: Icons.pending_outlined),
    );
    if (!showReasons) return chip;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        chip,
        const SizedBox(height: AppSpacing.xs),
        for (final r in c.reasons)
          Text(r,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
