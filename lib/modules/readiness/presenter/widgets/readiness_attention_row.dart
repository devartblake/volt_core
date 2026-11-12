import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/readiness_models.dart';
import '../../domain/readiness_view.dart';
import 'readiness_visuals.dart';

/// Width of one unit card in the horizontal list.
const double kAttentionCardWidth = 280;

/// "Needs attention first": the worst units as a row of compact cards. Fills
/// the row when they all fit, otherwise scrolls sideways.
class ReadinessAttentionRow extends StatelessWidget {
  const ReadinessAttentionRow({
    super.key,
    required this.units,
    required this.onOpen,
    required this.onSeeAll,
  });

  final List<ReadinessUnit> units;
  final ValueChanged<ReadinessUnit> onOpen;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (units.isEmpty) return const SizedBox.shrink();
    final scale = MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.6);
    final height = 176.0 * scale;
    const gap = AppSpacing.md;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text('Needs attention first',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
            ),
            TextButton(
              key: const Key('worst-see-all'),
              onPressed: onSeeAll,
              child: const Text('See all'),
            ),
          ],
        ),
        LayoutBuilder(builder: (context, c) {
          final needed = units.length * kAttentionCardWidth + (units.length - 1) * gap;
          if (needed <= c.maxWidth) {
            return SizedBox(
              height: height,
              child: Row(
                children: [
                  for (var i = 0; i < units.length; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    Expanded(child: _UnitCard(unit: units[i], onOpen: onOpen)),
                  ],
                ],
              ),
            );
          }
          return SizedBox(
            height: height,
            // At most five cards, so a plain horizontal scroller builds them
            // all (each stays findable and ready to tap).
            child: SingleChildScrollView(
              key: const Key('worst-list'),
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              child: Row(
                children: [
                  for (var i = 0; i < units.length; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    SizedBox(
                      width: kAttentionCardWidth,
                      child: _UnitCard(unit: units[i], onOpen: onOpen),
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({required this.unit, required this.onOpen});

  final ReadinessUnit unit;
  final ValueChanged<ReadinessUnit> onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final u = unit;
    final color = ReadinessVisuals.statusColor(theme, u.status);
    final site = [u.siteCode, u.customer].where((e) => e.isNotEmpty).join('  ');
    return Semantics(
      container: true,
      button: true,
      label: '${u.title}, ${u.status.label}. ${readinessDueText(u)}',
      excludeSemantics: true,
      child: Card(
        key: Key('worst-${u.key}'),
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardAll,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          onTap: () => onOpen(u),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(ReadinessVisuals.statusIcon(u.status), size: 20, color: color),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(u.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                if (site.isNotEmpty)
                  Text(site,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                const SizedBox(height: AppSpacing.xs),
                if (u.reasons.isNotEmpty)
                  Text(u.reasons.first.text,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Text(readinessDueText(u),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    GradeChip(grade: u.lastGrade),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
