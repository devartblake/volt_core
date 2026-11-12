import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/schedule_view_providers.dart';
import 'calendar_view_mode.dart';

/// App-bar menu that picks the month calendar layout.
class CalendarLayoutMenu extends ConsumerWidget {
  const CalendarLayoutMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = ref.watch(calendarViewModeProvider);
    return PopupMenuButton<CalendarViewMode>(
      icon: Icon(current.icon),
      tooltip: 'Calendar View',
      onSelected: (mode) =>
          ref.read(calendarViewModeProvider.notifier).state = mode,
      itemBuilder: (context) => CalendarViewMode.values.map((mode) {
        final isActive = current == mode;
        return PopupMenuItem(
          value: mode,
          child: Row(
            children: [
              Icon(mode.icon,
                  color: isActive ? theme.colorScheme.primary : null),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      mode.label,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: isActive ? theme.colorScheme.primary : null,
                        fontWeight: isActive ? FontWeight.w600 : null,
                      ),
                    ),
                    Text(
                      mode.description,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isActive
                            ? theme.colorScheme.primary.withValues(alpha: 0.7)
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isActive)
                Icon(Icons.check, color: theme.colorScheme.primary, size: 20),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Label shown in the stats bar for a [TimeRange].
String timeRangeLabel(TimeRange range) => switch (range) {
      TimeRange.week => 'This Week',
      TimeRange.month => 'This Month',
      TimeRange.year => 'This Year',
      TimeRange.all => 'All Time',
    };

/// App-bar menu for the list view's time range.
class TimeRangeMenu extends ConsumerWidget {
  const TimeRangeMenu({super.key});

  static const _icons = {
    TimeRange.week: Icons.view_week,
    TimeRange.month: Icons.calendar_today,
    TimeRange.year: Icons.date_range,
    TimeRange.all: Icons.all_inclusive,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final current = ref.watch(timeRangeProvider);
    return PopupMenuButton<TimeRange>(
      icon: const Icon(Icons.filter_list),
      tooltip: 'Filter by time',
      onSelected: (range) =>
          ref.read(timeRangeProvider.notifier).state = range,
      itemBuilder: (context) => [
        for (final range in TimeRange.values)
          PopupMenuItem(
            value: range,
            child: Row(
              children: [
                Icon(_icons[range],
                    color: range == current ? theme.colorScheme.primary : null),
                const SizedBox(width: 12),
                Text(
                  timeRangeLabel(range),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: range == current ? theme.colorScheme.primary : null,
                    fontWeight: range == current ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
