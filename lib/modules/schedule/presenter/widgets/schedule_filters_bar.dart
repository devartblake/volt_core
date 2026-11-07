import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/schedule_view_logic.dart';

/// Day / Week / Month switch.
class ScheduleSpanSelector extends StatelessWidget {
  const ScheduleSpanSelector({
    super.key,
    required this.span,
    required this.onChanged,
  });

  final ScheduleSpan span;
  final ValueChanged<ScheduleSpan> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<ScheduleSpan>(
        showSelectedIcon: false,
        segments: const [
          ButtonSegment(value: ScheduleSpan.day, label: Text('Day')),
          ButtonSegment(value: ScheduleSpan.week, label: Text('Week')),
          ButtonSegment(value: ScheduleSpan.month, label: Text('Month')),
        ],
        selected: {span},
        onSelectionChanged: (s) => onChanged(s.first),
      );
}

/// Previous / Today / Next with the range label, for the Day and Week views.
class ScheduleRangeNav extends StatelessWidget {
  const ScheduleRangeNav({
    super.key,
    required this.span,
    required this.focus,
    required this.onChanged,
  });

  final ScheduleSpan span;
  final DateTime focus;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noun = span == ScheduleSpan.day ? 'day' : 'week';
    return Row(
      children: [
        IconButton(
          tooltip: 'Previous $noun',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(shiftFocus(span, focus, -1)),
        ),
        Expanded(
          child: Text(
            formatSpanLabel(span, focus),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(
          onPressed: () => onChanged(DateTime.now()),
          child: const Text('Today'),
        ),
        IconButton(
          tooltip: 'Next $noun',
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChanged(shiftFocus(span, focus, 1)),
        ),
      ],
    );
  }
}

/// Technician filter: All, Unassigned, then one chip per technician.
///
/// [technicianIds] are the technicians to offer (those with tasks in view,
/// plus the selected one). [selected] is null for All, [unassignedFilter], or
/// a user id.
class TechnicianFilterChips extends StatelessWidget {
  const TechnicianFilterChips({
    super.key,
    required this.technicianIds,
    required this.names,
    required this.selected,
    required this.onSelected,
  });

  final List<String> technicianIds;
  final Map<String, String> names;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, String? value, {Key? key}) => Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: ChoiceChip(
            key: key,
            label: Text(label),
            selected: selected == value,
            onSelected: (_) => onSelected(value),
          ),
        );

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
        children: [
          chip('All', null, key: const Key('tech_filter_all')),
          chip('Unassigned', unassignedFilter,
              key: const Key('tech_filter_unassigned')),
          for (final id in technicianIds)
            chip(technicianLabel(id, names), id, key: Key('tech_filter_$id')),
        ],
      ),
    );
  }
}
