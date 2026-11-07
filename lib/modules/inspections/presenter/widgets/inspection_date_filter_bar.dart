import 'package:flutter/material.dart';

import '../inspection_date_filter.dart';

/// The date filter strip shared by the All Inspections list and the vehicle
/// inspection log: All, Today, This week, This month, or a picked date, with
/// arrows to step to the previous or next day, week or month.
class InspectionDateFilterBar extends StatelessWidget {
  const InspectionDateFilterBar({
    super.key,
    required this.filter,
    required this.onChanged,
    required this.shown,
    required this.total,
    this.noun = 'inspection',
  });

  final InspectionDateFilter filter;
  final ValueChanged<InspectionDateFilter> onChanged;

  /// How many items the current filter leaves, and how many there are in all.
  final int shown;
  final int total;

  /// Singular word for the count line ("inspection", "log entry").
  final String noun;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _count(int n) => n == 1 ? '1 $noun' : '$n ${noun}s';

  Future<void> _pickDate(BuildContext context, {InspectionPeriod? period}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: filter.anchor ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 2, 12, 31),
      helpText: switch (period ?? filter.period) {
        InspectionPeriod.week => 'Pick any day in the week',
        InspectionPeriod.month => 'Pick any day in the month',
        _ => 'Pick a date',
      },
    );
    if (picked == null || !context.mounted) return;
    onChanged(InspectionDateFilter.of(
      period ?? (filter.isAll ? InspectionPeriod.day : filter.period),
      picked,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isToday = filter.period == InspectionPeriod.day &&
        filter.anchor != null &&
        _sameDay(filter.anchor!, now);
    final isOtherDay = filter.period == InspectionPeriod.day && !isToday;

    Widget chip(String label, bool selected, VoidCallback onTap,
            {IconData? icon}) =>
        ChoiceChip(
          avatar: icon == null ? null : Icon(icon, size: 16),
          // Explicit colours: the theme's chip text was nearly invisible on
          // the light bar.
          label: Text(
            label,
            style: TextStyle(
              color: selected
                  ? theme.colorScheme.onSecondaryContainer
                  : theme.colorScheme.onSurface,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          selected: selected,
          onSelected: (_) => onTap(),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              chip('All', filter.isAll,
                  () => onChanged(const InspectionDateFilter.all())),
              chip('Today', isToday,
                  () => onChanged(InspectionDateFilter.of(InspectionPeriod.day, now))),
              chip(
                'This week',
                filter.period == InspectionPeriod.week && filter.containsToday(now),
                () => onChanged(InspectionDateFilter.of(InspectionPeriod.week, now)),
              ),
              chip(
                'This month',
                filter.period == InspectionPeriod.month && filter.containsToday(now),
                () => onChanged(InspectionDateFilter.of(InspectionPeriod.month, now)),
              ),
              chip(
                isOtherDay ? filter.label : 'Pick a date',
                isOtherDay,
                () => _pickDate(context, period: InspectionPeriod.day),
                icon: Icons.calendar_today,
              ),
            ],
          ),
          if (!filter.isAll)
            Row(
              children: [
                IconButton(
                  tooltip: switch (filter.period) {
                    InspectionPeriod.week => 'Previous week',
                    InspectionPeriod.month => 'Previous month',
                    _ => 'Previous day',
                  },
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => onChanged(filter.shifted(-1)),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          Text(
                            filter.label,
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            _count(shown),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: switch (filter.period) {
                    InspectionPeriod.week => 'Next week',
                    InspectionPeriod.month => 'Next month',
                    _ => 'Next day',
                  },
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => onChanged(filter.shifted(1)),
                ),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 2),
              child: Text(
                _count(total),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
