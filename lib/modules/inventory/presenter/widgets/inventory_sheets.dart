import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../materials/domain/material_item.dart';
import '../../domain/catalog_part.dart';
import '../../domain/stock.dart';
import '../../domain/vendor.dart';
import '../../infra/inventory_repository.dart';
import '../../infra/part_image_store.dart';
import '../../infra/pricing_repository.dart';
import '../inventory_access.dart';
import 'part_image.dart';

void _refresh(WidgetRef ref) {
  ref.invalidate(stockLevelsProvider);
  ref.invalidate(catalogPartsProvider);
  ref.invalidate(partMovementsProvider);
}

/// Add a part (when [part] is null) or edit one. Admin only; callers check.
Future<void> showPartEditorSheet(
  BuildContext context,
  WidgetRef ref, {
  CatalogPart? part,
  String? initialNumber,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) =>
        _PartEditor(part: part, ref: ref, initialNumber: initialNumber),
  );
}

class _PartEditor extends StatefulWidget {
  const _PartEditor(
      {required this.part, required this.ref, this.initialNumber});

  final CatalogPart? part;
  final WidgetRef ref;

  /// Prefills the part number of a new part (a scanned barcode).
  final String? initialNumber;

  @override
  State<_PartEditor> createState() => _PartEditorState();
}

class _PartEditorState extends State<_PartEditor> {
  late final _number = TextEditingController(
      text: widget.part?.partNumber ?? widget.initialNumber);
  late final _name = TextEditingController(text: widget.part?.name);
  late final _mfr = TextEditingController(text: widget.part?.manufacturer);
  late final _min =
      TextEditingController(text: '${widget.part?.minStock ?? 0}');
  late final _alts =
      TextEditingController(text: widget.part?.altPartNumbers.join(', '));
  late final _notes = TextEditingController(text: widget.part?.notes);
  late MaterialSlot? _slot = widget.part?.slot;
  late bool _active = widget.part?.isActive ?? true;
  String? _error;
  bool _saving = false;

  /// A photo chosen in this editor, not saved yet.
  Uint8List? _newImage;
  bool _removeImage = false;

  bool get _hasImage =>
      _newImage != null || (!_removeImage && widget.part?.imagePath != null);

