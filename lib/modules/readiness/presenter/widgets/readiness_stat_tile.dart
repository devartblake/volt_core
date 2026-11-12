import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/readiness_mini_series.dart';
import '../../domain/readiness_models.dart';
import '../../domain/readiness_summary.dart';
import 'readiness_mini_charts.dart';
import 'readiness_visuals.dart';

const _tileLabels = {
  ReadinessStatus.ready: 'Ready',
  ReadinessStatus.dueSoon: 'Due soon',
  ReadinessStatus.attention: 'Attention',
  ReadinessStatus.notReady: 'Not ready',
};

/// A status tile: label and icon on top, the count and a small graph of what
/// is behind it underneath. Tapping toggles the status filter.
class ReadinessStatTile extends StatelessWidget {
  const ReadinessStatTile({
    super.key,
    required this.status,
    required this.summary,
    required this.units,
    required this.now,
    required this.dueSoonDays,
    required this.onTap,
  });

  final ReadinessStatus status;
  final ReadinessSummary summary;
  final List<ReadinessUnit> units;
  final DateTime now;
  final int dueSoonDays;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = ReadinessVisuals.statusColor(theme, status);
    final label = _tileLabels[status]!;
    final value = '${summary.count(status)}';

    final reasons = switch (status) {
      ReadinessStatus.attention => attentionReasonCounts(units),
      ReadinessStatus.notReady => notReadyReasonCounts(units),
      _ => const <ReasonCount>[],
    };
    final weeks = status == ReadinessStatus.dueSoon
        ? dueSoonWeekSlice(summary.dueByWeek, now, dueSoonDays)
        : const <DueWeekPoint>[];
    final graph = ReadinessTileGraph(
      status: status,
      share: statusShare(summary, status),
      dueWeeks: weeks,
      reasons: reasons,
      total: summary.total,
      count: summary.count(status),
    );

    return Semantics(
      container: true,
      button: true,
      label: '$label: $value',
      child: Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.field),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ExcludeSemantics(
                child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(ReadinessVisuals.statusIcon(status), color: accent, size: 20),
                ],
              )),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ExcludeSemantics(
                    child: Text(
                      value,
                      maxLines: 1,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: graph),
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
