import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../materials/presenter/materials_section_card.dart'
    show showGeneratorPartsProfile;
import '../../domain/readiness_models.dart';
import '../../domain/readiness_view.dart';
import 'readiness_unit_card.dart';

enum ReadinessSegment {
  units('Units', Icons.list_alt_outlined),
  calendar('Due calendar', Icons.calendar_month_outlined),
  followUps('Follow-ups', Icons.assignment_late_outlined),
  parts('Parts', Icons.inventory_2_outlined);

  const ReadinessSegment(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Units | Due calendar | Follow-ups | Parts. Scrolls sideways rather than
/// squeezing the labels on a narrow phone.
class ReadinessSegmentSelector extends StatelessWidget {
  const ReadinessSegmentSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.followUpUnits,
    required this.partsUnits,
    this.compact = false,
  });

  final ReadinessSegment selected;
  final ValueChanged<ReadinessSegment> onChanged;
  final int followUpUnits;
  final int partsUnits;

  /// No icons, so all four labels fit a narrow phone.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    String label(ReadinessSegment s) => switch (s) {
          ReadinessSegment.followUps when followUpUnits > 0 => 'Follow-ups ($followUpUnits)',
          ReadinessSegment.parts when partsUnits > 0 => 'Parts ($partsUnits)',
          _ => s.label,
        };
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SegmentedButton<ReadinessSegment>(
        key: const Key('readiness-segments'),
        showSelectedIcon: false,
        segments: [
          for (final s in ReadinessSegment.values)
            ButtonSegment(
              value: s,
              icon: compact ? null : Icon(s.icon, size: 18),
              label: Text(label(s)),
            ),
        ],
        selected: {selected},
        onSelectionChanged: (v) => onChanged(v.first),
      ),
    );
  }
}

/// One lazily built row of a segment list.
typedef ReadinessRow = Widget Function(BuildContext context);

/// Rows for the Due calendar: a header per week then its units.
List<ReadinessRow> calendarRows(
  List<ReadinessUnit> units,
  DateTime now,
  Widget Function(ReadinessUnit) card,
) {
  final rows = <ReadinessRow>[];
  for (final g in groupByDueWeek(units, now)) {
    rows.add((context) {
      final theme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
        child: Semantics(
          header: true,
          child: Text(
            '${g.label} (${g.count})',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: g.label == 'Overdue' ? theme.colorScheme.error : null,
            ),
          ),
        ),
      );
    });
    for (final u in g.units) {
      rows.add((_) => card(u));
    }
  }
  return rows;
}

/// Rows for Follow-ups: units with open follow-ups, newest note first.
List<ReadinessRow> followUpRows(
  List<ReadinessUnit> units,
  DateTime now,
  ValueChanged<ReadinessUnit> onOpen,
) {
  final withNotes = [
    for (final u in units)
      if (u.hasFollowUps) u,
  ]..sort((a, b) => ReadinessFollowUpCard.newestDate(b)
      .compareTo(ReadinessFollowUpCard.newestDate(a)));
  return [
    for (final u in withNotes)
      (_) => ReadinessFollowUpCard(unit: u, now: now, onTap: () => onOpen(u)),
  ];
}

/// Rows for Parts: units short of parts for their next job, most short first,
/// led by a link to the Shortages page.
List<ReadinessRow> partsRows(
  List<ReadinessUnit> units,
  ValueChanged<ReadinessUnit> onOpen,
) {
  final short = [
    for (final u in units)
      if (u.partsShortCount > 0) u,
  ]..sort((a, b) => b.partsShortCount.compareTo(a.partsShortCount));
  return [
    if (short.isNotEmpty)
      (context) => Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: OutlinedButton.icon(
                key: const Key('open-shortages'),
                onPressed: () => context.go(RoutePaths.inventoryShortages),
                icon: const Icon(Icons.shopping_cart_outlined),
                label: const Text('Open the Shortages page'),
              ),
            ),
          ),
    for (final u in short)
      (context) => ReadinessPartsCard(
            unit: u,
            onTap: () => onOpen(u),
            onProfile: u.profileKey.isEmpty
                ? null
                : () => showGeneratorPartsProfile(context,
                    make: u.make, model: u.model, serial: u.serial),
          ),
  ];
}
