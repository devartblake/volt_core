import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/readiness_models.dart';
import '../../domain/readiness_rules.dart' show readinessDate;
import '../../domain/readiness_view.dart';
import 'readiness_visuals.dart';

/// One generator in a list: status, the top two reasons, the due countdown and
/// the last grade. Tap opens it; long-press (or [selecting]) multi-selects.
class ReadinessUnitCard extends StatelessWidget {
  const ReadinessUnitCard({
    super.key,
    required this.unit,
    required this.now,
    required this.onTap,
    this.onLongPress,
    this.selecting = false,
    this.selected = false,
    this.highlighted = false,
  });

  final ReadinessUnit unit;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selecting;
  final bool selected;

  /// The unit open in the side pane.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final u = unit;
    final facts = [
      if (u.siteCode.isNotEmpty) u.siteCode else if (u.address.isNotEmpty) u.address,
      if (u.customer.isNotEmpty) u.customer,
    ].join('  ·  ');
    final makeModel = [u.make, u.model].where((e) => e.trim().isNotEmpty).join(' ');
    final accent = ReadinessVisuals.statusColor(theme, u.status);

    return Semantics(
      container: true,
      selected: selected,
      label: '${u.title}, ${u.status.label}. ${readinessDueText(u)}',
      child: Card(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardAll,
          side: BorderSide(
            color: selected || highlighted ? scheme.primary : scheme.outlineVariant,
            width: selected || highlighted ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (selecting)
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ExcludeSemantics(
                      child: Icon(
                        selected ? Icons.check_box : Icons.check_box_outline_blank,
                        color: selected ? scheme.primary : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                Container(
                  width: 4,
                  height: 64,
                  margin: const EdgeInsets.only(right: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              u.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: StatusChip(
                              label: u.status.label,
                              tone: ReadinessVisuals.statusTone(u.status),
                              icon: ReadinessVisuals.statusIcon(u.status),
                            ),
                          ),
                        ],
                      ),
                      if (facts.isNotEmpty || makeModel.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xxs),
                          child: Text(
                            [facts, makeModel].where((e) => e.isNotEmpty).join('  ·  '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      for (final r in u.reasons.take(2))
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ExcludeSemantics(
                                child: Icon(ReadinessVisuals.reasonIcon(r.kind),
                                    size: 16,
                                    color: ReadinessVisuals.severityColor(theme, r.severity)),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(r.text,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: AppSpacing.md,
                        runSpacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          InfoChip(
                            icon: u.isOverdue ? Icons.event_busy_outlined : Icons.event_outlined,
                            label: readinessDueText(u),
                            emphasized: u.isOverdue,
                          ),
                          if (u.lastGrade != ReadinessGrade.none)
                            GradeChip(grade: u.lastGrade),
                          if (u.lastInspectionAt != null)
                            InfoChip(
                              icon: Icons.fact_check_outlined,
                              label: 'Inspected ${readinessDate(u.lastInspectionAt!, now)}',
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A unit's open follow-up notes, newest first.
class ReadinessFollowUpCard extends StatelessWidget {
  const ReadinessFollowUpCard({
    super.key,
    required this.unit,
    required this.now,
    required this.onTap,
  });

  final ReadinessUnit unit;
  final DateTime now;
  final VoidCallback onTap;

  /// [unit]'s follow-ups, newest first (undated last).
  static List<ReadinessFollowUp> newestFirst(ReadinessUnit u) => [...u.openFollowUps]
    ..sort((a, b) {
      if (a.date == null && b.date == null) return 0;
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });

  /// Date of the newest follow-up, for ordering the cards.
  static DateTime newestDate(ReadinessUnit u) {
    final n = newestFirst(u);
    return n.isEmpty || n.first.date == null ? DateTime.fromMillisecondsSinceEpoch(0) : n.first.date!;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(unit.title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              if (unit.siteCode.isNotEmpty)
                Text(unit.siteCode,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.xs),
              for (final f in newestFirst(unit))
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ExcludeSemantics(
                        child: Icon(Icons.assignment_late_outlined,
                            size: 16, color: theme.status.warning),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          [
                            if (f.date != null) readinessDate(f.date!, now),
                            f.note.isEmpty ? 'Follow-up needed (no note)' : f.note,
                          ].join('  -  '),
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A unit that is short of parts for its next job.
class ReadinessPartsCard extends StatelessWidget {
  const ReadinessPartsCard({
    super.key,
    required this.unit,
    required this.onTap,
    required this.onProfile,
  });

  final ReadinessUnit unit;
  final VoidCallback onTap;

  /// Null when the unit has no parts profile key.
  final VoidCallback? onProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final n = unit.partsShortCount;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Icon(Icons.inventory_2_outlined, color: theme.status.warning),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(unit.title,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    Text(n == 1 ? '1 part short for the next job' : '$n parts short for the next job',
                        style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              if (onProfile != null)
                TextButton(onPressed: onProfile, child: const Text('Parts profile')),
            ],
          ),
        ),
      ),
    );
  }
}
