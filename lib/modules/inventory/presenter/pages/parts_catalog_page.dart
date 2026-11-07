import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_page.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/lazy_head_list.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/catalog_part.dart';
import '../../infra/inventory_repository.dart';
import '../inventory_access.dart';
import '../widgets/inventory_sheets.dart';
import '../widgets/part_scan_button.dart';
import '../widgets/parts_import_sheet.dart';

/// Every part the company uses: number, name, manufacturer, alternates.
/// Everyone can browse; admins add and edit.
class PartsCatalogPage extends ConsumerStatefulWidget {
  const PartsCatalogPage({super.key});

  @override
  ConsumerState<PartsCatalogPage> createState() => _PartsCatalogPageState();
}

class _PartsCatalogPageState extends ConsumerState<PartsCatalogPage> {
  String _query = '';
  final _searchCtl = TextEditingController();

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  /// Fills the search with a scanned code; an exact part number (or
  /// alternate) opens the editor for admins, no match offers admins to add it.
  Future<void> _onScanned(String code) async {
    _searchCtl.text = code;
    setState(() => _query = code);
    final part = await findScannedPart(ref, code);
    if (!mounted) return;
    if (part != null) {
      if (ref.read(canManageInventoryProvider)) {
        await showPartEditorSheet(context, ref, part: part);
      }
      return;
    }
    await offerAddScannedPart(context, ref, code);
  }

  @override
  Widget build(BuildContext context) {
    final parts = ref.watch(catalogPartsProvider);
    final canManage = ref.watch(canManageInventoryProvider);
    final theme = Theme.of(context);

    return AppPage(
      title: 'Parts Catalog',
      fab: canManage
          ? FloatingActionButton.extended(
              key: const Key('add_part'),
              onPressed: () => showPartEditorSheet(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add part'),
            )
          : null,
      body: parts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState.error(
          message: 'The catalog could not be loaded.',
          action: TextButton(
            onPressed: () => ref.invalidate(catalogPartsProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (all) {
          final q = _query.trim();
          final shown = q.isEmpty
              ? (List.of(all)
                ..sort((a, b) => partKey(a.partNumber)
                    .compareTo(partKey(b.partNumber))))
              : searchParts(all, q, limit: 200, includeInactive: true);
          final rowParts = (all.isEmpty || shown.isEmpty) ? const <CatalogPart>[] : shown;
          return LazyHeadList(
            padding: const EdgeInsets.all(AppSpacing.lg),
            rowCount: rowParts.length,
            rowBuilder: (context, i) {
              final p = rowParts[i];
              return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.cardAll,
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    child: ListTile(
                      onTap: canManage
                          ? () => showPartEditorSheet(context, ref, part: p)
                          : null,
                      title: Text(p.partNumber,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        [
                          if (p.name.isNotEmpty) p.name,
                          if (p.manufacturer.isNotEmpty) p.manufacturer,
                          if (p.slot != null) p.slot!.label,
                        ].join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: p.isActive
                          ? null
                          : const StatusChip(label: 'Inactive'),
                    ),
                  );
            },
            head: [
              Row(children: [
                Expanded(
                  child: TextField(
                    key: const Key('catalog_search'),
                    controller: _searchCtl,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: 'Search part number, name or manufacturer',
                      suffixIcon: PartScanButton(onScanned: _onScanned),
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                if (canManage) ...[
                  const SizedBox(width: AppSpacing.md),
                  OutlinedButton.icon(
                    key: const Key('import_parts'),
                    onPressed: () => startPartsImport(context, ref),
                    icon: const Icon(Icons.upload_file_outlined),
                    label: const Text('Import'),
                  ),
                ],
              ]),
              const SizedBox(height: AppSpacing.md),
              if (all.isEmpty)
                EmptyState(
                  icon: Icons.menu_book_outlined,
                  title: 'The catalog is empty',
                  message: canManage
                      ? 'Add the parts you stock or use on jobs.'
                      : 'An admin adds parts here.',
                )
              else if (shown.isEmpty)
                const EmptyState(
                    icon: Icons.search_off, title: 'Nothing matches', compact: true)
            ],
          );
        },
      ),
    );
  }
}
