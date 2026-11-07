import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/widgets.dart';
import '../domain/material_item.dart';
import '../domain/material_list.dart';
import '../domain/part_usage.dart';
import 'job_context_providers.dart';
import 'profile_job_proposal.dart';
import '../infra/material_usage.dart';
import '../infra/materials_repository.dart';
import '../../inventory/domain/catalog_part.dart';
import '../../inventory/domain/stock.dart';
import '../../inventory/infra/inventory_repository.dart';

/// Where the editor is used; changes wording and which controls show.
enum MaterialsMode {
  /// A generator's standing parts list ("what it takes").
  profile('Date last fitted'),

  /// An inspection: what is installed, and what is due for replacement.
  inspection('Date used'),

  /// A maintenance: what was used.
  maintenance('Date used');

  const MaterialsMode(this.dateLabel);

  final String dateLabel;
}

String formatMaterialDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

/// The ten material slots of a generator or a job, each with the same item
/// fields: part number, quantity, date used and part name / manufacturer.
///
/// Edits autosave to the device a moment after typing stops and are queued for
/// the cloud with them, so closing the form never loses parts.
class MaterialsEditor extends ConsumerStatefulWidget {
  const MaterialsEditor({
    super.key,
    required this.owner,
    required this.mode,
    this.profileOwner,
    this.canEditProfile = false,
    this.readOnly = false,
    this.seed,
    this.onChanged,
  });

  final MaterialOwner owner;
  final MaterialsMode mode;

  /// The generator's profile, when this editor is for a job: enables
  /// "Copy from profile" (and "Save to profile" where [canEditProfile]).
  final MaterialOwner? profileOwner;
  final bool canEditProfile;
  final bool readOnly;

  /// Items to start from when nothing is saved yet (older inspections only
  /// have four dates; they are carried in here so they are not lost).
  final List<MaterialItem> Function()? seed;

  /// Called with the current items after each edit.
  final ValueChanged<List<MaterialItem>>? onChanged;

  @override
  ConsumerState<MaterialsEditor> createState() => _MaterialsEditorState();
}

class _MaterialsEditorState extends ConsumerState<MaterialsEditor> {
  List<MaterialItem> _items = const [];
  bool _loaded = false;
  bool _dirty = false;
  Timer? _timer;
  final Set<MaterialSlot> _open = {};

