import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../materials/domain/material_item.dart';
import '../../../materials/infra/materials_repository.dart';
import '../../domain/import/parts_import.dart';
import '../../domain/import/sheet_reader.dart';
import '../../infra/inventory_repository.dart';
import '../../infra/parts_import_service.dart';

/// Picks an .xlsx or .csv file, cleans it and opens the preview. Nothing is
/// saved until the admin confirms in the preview.
Future<void> startPartsImport(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final picked = await FilePicker.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['xlsx', 'csv'],
  );
  if (picked.isEmpty) return;
  final file = picked.first;
  final Uint8List bytes;
  try {
    bytes = await file.readAsBytes();
  } catch (_) {
    AppSnackBar.errorOn(messenger, 'That file could not be opened.');
    return;
  }
  try {
    final parsed = parseInventorySheets(readSpreadsheet(bytes, fileName: file.name));
    if (!context.mounted) return;
    await showPartsImportPreview(context, ref, parsed, fileName: file.name);
  } on SheetReadException catch (e) {
    AppSnackBar.errorOn(messenger, e.message);
  } catch (_) {
    AppSnackBar.errorOn(messenger, 'That file could not be read.');
  }
}

Future<void> showPartsImportPreview(
  BuildContext context,
  WidgetRef ref,
  ParsedImport parsed, {
  required String fileName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 760),
    builder: (_) => PartsImportPreview(parsed: parsed, fileName: fileName),
  );
}

enum _View { all, attention, fresh, generators }

/// The cleaned result: what will be added, what already exists, what was left
/// out and why. The admin unticks anything they do not want, then imports.
class PartsImportPreview extends ConsumerStatefulWidget {
  const PartsImportPreview({super.key, required this.parsed, required this.fileName});

  final ParsedImport parsed;
  final String fileName;

  @override
  ConsumerState<PartsImportPreview> createState() => _PartsImportPreviewState();
}

