import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/readiness_models.dart';
import '../../domain/readiness_summary.dart';
import '../../domain/readiness_view.dart';
import '../readiness_providers.dart';
import 'readiness_charts.dart' show readinessWeekLabel;

/// Search, status chips, sort and the less-used filters. On a phone the
/// less-used ones collapse into a "Filters (3)" bottom sheet; on wider screens
/// they sit inline. State lives in [readinessFilterProvider] and
/// [readinessSortProvider], so it survives leaving the screen for the session.
class ReadinessFilterBar extends ConsumerStatefulWidget {
  const ReadinessFilterBar({super.key, required this.units, required this.compact});

  /// Every unit (not the filtered ones), for the make and borough options.
  final List<ReadinessUnit> units;
  final bool compact;

  @override
  ConsumerState<ReadinessFilterBar> createState() => _ReadinessFilterBarState();
}

class _ReadinessFilterBarState extends ConsumerState<ReadinessFilterBar> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: ref.read(readinessFilterProvider).query);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _set(ReadinessFilter f) => ref.read(readinessFilterProvider.notifier).state = f;

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(readinessFilterProvider);
    final sort = ref.watch(readinessSortProvider);
    // Keep the box in step when the filter is cleared from elsewhere.
    if (_search.text != filter.query) {
      _search.value = TextEditingValue(
        text: filter.query,
        selection: TextSelection.collapsed(offset: filter.query.length),
      );
    }
    final active = activeFilterCount(filter);
    final inSheet = sheetFilterCount(filter);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                key: const Key('readiness-search'),
                controller: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search unit, site, serial or customer',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  suffixIcon: filter.query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.close),
                          onPressed: () => _set(filter.copyWith(query: '')),
                        ),
                ),
                onChanged: (v) => _set(filter.copyWith(query: v)),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            PopupMenuButton<ReadinessSort>(
              key: const Key('readiness-sort'),
              tooltip: 'Sort: ${sort.label}',
              initialValue: sort,
              onSelected: (s) => ref.read(readinessSortProvider.notifier).state = s,
              itemBuilder: (_) => [
                for (final s in ReadinessSort.values)
                  CheckedPopupMenuItem(
                    value: s,
                    checked: s == sort,
                    child: Text(s.label),
                  ),
              ],
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.sort),
                    if (!widget.compact) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Text(sort.label),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final st in ReadinessStatus.values.reversed)
              FilterChip(
                key: Key('status-chip-${st.name}'),
                label: Text(st.label),
                selected: filter.statuses.contains(st),
                onSelected: (on) {
                  final next = {...filter.statuses};
                  on ? next.add(st) : next.remove(st);
                  _set(filter.copyWith(statuses: next));
                },
              ),
            if (widget.compact)
              ActionChip(
                key: const Key('filters-button'),
                avatar: const Icon(Icons.tune, size: 18),
                label: Text(inSheet == 0 ? 'Filters' : 'Filters ($inSheet)'),
                onPressed: () => showReadinessFiltersSheet(context, widget.units),
              ),
            if (active > 0)
              TextButton(
                key: const Key('clear-filters'),
                onPressed: () => _set(const ReadinessFilter()),
                child: Text('Clear all ($active)'),
              ),
          ],
        ),
        if (!widget.compact) ...[
          const SizedBox(height: AppSpacing.sm),
          ReadinessFilterControls(units: widget.units),
        ],
        if (filter.dueWeekStart != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: InputChip(
              label: Text('Due week of ${readinessWeekLabel(filter.dueWeekStart!)}'),
              onDeleted: () => _set(filter.copyWith(clearDueWeek: true)),
              deleteButtonTooltipMessage: 'Remove week filter',
            ),
          ),
      ],
    );
  }
}

/// Make, borough, due window, follow-ups and grade. Inline on wide screens and
/// the body of the phone sheet.
class ReadinessFilterControls extends ConsumerWidget {
  const ReadinessFilterControls({super.key, required this.units});

  final List<ReadinessUnit> units;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(readinessFilterProvider);
    void set(ReadinessFilter f) => ref.read(readinessFilterProvider.notifier).state = f;
    final theme = Theme.of(context);
    final makes = distinctMakes(units);
    final boroughs = distinctBoroughs(units);

    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
          child: Text(t,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (makes.isNotEmpty) ...[
          label('Make'),
          DropdownButtonFormField<String?>(
            key: ValueKey('make-${filter.make}'),
            initialValue: filter.make,
            isExpanded: true,
            decoration: const InputDecoration(isDense: true),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('Any make')),
              for (final m in makes) DropdownMenuItem<String?>(value: m, child: Text(m)),
            ],
            onChanged: (m) => set(m == null
                ? filter.copyWith(clearMake: true)
                : filter.copyWith(make: m)),
          ),
        ],
        // Boroughs only exist for site codes the app can read (Q_ and X_).
        if (boroughs.isNotEmpty) ...[
          label('Borough'),
          Wrap(spacing: AppSpacing.sm, children: [
            for (final b in boroughs)
              ChoiceChip(
                label: Text(b),
                selected: filter.borough == b,
                onSelected: (on) => set(on
                    ? filter.copyWith(borough: b)
                    : filter.copyWith(clearBorough: true)),
              ),
          ]),
        ],
        label('Next inspection due'),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
          for (final w in ReadinessDueWindow.values)
            ChoiceChip(
              key: Key('window-${w.name}'),
              label: Text(switch (w) {
                ReadinessDueWindow.overdue => 'Overdue',
                ReadinessDueWindow.next7 => '7 days',
                ReadinessDueWindow.next30 => '30 days',
                ReadinessDueWindow.next90 => '90 days',
              }),
              selected: filter.dueWindow == w,
              onSelected: (on) => set(on
                  ? filter.copyWith(dueWindow: w, clearDueWeek: true)
                  : filter.copyWith(clearDueWindow: true)),
            ),
        ]),
        label('Last grade'),
        Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.xs, children: [
          for (final g in const [
            ReadinessGrade.green,
            ReadinessGrade.amber,
            ReadinessGrade.red,
            ReadinessGrade.none,
          ])
            ChoiceChip(
              key: Key('grade-${g.name}'),
              label: Text(g.label),
              selected: filter.grade == g,
              onSelected: (on) => set(
                  on ? filter.copyWith(grade: g) : filter.copyWith(clearGrade: true)),
            ),
        ]),
        const SizedBox(height: AppSpacing.xs),
        SwitchListTile(
          key: const Key('followups-switch'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Has follow-ups'),
          value: filter.hasFollowUps == true,
          onChanged: (on) => set(on
              ? filter.copyWith(hasFollowUps: true)
              : filter.copyWith(clearHasFollowUps: true)),
        ),
      ],
    );
  }
}

Future<void> showReadinessFiltersSheet(
  BuildContext context,
  List<ReadinessUnit> units,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => Consumer(builder: (context, ref, _) {
      final f = ref.watch(readinessFilterProvider);
      return SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg,
            AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text('Filters',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              TextButton(
                onPressed: () => ref.read(readinessFilterProvider.notifier).state =
                    f.copyWith(
                  clearMake: true,
                  clearBorough: true,
                  clearDueWindow: true,
                  clearDueWeek: true,
                  clearHasFollowUps: true,
                  clearGrade: true,
                ),
                child: const Text('Reset'),
              ),
            ]),
            ReadinessFilterControls(units: units),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      );
    }),
  );
}
