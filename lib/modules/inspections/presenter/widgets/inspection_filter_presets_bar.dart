import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../domain/inspection_filter_preset.dart';

/// Search box, grade chips, density toggle and saved-preset chips for the
/// inspections list. Holds no filter state: the page owns it.
class InspectionFilterPresetsBar extends StatefulWidget {
  const InspectionFilterPresetsBar({
    super.key,
    required this.filter,
    required this.onChanged,
    required this.presets,
    required this.onSavePreset,
    required this.onRenamePreset,
    required this.onDeletePreset,
    required this.density,
    required this.onDensityChanged,
  });

  final InspectionListFilter filter;
  final ValueChanged<InspectionListFilter> onChanged;

  /// Built-in presets first, then the user's saved ones.
  final List<InspectionFilterPreset> presets;
  final ValueChanged<String> onSavePreset;
  final void Function(InspectionFilterPreset preset, String name)
      onRenamePreset;
  final ValueChanged<InspectionFilterPreset> onDeletePreset;

  final InspectionDensity density;
  final ValueChanged<InspectionDensity> onDensityChanged;

  @override
  State<InspectionFilterPresetsBar> createState() =>
      _InspectionFilterPresetsBarState();
}

class _InspectionFilterPresetsBarState
    extends State<InspectionFilterPresetsBar> {
  late final TextEditingController _search =
      TextEditingController(text: widget.filter.query);

  @override
  void didUpdateWidget(covariant InspectionFilterPresetsBar old) {
    super.didUpdateWidget(old);
    // A preset was applied or the filter was cleared from outside.
    if (_search.text != widget.filter.query) {
      _search.text = widget.filter.query;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  static const _grades = ['green', 'amber', 'red'];

  void _toggleGrade(String grade) {
    final next = Set<String>.of(widget.filter.grades);
    if (!next.remove(grade)) next.add(grade);
    widget.onChanged(widget.filter.copyWith(grades: next));
  }

  Future<String?> _askName(String title, {String initial = ''}) {
    return showDialog<String>(
      context: context,
      builder: (_) => _NameDialog(title: title, initial: initial),
    );
  }

  Future<void> _save() async {
    final name = await _askName('Save filter');
    if (name != null && mounted) widget.onSavePreset(name);
  }

  Future<void> _presetMenu(InspectionFilterPreset p) async {
    if (p.builtIn) return;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: Text(p.name)),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename'),
              onTap: () => Navigator.pop(ctx, 'rename'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'delete') {
      widget.onDeletePreset(p);
    } else if (choice == 'rename') {
      final name = await _askName('Rename filter', initial: p.name);
      if (name != null && mounted) widget.onRenamePreset(p, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filter = widget.filter;
    final compact = widget.density == InspectionDensity.compact;
    final matched = widget.presets.any((p) => p.matches(filter));

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _search,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search address, site, technician',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: filter.query.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                widget.onChanged(filter.copyWith(query: '')),
                          ),
                  ),
                  onChanged: (v) => widget.onChanged(filter.copyWith(query: v)),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              IconButton(
                tooltip: compact ? 'Comfortable rows' : 'Compact rows',
                icon: Icon(compact
                    ? Icons.density_medium
                    : Icons.density_small),
                onPressed: () => widget.onDensityChanged(compact
                    ? InspectionDensity.comfortable
                    : InspectionDensity.compact),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final g in _grades)
                FilterChip(
                  label: Text('${g[0].toUpperCase()}${g.substring(1)}'),
                  selected: filter.grades.contains(g),
                  onSelected: (_) => _toggleGrade(g),
                ),
              for (final p in widget.presets)
                GestureDetector(
                  onLongPress: p.builtIn ? null : () => _presetMenu(p),
                  child: ChoiceChip(
                    avatar: Icon(
                      p.builtIn ? Icons.bookmark_border : Icons.bookmark,
                      size: 16,
                    ),
                    label: Text(p.name),
                    selected: p.matches(filter),
                    onSelected: (_) => widget.onChanged(p.toFilter()),
                  ),
                ),
              if (!filter.isDefault && !matched)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 16),
                  label: const Text('Save filter'),
                  onPressed: _save,
                ),
              if (!filter.isDefault)
                TextButton(
                  onPressed: () => widget.onChanged(const InspectionListFilter()),
                  child: Text('Clear',
                      style: TextStyle(color: theme.colorScheme.primary)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.title, required this.initial});

  final String title;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _ctl =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _ctl.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