  Future<void> _pickImage(PartImageSource source) async {
    try {
      final bytes = await widget.ref.read(partImagePickerProvider).pick(source);
      if (bytes == null || !mounted) return;
      setState(() {
        _newImage = bytes;
        _removeImage = false;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not get that photo.');
    }
  }

  Future<void> _choosePhoto() async {
    final source = await showModalBottomSheet<PartImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            key: const Key('photo_camera'),
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Take a photo'),
            onTap: () => Navigator.pop(ctx, PartImageSource.camera),
          ),
          ListTile(
            key: const Key('photo_gallery'),
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Choose from gallery'),
            onTap: () => Navigator.pop(ctx, PartImageSource.gallery),
          ),
        ]),
      ),
    );
    if (source != null) await _pickImage(source);
  }

  Widget _photoSection(ThemeData theme) {
    final part = widget.part;
    final Widget preview;
    if (_newImage != null) {
      preview = Image.memory(_newImage!,
          key: const Key('part_photo_preview'),
          fit: BoxFit.cover,
          cacheWidth: 256,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined));
    } else if (part != null && !_removeImage) {
      preview = PartImage(part: part);
    } else {
      preview = ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(Icons.inventory_2_outlined,
              color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }
    return Row(children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.square(dimension: 72, child: preview),
      ),
      const SizedBox(width: AppSpacing.md),
      Expanded(
        child: Wrap(spacing: AppSpacing.sm, children: [
          OutlinedButton.icon(
            key: const Key('part_photo_add'),
            onPressed: _saving ? null : _choosePhoto,
            icon: const Icon(Icons.add_a_photo_outlined, size: 18),
            label: Text(_hasImage ? 'Replace' : 'Add photo'),
          ),
          if (_hasImage)
            TextButton(
              key: const Key('part_photo_remove'),
              onPressed: _saving
                  ? null
                  : () => setState(() {
                        _newImage = null;
                        _removeImage = true;
                      }),
              child: const Text('Remove'),
            ),
        ]),
      ),
    ]);
  }

  @override
  void dispose() {
    for (final c in [_number, _name, _mfr, _min, _alts, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (partKey(_number.text).isEmpty) {
      setState(() => _error = 'Enter a part number.');
      return;
    }
    final repo = widget.ref.read(inventoryRepositoryProvider);
    final alts = _alts.text
        .split(RegExp(r'[,\n;]'))
        .map((a) => a.trim())
        .where((a) => a.isNotEmpty)
        .toList();
    final existing = widget.part;
    final base = existing ??
        repo.newPart(partNumber: _number.text);
    var next = base.copyWith(
      partNumber: _number.text,
      name: _name.text,
      manufacturer: _mfr.text,
      slot: _slot,
      minStock: int.tryParse(_min.text.trim()) ?? 0,
      altPartNumbers: alts,
      notes: _notes.text.trim(),
      isActive: _active,
    );
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final store = widget.ref.read(partImageStoreProvider);
      if (_newImage != null) {
        final path = await store.save(next, _newImage!);
        next = next.copyWith(imagePath: path);
      } else if (_removeImage && next.imagePath != null) {
        await store.remove(next);
        next = next.copyWith(imagePath: null);
      }
      await repo.savePart(next);
      _refresh(widget.ref);
      AppSnackBar.successOn(messenger, existing == null ? 'Part added' : 'Part saved');
      nav.pop();
    } on DuplicatePartException catch (e) {
      setState(() {
        _saving = false;
        _error = '${e.existing.partNumber} is already in the catalog.';
      });
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'Could not save the part. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.part == null ? 'Add part' : 'Edit part',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            if (widget.ref.read(canManageInventoryProvider)) ...[
              _photoSection(theme),
              const SizedBox(height: AppSpacing.md),
            ],
            TextField(
              key: const Key('part_number'),
              controller: _number,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Part number *'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('part_name'),
              controller: _name,
              minLines: 2,
              maxLines: 3,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'e.g. Fleetguard lube filter, spin-on, 4.5" tall',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('part_manufacturer'),
              controller: _mfr,
              decoration: const InputDecoration(labelText: 'Manufacturer'),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<MaterialSlot?>(
              isExpanded: true,
              initialValue: _slot,
              decoration: const InputDecoration(labelText: 'Fits'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Any / general')),
                for (final s in MaterialSlot.values)
                  DropdownMenuItem(value: s, child: Text(s.label)),
              ],
              onChanged: (v) => setState(() => _slot = v),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('part_min'),
              controller: _min,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Minimum stock',
                helperText: 'Shows as Low at or below this. 0 = no minimum.',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('part_alts'),
              controller: _alts,
              decoration: const InputDecoration(
                labelText: 'Alternate part numbers',
                helperText: 'Separate with commas',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              subtitle: const Text('Inactive parts are hidden from stock and search'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(_error!,
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
            FilledButton(
              key: const Key('part_save'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}

enum StockAction {
  receive('Receive stock', 'Quantity received', 'Add to what is on the shelf'),
  adjust('Adjust', 'Change (use − to remove)',
      'Correct the count by a difference, with a reason'),
  count('Count', 'Counted on the shelf',
      'Set the count; the difference is recorded');

  const StockAction(this.title, this.field, this.help);

  final String title;
  final String field;
  final String help;
}

/// Receive / adjust / count for one part. Admin only; callers check.
Future<void> showStockActionSheet(
  BuildContext context,
  WidgetRef ref, {
  required StockLevel level,
  required StockAction action,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _StockActionSheet(level: level, action: action, ref: ref),
  );
}

class _StockActionSheet extends StatefulWidget {
  const _StockActionSheet(
      {required this.level, required this.action, required this.ref});

  final StockLevel level;
  final StockAction action;
  final WidgetRef ref;

  @override
  State<_StockActionSheet> createState() => _StockActionSheetState();
}

class _StockActionSheetState extends State<_StockActionSheet> {
  final _qty = TextEditingController();
  final _note = TextEditingController();
  final _cost = TextEditingController();
  List<Vendor> _vendors = const [];
  String? _vendorId;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.action == StockAction.receive) {
      widget.ref.read(pricingRepositoryProvider).vendors().then((v) {
        if (mounted) setState(() => _vendors = v.where((x) => x.isActive).toList());
      });
    }
  }

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final n = int.tryParse(_qty.text.trim());
    final a = widget.action;
    if (n == null) {
      setState(() => _error = 'Enter a whole number.');
      return;
    }
    if (a == StockAction.receive && n <= 0) {
      setState(() => _error = 'Enter how many arrived.');
      return;
    }
    if (a == StockAction.count && n < 0) {
      setState(() => _error = 'A count cannot be negative.');
      return;
    }
    if (a == StockAction.adjust && n == 0) {
      setState(() => _error = 'Enter the change, such as -2 or 3.');
      return;
    }
    if (a == StockAction.adjust && _note.text.trim().isEmpty) {
      setState(() => _error = 'Say why, so the change can be traced.');
      return;
    }
    // A price needs a vendor, and a vendor with a price is worth recording.
    final cost = _cost.text.trim().isEmpty ? null : parseCents(_cost.text);
    if (a == StockAction.receive) {
      if (_cost.text.trim().isNotEmpty && (cost == null || cost <= 0)) {
        setState(() => _error = 'Enter the price for one, such as 24.50.');
        return;
      }
      if (cost != null && _vendorId == null) {
        setState(() => _error = 'Choose the vendor this price is from.');
        return;
      }
    }
    final repo = widget.ref.read(inventoryRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final id = widget.level.part.id;
      switch (a) {
        case StockAction.receive:
          await repo.record(
              partId: id, qty: n, reason: MovementReason.receive, note: _note.text);
          if (cost != null && _vendorId != null) {
            await widget.ref.read(pricingRepositoryProvider).addPrice(
                  partId: id,
                  vendorId: _vendorId!,
                  unitCents: cost,
                  note: _note.text,
                );
            widget.ref.invalidate(allPricesProvider);
            widget.ref.invalidate(partPricesProvider);
          }
        case StockAction.adjust:
          await repo.record(
              partId: id, qty: n, reason: MovementReason.adjust, note: _note.text);
        case StockAction.count:
          await repo.recordCount(id, n, note: _note.text);
      }
      _refresh(widget.ref);
      AppSnackBar.successOn(messenger, '${a.title} saved');
      nav.pop();
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'Could not save. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final a = widget.action;
    final p = widget.level.part;
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(a.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text('${p.partNumber} · ${p.title} — ${widget.level.onHand} on hand',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: AppSpacing.xs),
          Text(a.help, style: theme.textTheme.bodySmall),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('stock_qty'),
            controller: _qty,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                  a == StockAction.adjust ? RegExp(r'^-?\d*') : RegExp(r'\d*')),
            ],
            decoration: InputDecoration(labelText: a.field),
          ),
          if (a == StockAction.receive && _vendors.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  key: const Key('receive_vendor'),
                  initialValue: _vendorId,
                  decoration: const InputDecoration(labelText: 'Vendor'),
                  items: [
                    for (final v in _vendors)
                      DropdownMenuItem(value: v.id, child: Text(v.name)),
                  ],
                  onChanged: (v) => setState(() => _vendorId = v),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                flex: 2,
                child: TextField(
                  key: const Key('receive_cost'),
                  controller: _cost,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.,$]')),
                  ],
                  decoration: const InputDecoration(
                      labelText: 'Price for one', prefixText: r'$ '),
                ),
              ),
            ]),
          ],
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('stock_note'),
            controller: _note,
            decoration: InputDecoration(
              labelText: a == StockAction.adjust ? 'Reason *' : 'Note',
              helperText: a == StockAction.receive
                  ? 'Supplier, invoice or PO number'
                  : null,
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('stock_save'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    );
  }
}