  // Held for dispose, where `ref` can no longer be used.
  late final MaterialsRepository _repo = ref.read(materialsRepositoryProvider);
  late MaterialOwner _owner = widget.owner;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MaterialsEditor old) {
    super.didUpdateWidget(old);
    if (old.owner != widget.owner) {
      _flush();
      _owner = widget.owner;
      _loaded = false;
      _load();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_dirty) {
      // Fire and forget: the form is closing and must not wait on the disk.
      _repo.save(_owner, _items);
    }
    super.dispose();
  }

  Future<void> _load() async {
    var items = await _repo.load(_owner);
    if (items.isEmpty && widget.seed != null) items = widget.seed!();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loaded = true;
      _open
        ..clear()
        ..addAll([
          for (final s in MaterialSlot.values)
            if (items.any((i) => i.slot == s)) s,
        ]);
    });
  }

  void _change(List<MaterialItem> next) {
    setState(() {
      _items = next;
      _dirty = true;
    });
    widget.onChanged?.call(next);
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 1500), _flush);
  }

  Future<void> _flush() async {
    _timer?.cancel();
    if (!_dirty) return;
    _dirty = false;
    try {
      await _repo.save(_owner, _items);
      ref.invalidate(materialItemsProvider(_owner));
    } catch (_) {
      // The next edit saves again; an autosave hiccup must not interrupt work.
      _dirty = true;
    }
  }

  // ------------------------------------------------------------- actions

  Future<void> _copyFromProfile() async {
    final profile = widget.profileOwner;
    if (profile == null) return;
    final source = await _repo.load(profile);
    if (!mounted) return;
    if (source.isEmpty) {
      AppSnackBar.info(
        context,
        'This generator has no parts profile yet. Fill it in from the '
        'generator, or use "Save to profile" after entering parts here.',
      );
      return;
    }
    final hasWork = _items.any((i) => !i.isBlank);
    if (hasWork) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Replace the parts listed here?'),
          content: const Text(
            'This list already has parts. Copying from the generator\'s '
            'profile replaces them.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep mine'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Replace'),
            ),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    final copy = MaterialListOps.cloneWithNewIds(source);
    _change(copy);
    setState(() => _open
      ..clear()
      ..addAll([for (final i in copy) i.slot]));
    AppSnackBar.success(context, 'Copied ${copy.length} parts from the profile.');
  }

  Future<void> _saveToProfile() async {
    final profile = widget.profileOwner;
    if (profile == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update the generator\'s profile?'),
        content: const Text(
          'The parts listed here become what this generator takes, for every '
          'future inspection and maintenance.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Update profile'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    final forProfile = MaterialListOps.cloneWithNewIds(
      MaterialListOps.forSaving(_items),
    );
    await _repo.save(profile, forProfile);
    ref.invalidate(materialItemsProvider(profile));
    AppSnackBar.successOn(messenger, 'Generator profile updated.');
  }

  final Set<String> _usageBusy = {};

  /// "Mark used" / "Undo": records (or reverses) the stock issue for one
  /// item, and saves the item straight away so the mark and the ledger entry
  /// cannot drift apart.
  Future<void> _toggleUsed(MaterialItem shown) async {
    if (!_usageBusy.add(shown.id)) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final current = _items.firstWhere((i) => i.id == shown.id,
          orElse: () => shown);
      final service = ref.read(materialUsageServiceProvider);
      final result = current.usedMovementId == null
          ? await service.markUsed(_owner, current)
          : await service.undoUsed(_owner, current);
      if (!mounted) return;
      _change(MaterialListOps.update(_items, result.item));
      await _flush();
      ref.invalidate(stockLevelsProvider);
      ref.invalidate(partMovementsProvider);
      AppSnackBar.infoOn(messenger, result.message);
    } catch (_) {
      AppSnackBar.errorOn(
          messenger, 'Could not update the stock. Try again.');
    } finally {
      _usageBusy.remove(shown.id);
    }
  }

  Future<void> _pickDate(MaterialItem item) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: item.dateUsed ?? now,
      firstDate: DateTime(now.year - 25),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: widget.mode.dateLabel,
    );
    if (picked != null) {
      _change(MaterialListOps.update(_items, item.copyWith(dateUsed: picked)));
    }
  }

  // --------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const LoadingIndicator();

    final theme = Theme.of(context);
    final due = MaterialListOps.needed(_items).length;
    final canCopy = widget.profileOwner != null && !widget.readOnly;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canCopy || (due > 0 && widget.mode == MaterialsMode.inspection))
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (canCopy)
                  OutlinedButton.icon(
                    onPressed: _copyFromProfile,
                    icon: const Icon(Icons.content_copy_outlined),
                    label: const Text('Copy from generator profile'),
                  ),
                if (canCopy && widget.canEditProfile)
                  OutlinedButton.icon(
                    onPressed: _saveToProfile,
                    icon: const Icon(Icons.bookmark_add_outlined),
                    label: const Text('Save to profile'),
                  ),
                // Technicians cannot change the profile; they propose.
                if (canCopy && !widget.canEditProfile)
                  OutlinedButton.icon(
                    key: const ValueKey('propose_to_profile'),
                    onPressed: () => proposeJobListToProfile(
                      context,
                      ref,
                      profile: widget.profileOwner!,
                      jobItems: _items,
                    ),
                    icon: const Icon(Icons.outgoing_mail),
                    label: const Text('Propose to profile'),
                  ),
                if (due > 0 && widget.mode == MaterialsMode.inspection)
                  StatusChip(
                    label: due == 1
                        ? '1 part due for replacement'
                        : '$due parts due for replacement',
                    tone: StatusTone.warning,
                    icon: Icons.build_outlined,
                  ),
              ],
            ),
          ),
        for (final slot in MaterialSlot.values) _slotCard(context, theme, slot),
      ],
    );
  }

  Widget _slotCard(BuildContext context, ThemeData theme, MaterialSlot slot) {
    final scheme = theme.colorScheme;
    final items = MaterialListOps.forSlot(_items, slot);
    final open = _open.contains(slot);
    final recorded = items.where((i) => !i.isBlank).length;
    final dueHere = items.where((i) => i.needsReplacement).length;
    final canAdd = !widget.readOnly && (slot.multiple || items.isEmpty);

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            label: '${slot.label}, '
                '${recorded == 0 ? 'nothing recorded' : '$recorded recorded'}',
            excludeSemantics: true,
            child: InkWell(
              borderRadius: AppRadius.cardAll,
              onTap: () => setState(() {
                open ? _open.remove(slot) : _open.add(slot);
              }),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      Icon(slot.icon, color: scheme.primary),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          slot.label,
                          style: theme.textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (dueHere > 0)
                        const Padding(
                          padding: EdgeInsets.only(right: AppSpacing.sm),
                          child: StatusChip(
                            label: 'Due',
                            tone: StatusTone.warning,
                          ),
                        ),
                      if (recorded > 0)
                        Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.sm),
                          child: StatusChip(
                            label: recorded == 1 ? 'Recorded' : '$recorded parts',
                            tone: StatusTone.success,
                            icon: Icons.check_circle_outline,
                          ),
                        ),
                      Icon(open ? Icons.expand_less : Icons.expand_more),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (open) ...[
            Divider(height: 1, color: scheme.outlineVariant),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (items.isEmpty)
                    Text(
                      widget.readOnly ? 'Nothing recorded.' : 'Nothing recorded yet.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  for (final item in items)
                    _ItemRow(
                      key: ValueKey(item.id),
                      item: item,
                      mode: widget.mode,
                      readOnly: widget.readOnly,
                      showRole: slot.multiple && slot.usesRoles,
                      onChanged: (changed) =>
                          _change(MaterialListOps.update(_items, changed)),
                      onRole: (role) => _change(
                          MaterialListOps.setRole(_items, item.id, role)),
                      onRemove: () =>
                          _change(MaterialListOps.remove(_items, item.id)),
                      onPickDate: () => _pickDate(item),
                      usedOn: widget.mode != MaterialsMode.profile
                          ? 0
                          : ref
                                  .watch(generatorPartUsageProvider(
                                      _owner.key))
                                  .value?[partKey(item.partNumber)] ??
                              0,
                      onToggleUsed: widget.mode == MaterialsMode.profile ||
                              widget.readOnly
                          ? null
                          : () => _toggleUsed(item),
                    ),
                  if (canAdd)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          _change(MaterialListOps.add(_items, slot));
                          setState(() => _open.add(slot));
                        },
                        icon: const Icon(Icons.add),
                        label: Text(items.isEmpty
                            ? 'Add ${slot.label.toLowerCase()}'
                            : 'Add another'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One part: part number, name, manufacturer, quantity, date used.
class _ItemRow extends ConsumerStatefulWidget {
  const _ItemRow({
    super.key,
    required this.item,
    required this.mode,
    required this.readOnly,
    required this.showRole,
    required this.onChanged,
    required this.onRole,
    required this.onRemove,
    required this.onPickDate,
    this.onToggleUsed,
    this.usedOn = 0,
  });

  final MaterialItem item;
  final MaterialsMode mode;
  final bool readOnly;
  final bool showRole;
  final ValueChanged<MaterialItem> onChanged;
  final ValueChanged<MaterialRole> onRole;
  final VoidCallback onRemove;
  final VoidCallback onPickDate;

  /// Null where "Mark used" does not apply (profiles, read-only).
  final VoidCallback? onToggleUsed;

  /// On a generator profile: how many of its jobs list this part.
  final int usedOn;

  @override
  ConsumerState<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends ConsumerState<_ItemRow> {
  /// Bumped when a catalog suggestion fills the fields, so they rebuild with
  /// the new text (TextFormField only reads initialValue once).
  int _fill = 0;

  MaterialItem get item => widget.item;
  MaterialsMode get mode => widget.mode;
  bool get readOnly => widget.readOnly;
  bool get showRole => widget.showRole;
  ValueChanged<MaterialItem> get onChanged => widget.onChanged;
  ValueChanged<MaterialRole> get onRole => widget.onRole;
  VoidCallback get onRemove => widget.onRemove;
  VoidCallback get onPickDate => widget.onPickDate;

  void _useCatalogPart(CatalogPart p) {
    setState(() => _fill++);
    onChanged(item.copyWith(
      partNumber: p.partNumber,
      partName: p.name.isNotEmpty ? p.name : item.partName,
      manufacturer: p.manufacturer.isNotEmpty ? p.manufacturer : item.manufacturer,
    ));
  }

  /// Catalog matches for what is typed in the part number, and the stock of an
  /// exact match. Empty when nothing useful to show.
  Widget _catalogHints(BuildContext context) {
    final typed = item.partNumber.trim();
    if (readOnly || partKey(typed).length < 2) return const SizedBox.shrink();
    final levels = ref.watch(stockLevelsProvider).value;
    if (levels == null) return const SizedBox.shrink();

    final parts = [for (final l in levels) l.part];
    final exact = findPartByNumber(parts, typed);
    final theme = Theme.of(context);

    if (exact != null) {
      final level = levels.firstWhere((l) => l.part.id == exact.id);
      final tone = level.status == StockStatus.ok
          ? StatusTone.success
          : level.status == StockStatus.low
              ? StatusTone.warning
              : StatusTone.danger;
      return Padding(
        padding: const EdgeInsets.only(top: AppSpacing.sm),
        child: Align(
          alignment: Alignment.centerLeft,
          child: StatusChip(
            label: level.onHand > 0
                ? 'In stock: ${level.available}'
                : 'Not in stock',
            tone: tone,
            icon: Icons.warehouse_outlined,
          ),
        ),
      );
    }

    final matches = searchParts(
      parts.where((p) => p.slot == null || p.slot == item.slot),
      typed,
      limit: 4,
    );
    if (matches.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          for (final p in matches)
            ActionChip(
              key: ValueKey('${item.id}-suggest-${p.id}'),
              avatar: const Icon(Icons.inventory_2_outlined, size: 16),
              label: Text(
                p.name.isEmpty ? p.partNumber : '${p.partNumber} · ${p.name}',
                style: theme.textTheme.labelMedium,
              ),
              onPressed: () => _useCatalogPart(p),
            ),
        ],
      ),
    );
  }

  InputDecoration _dec(String label, {IconData? icon}) => InputDecoration(
        labelText: label,
        prefixIcon: icon == null ? null : Icon(icon, size: 20),
        isDense: true,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final partNumber = TextFormField(
      key: ValueKey('${item.id}-pn-$_fill'),
      initialValue: item.partNumber,
      readOnly: readOnly,
      textCapitalization: TextCapitalization.characters,
      decoration: _dec('Part number', icon: Icons.tag),
      onChanged: (v) => onChanged(item.copyWith(partNumber: v.trim())),
    );
    final partName = TextFormField(
      key: ValueKey('${item.id}-name-$_fill'),
      initialValue: item.partName,
      readOnly: readOnly,
      textCapitalization: TextCapitalization.words,
      decoration: _dec('Part name'),
      onChanged: (v) => onChanged(item.copyWith(partName: v.trim())),
    );
    final maker = TextFormField(
      key: ValueKey('${item.id}-mfr-$_fill'),
      initialValue: item.manufacturer,
      readOnly: readOnly,
      textCapitalization: TextCapitalization.words,
      decoration: _dec('Manufacturer'),
      onChanged: (v) => onChanged(item.copyWith(manufacturer: v.trim())),
    );
    final quantity = _QuantityStepper(
      value: item.quantity,
      enabled: !readOnly,
      onChanged: (q) => onChanged(item.copyWith(quantity: q)),
    );
    final date = _DateButton(
      label: mode.dateLabel,
      value: item.dateUsed,
      enabled: !readOnly,
      onTap: onPickDate,
      onClear: () => onChanged(item.copyWith(dateUsed: null)),
    );

    // A Material, not a coloured Container: the switch row below is a ListTile,
    // whose ink would be hidden behind a plain background colour.
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppRadius.field),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: LayoutBuilder(
        builder: (context, c) {
          final wide = c.maxWidth >= 640;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (showRole)
                    Expanded(
                      child: SegmentedButton<MaterialRole>(
                        showSelectedIcon: false,
                        emptySelectionAllowed: true,
                        style: const ButtonStyle(
                          visualDensity: VisualDensity.compact,
                        ),
                        segments: const [
                          ButtonSegment(
                              value: MaterialRole.primary,
                              label: Text('Primary')),
                          ButtonSegment(
                              value: MaterialRole.secondary,
                              label: Text('Secondary')),
                        ],
                        selected: item.role == MaterialRole.none
                            ? <MaterialRole>{}
                            : {item.role},
                        onSelectionChanged: readOnly
                            ? null
                            : (s) {
                                if (s.isNotEmpty) onRole(s.first);
                              },
                      ),
                    )
                  else
                    const Spacer(),
                  if (!readOnly)
                    IconButton(
                      tooltip: 'Remove this part',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: onRemove,
                    ),
                ],
              ),
              if (widget.usedOn > 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    usedOnLabel(widget.usedOn),
                    key: ValueKey('${item.id}-used-on'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),
              if (wide) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [partNumber, _catalogHints(context)],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(flex: 3, child: partName),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(flex: 2, child: maker),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    quantity,
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: date),
                  ],
                ),
              ] else ...[
                partNumber,
                _catalogHints(context),
                const SizedBox(height: AppSpacing.md),
                partName,
                const SizedBox(height: AppSpacing.md),
                maker,
                const SizedBox(height: AppSpacing.md),
                quantity,
                const SizedBox(height: AppSpacing.md),
                date,
              ],
              if (widget.onToggleUsed != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (item.usedMovementId == null)
                        OutlinedButton.icon(
                          key: ValueKey('${item.id}-mark-used'),
                          onPressed: item.isBlank ? null : widget.onToggleUsed,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Mark used'),
                        )
                      else ...[
                        const StatusChip(
                          label: 'Used - stock updated',
                          tone: StatusTone.success,
                          icon: Icons.check_circle,
                        ),
                        TextButton.icon(
                          key: ValueKey('${item.id}-undo-used'),
                          onPressed: widget.onToggleUsed,
                          icon: const Icon(Icons.undo),
                          label: const Text('Undo'),
                        ),
                      ],
                    ],
                  ),
                ),
              if (mode == MaterialsMode.inspection)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: const Text('Needs replacement'),
                  subtitle: const Text('Adds this part to the follow-up job'),
                  value: item.needsReplacement,
                  onChanged: readOnly
                      ? null
                      : (v) => onChanged(item.copyWith(needsReplacement: v)),
                ),
              TextFormField(
                key: ValueKey('${item.id}-notes'),
                initialValue: item.notes,
                readOnly: readOnly,
                decoration: _dec('Notes (optional)'),
                onChanged: (v) => onChanged(item.copyWith(notes: v)),
              ),
            ],
          );
        },
          ),
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  const _QuantityStepper({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: 'Quantity $value',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Qty', style: theme.textTheme.labelLarge),
          const SizedBox(width: AppSpacing.sm),
          IconButton.outlined(
            tooltip: 'Fewer',
            onPressed: enabled && value > 0 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton.outlined(
            tooltip: 'More',
            onPressed: enabled ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = value == null ? 'Not recorded' : formatMaterialDate(value!);
    return Semantics(
      button: enabled,
      label: '$label, $text',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.field),
        onTap: enabled ? onTap : null,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            prefixIcon: const Icon(Icons.event_outlined, size: 20),
            suffixIcon: value != null && enabled
                ? IconButton(
                    tooltip: 'Clear date',
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: onClear,
                  )
                : null,
          ),
          child: Text(
            text,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: value == null ? theme.colorScheme.onSurfaceVariant : null,
            ),
          ),
        ),
      ),
    );
  }
}
