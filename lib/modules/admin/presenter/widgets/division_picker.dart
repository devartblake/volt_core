import 'package:flutter/material.dart';

import '../../domain/division.dart';

/// Opens a checkbox sheet to choose any number of divisions.
///
/// [selected] are the ids already chosen. Active divisions are offered; an
/// inactive one is shown only while it is selected (so it can be removed but
/// not newly added). Returns the chosen ids in the admin-arranged order, or
/// null when the sheet is dismissed without pressing Done.
Future<List<String>?> showDivisionPickerSheet(
  BuildContext context, {
  required List<Division> divisions,
  required Iterable<String> selected,
  String title = 'Divisions',
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _DivisionPickerSheet(
      divisions: divisions,
      selected: selected.toSet(),
      title: title,
    ),
  );
}

class _DivisionPickerSheet extends StatefulWidget {
  const _DivisionPickerSheet({
    required this.divisions,
    required this.selected,
    required this.title,
  });

  final List<Division> divisions;
  final Set<String> selected;
  final String title;

  @override
  State<_DivisionPickerSheet> createState() => _DivisionPickerSheetState();
}

class _DivisionPickerSheetState extends State<_DivisionPickerSheet> {
  late final Set<String> _chosen = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final offered = [
      for (final d in sortedDivisions(widget.divisions))
        if (d.isActive || widget.selected.contains(d.id)) d,
    ];
    final atLimit = _chosen.length >= kMaxMemberDivisions;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(widget.title, style: theme.textTheme.titleLarge),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Choose every division this person works in.',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 8),
        Flexible(
          child: offered.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No divisions yet. Add them in Divisions.'),
                )
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final d in offered)
                      CheckboxListTile(
                        key: Key('division_option_${d.id}'),
                        value: _chosen.contains(d.id),
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(d.isActive ? d.name : '${d.name} (not offered)'),
                        onChanged: !_chosen.contains(d.id) && atLimit
                            ? null
                            : (v) => setState(() {
                                  if (v == true) {
                                    _chosen.add(d.id);
                                  } else {
                                    _chosen.remove(d.id);
                                  }
                                }),
                      ),
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                key: const Key('division_picker_cancel'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const Key('division_picker_done'),
                onPressed: () => Navigator.of(context)
                    .pop(orderedDivisionIds(_chosen, widget.divisions)),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Division names as chips that wrap onto more lines instead of overflowing.
/// A very long name is cut with an ellipsis.
class DivisionChips extends StatelessWidget {
  const DivisionChips({
    super.key,
    required this.names,
    this.keyPrefix = 'division_chip',
    this.icon = true,
  });

  final List<String> names;

  /// Chips are keyed `<keyPrefix>_<index>`.
  final String keyPrefix;
  final bool icon;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (var i = 0; i < names.length; i++)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Chip(
              key: Key('${keyPrefix}_$i'),
              avatar: icon
                  ? const Icon(Icons.account_tree_outlined, size: 16)
                  : null,
              label: Text(names[i], overflow: TextOverflow.ellipsis),
            ),
          ),
      ],
    );
  }
}

/// A read-only looking field that opens the picker when tapped, with the
/// chosen names (or [emptyText]) inside.
class DivisionPickerField extends StatelessWidget {
  const DivisionPickerField({
    super.key,
    required this.label,
    required this.names,
    required this.onTap,
    this.emptyText = 'No divisions',
  });

  final String label;
  final List<String> names;
  final VoidCallback? onTap;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
          suffixIcon: const Icon(Icons.arrow_drop_down),
          enabled: onTap != null,
        ),
        child: Text(
          names.isEmpty ? emptyText : names.join(', '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: names.isEmpty
              ? theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)
              : theme.textTheme.bodyLarge,
        ),
      ),
    );
  }
}