class _PartsImportPreviewState extends ConsumerState<PartsImportPreview> {
  List<PlannedPart>? _plan;
  final _selected = <String>{};
  final _genSelected = <String>{};
  Set<String> _genHave = {};
  var _view = _View.all;
  var _openingStock = true;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final catalog = await ref.read(inventoryRepositoryProvider).parts();
    final plan = planImport(widget.parsed.parts, catalog);
    final have = await generatorsWithProfile(
        ref.read(materialsRepositoryProvider), widget.parsed.generators);
    if (!mounted) return;
    setState(() {
      _plan = plan;
      _genHave = have;
      _genSelected
        ..clear()
        ..addAll(widget.parsed.generators
            .where((g) => !have.contains(g.key))
            .map((g) => g.key));
      _selected
        ..clear()
        ..addAll(plan
            .where((p) => p.action != ImportAction.same)
            .map((p) => p.part.key));
    });
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    final r = await applyImport(
      ref.read(inventoryRepositoryProvider),
      _plan!,
      selected: _selected,
      openingStock: _openingStock,
    );
    final g = await applyGeneratorProfiles(
      ref.read(materialsRepositoryProvider),
      widget.parsed.generators,
      selected: _genSelected,
    );
    ref.invalidate(catalogPartsProvider);
    ref.invalidate(stockLevelsProvider);
    nav.pop();
    final bits = [
      if (r.added > 0) '${r.added} added',
      if (r.filled > 0) '${r.filled} updated',
      if (r.stocked > 0) '${r.stocked} with opening stock',
      if (g.saved > 0) '${g.saved} generator lists',
    ];
    final failures = r.failed.length + g.failed.length;
    if (failures > 0) {
      AppSnackBar.errorOn(messenger,
          '${bits.isEmpty ? 'Nothing imported' : bits.join(', ')}. $failures could not be saved.');
    } else {
      AppSnackBar.successOn(messenger, bits.isEmpty ? 'Nothing to import' : 'Imported: ${bits.join(', ')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final plan = _plan;
    final height = MediaQuery.sizeOf(context).height;
    final parsed = widget.parsed;

    return SizedBox(
      height: height * 0.9,
      child: plan == null
          ? const Center(child: CircularProgressIndicator())
          : _body(context, theme, plan, parsed),
    );
  }

  Widget _body(BuildContext context, ThemeData theme, List<PlannedPart> plan,
      ParsedImport parsed) {
    final adds = plan.where((p) => p.action == ImportAction.add).length;
    final fills = plan.where((p) => p.action == ImportAction.fill).length;
    final same = plan.where((p) => p.action == ImportAction.same).length;
    final hasStock = plan.any((p) =>
        p.action == ImportAction.add && (p.part.openingQty ?? 0) > 0);
    final shown = plan.where((p) {
      switch (_view) {
        case _View.all:
          return true;
        case _View.attention:
          return p.part.issues.isNotEmpty;
        case _View.fresh:
          return p.action == ImportAction.add;
        case _View.generators:
          return false;
      }
    }).toList();
    final chosen = _selected.length + _genSelected.length;
    final gens = parsed.generators;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Import parts', style: theme.textTheme.titleLarge),
              Text(widget.fileName,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.md),
              Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
                StatusChip(label: '$adds new', tone: StatusTone.success),
                if (fills > 0)
                  StatusChip(label: '$fills to update', tone: StatusTone.info),
                if (same > 0) StatusChip(label: '$same already there'),
                if (gens.isNotEmpty)
                  StatusChip(
                      label: '${gens.length} generators', tone: StatusTone.info),
                if (parsed.skipped.isNotEmpty)
                  StatusChip(
                      label: '${parsed.skipped.length} left out',
                      tone: StatusTone.warning),
              ]),
              const SizedBox(height: AppSpacing.sm),
              for (final e in parsed.sheetsRead.entries)
                Text('Read “${e.key}” — ${e.value}',
                    style: theme.textTheme.bodySmall),
              for (final e in parsed.sheetsIgnored.entries)
                Text('Skipped “${e.key}” — ${e.value}',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<_View>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: _View.all, label: Text('All ${plan.length}')),
                  ButtonSegment(
                      value: _View.attention,
                      label: Text(
                          'Check ${plan.where((p) => p.part.issues.isNotEmpty).length}')),
                  ButtonSegment(value: _View.fresh, label: Text('New $adds')),
                  if (gens.isNotEmpty)
                    ButtonSegment(
                        value: _View.generators,
                        label: Text('Generators ${gens.length}')),
                ],
                selected: {_view},
                onSelectionChanged: (s) => setState(() => _view = s.first),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            children: [
              if (plan.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: Text('No parts were found in this file. Check that it '
                      'has a “Part Number” column.'),
                ),
              if (_view == _View.generators)
                for (final g in gens) _genRow(theme, g)
              else
                for (final p in shown) _row(theme, p),
              if (parsed.skipped.isNotEmpty)
                ExpansionTile(
                  key: const Key('import_skipped'),
                  title: Text('${parsed.skipped.length} left out'),
                  children: [
                    for (final s in parsed.skipped)
                      ListTile(
                        dense: true,
                        title: Text(s.value.isEmpty ? '(blank)' : s.value),
                        subtitle: Text('${s.sheet}, row ${s.row} — ${s.reason}'),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasStock)
                CheckboxListTile(
                  key: const Key('import_opening_stock'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: _openingStock,
                  onChanged: (v) => setState(() => _openingStock = v ?? false),
                  title: const Text('Record quantities as opening stock'),
                ),
              Row(children: [
                Expanded(
                  child: Text(
                    'Existing parts keep what they have; only blank fields are filled.',
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                FilledButton(
                  key: const Key('import_confirm'),
                  onPressed: _busy || chosen == 0 ? null : _import,
                  child: Text(_busy
                      ? 'Importing…'
                      : _genSelected.isEmpty
                          ? 'Import $chosen'
                          : 'Import ${_selected.length} parts + ${_genSelected.length} lists'),
                ),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(ThemeData theme, PlannedPart item) {
    final p = item.part;
    final selectable = item.action != ImportAction.same;
    final detail = [
      if (p.name.isNotEmpty && p.name != p.slot?.label) p.name,
      if (p.manufacturer.isNotEmpty) p.manufacturer,
      if (p.slot != null) p.slot!.label,
      if (p.uses > 1) 'listed ${p.uses}×',
      if (p.openingQty != null) 'qty ${p.openingQty}',
    ].join(' · ');
    final label = switch (item.action) {
      ImportAction.add => const StatusChip(label: 'New', tone: StatusTone.success),
      ImportAction.fill =>
        StatusChip(label: 'Fill ${item.fills.join(', ')}', tone: StatusTone.info),
      ImportAction.same => const StatusChip(label: 'Already there'),
    };
    return CheckboxListTile(
      key: ValueKey('import_row_${p.key}'),
      value: _selected.contains(p.key),
      onChanged: selectable
          ? (v) => setState(() {
                if (v == true) {
                  _selected.add(p.key);
                } else {
                  _selected.remove(p.key);
                }
              })
          : null,
      controlAffinity: ListTileControlAffinity.leading,
      title: Row(children: [
        Flexible(
          child: Text(p.partNumber,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ),
        const SizedBox(width: AppSpacing.sm),
        label,
      ]),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (detail.isNotEmpty) Text(detail),
          for (final i in p.issues)
            Text(i.message,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.tertiary)),
        ],
      ),
    );
  }

  Widget _genRow(ThemeData theme, GeneratorImport g) {
    final have = _genHave.contains(g.key);
    final bySlot = <MaterialSlot, int>{};
    for (final i in g.items) {
      bySlot[i.slot] = (bySlot[i.slot] ?? 0) + 1;
    }
    return CheckboxListTile(
      key: ValueKey('import_gen_${g.key}'),
      value: _genSelected.contains(g.key),
      onChanged: have
          ? null
          : (v) => setState(() {
                if (v == true) {
                  _genSelected.add(g.key);
                } else {
                  _genSelected.remove(g.key);
                }
              }),
      controlAffinity: ListTileControlAffinity.leading,
      title: Row(children: [
        Flexible(
          child: Text(
            [g.site, g.title].where((s) => s.isNotEmpty).join(' · '),
            style: const TextStyle(fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        have
            ? const StatusChip(label: 'Has a list')
            : const StatusChip(label: 'New list', tone: StatusTone.success),
      ]),
      subtitle: Text([
        if (g.serial.isNotEmpty) 'SN ${g.serial}',
        '${g.items.length} parts in ${bySlot.length} slots',
      ].join(' · ')),
    );
  }
}
