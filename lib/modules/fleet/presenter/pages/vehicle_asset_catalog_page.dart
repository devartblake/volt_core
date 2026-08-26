import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/sync/sync_context.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/entities/vehicle_asset_catalog_item.dart';
import '../../infra/repositories/vehicle_asset_repository.dart';
import '../fleet_providers.dart';

/// The master list of tool types. Admin only.
class VehicleAssetCatalogPage extends ConsumerWidget {
  const VehicleAssetCatalogPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(vehicleAssetCatalogAllProvider);

    return AppPage(
      title: 'Tool Catalog',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(vehicleAssetCatalogAllProvider),
        ),
      ],
      fab: FloatingActionButton.extended(
        onPressed: () => _editItem(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Add tool'),
      ),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState.error(
          message: '$error',
          action: FilledButton.tonal(
            onPressed: () => ref.invalidate(vehicleAssetCatalogAllProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.handyman_outlined,
              title: 'No tools catalogued yet',
              message: 'Add each tool type once. Vans then carry instances of '
                  'it, which is what keeps the same bender from being typed '
                  'five different ways.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final item = items[index];
              return Card(
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  onTap: () => _editItem(context, ref, item),
                  title: Text(
                    item.name,
                    style: TextStyle(
                      // Struck through rather than hidden: a deactivated tool
                      // still appears on old receipts, so it has to stay
                      // findable.
                      decoration:
                          item.isActive ? null : TextDecoration.lineThrough,
                    ),
                  ),
                  subtitle: Text(
                    [
                      if ((item.partNumber ?? '').isNotEmpty) item.partNumber!,
                      if (item.category.isNotEmpty) item.category,
                      if (!item.isActive) 'Deactivated',
                    ].join('  ·  '),
                  ),
                  trailing: const Icon(Icons.edit_outlined, size: 20),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _editItem(
    BuildContext context,
    WidgetRef ref,
    VehicleAssetCatalogItem? existing,
  ) async {
    final tenantId = SyncContext.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      AppSnackBar.error(
        context,
        'No active tenant is configured, so the catalog cannot be edited.',
      );
      return;
    }

    final saved = await showDialog<VehicleAssetCatalogItem>(
      context: context,
      builder: (_) => _CatalogItemDialog(
        item: existing ?? VehicleAssetCatalogItem.newDraft(tenantId: tenantId),
        isNew: existing == null,
      ),
    );
    if (saved == null || !context.mounted) return;

    try {
      await ref.read(vehicleAssetRepositoryProvider).saveCatalogItem(saved);
      ref.invalidate(vehicleAssetCatalogAllProvider);
      ref.invalidate(vehicleAssetCatalogProvider);
      if (context.mounted) AppSnackBar.success(context, 'Saved ${saved.name}.');
    } catch (error) {
      // Duplicate name and duplicate part number both land here, and both are
      // worth reading in full.
      if (context.mounted) AppSnackBar.error(context, '$error');
    }
  }
}

class _CatalogItemDialog extends StatefulWidget {
  const _CatalogItemDialog({required this.item, required this.isNew});

  final VehicleAssetCatalogItem item;
  final bool isNew;

  @override
  State<_CatalogItemDialog> createState() => _CatalogItemDialogState();
}

class _CatalogItemDialogState extends State<_CatalogItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late VehicleAssetCatalogItem _draft = widget.item;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isNew ? 'Add a tool' : 'Edit tool'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LabeledField(
                  label: 'Name',
                  value: _draft.name,
                  required: true,
                  autofocus: widget.isNew,
                  hint: 'IDEAL 1/2" EMT BENDER',
                  textCapitalization: TextCapitalization.characters,
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Give the tool a name.' : null,
                  onChanged: (v) => _draft = _draft.copyWith(name: v),
                ),
                LabeledField(
                  label: 'Part number',
                  value: _draft.partNumber ?? '',
                  hint: '74-031',
                  helper: 'Optional. Several tools have none.',
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (v) => _draft = _draft.copyWith(
                    partNumber: v.trim().isEmpty ? null : v,
                    clearPartNumber: v.trim().isEmpty,
                  ),
                ),
                LabeledField(
                  label: 'Category',
                  value: _draft.category,
                  hint: 'Benders',
                  textCapitalization: TextCapitalization.words,
                  onChanged: (v) => _draft = _draft.copyWith(category: v),
                ),
                LabeledField(
                  label: 'Notes',
                  value: _draft.notes,
                  maxLines: 2,
                  onChanged: (v) => _draft = _draft.copyWith(notes: v),
                ),
                if (!widget.isNew)
                  StatusSwitchTile(
                    label: 'Active',
                    icon: Icons.inventory_2_outlined,
                    value: _draft.isActive,
                    margin: const EdgeInsets.only(top: 12),
                    onChanged: (v) =>
                        setState(() => _draft = _draft.copyWith(isActive: v)),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.of(context).pop(_draft);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
