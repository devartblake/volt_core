import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/sync/sync_context.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/entities/vehicle_asset.dart';
import '../../domain/entities/vehicle_asset_catalog_item.dart';
import '../../infra/repositories/vehicle_asset_repository.dart';
import '../fleet_providers.dart';

/// The tools carried in one vehicle — one row per physical item.
class VehicleAssetsPage extends ConsumerWidget {
  const VehicleAssetsPage({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assets = ref.watch(vehicleAssetsProvider(vehicleId));
    final vehicle = ref.watch(vehicleProvider(vehicleId));
    final isManager = ref.watch(fleetManagerProvider);

    return AppPage(
      title: vehicle.asData?.value == null
          ? 'Vehicle Assets'
          : 'Assets · ${vehicle.asData!.value!.displayTitle}',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
          onPressed: () => ref.invalidate(vehicleAssetsProvider(vehicleId)),
        ),
      ],
      fab: isManager
          ? FloatingActionButton.extended(
              onPressed: () => _assign(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Add tool'),
            )
          : null,
      body: assets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState.error(
          message: '$error',
          action: FilledButton.tonal(
            onPressed: () => ref.invalidate(vehicleAssetsProvider(vehicleId)),
            child: const Text('Retry'),
          ),
        ),
        data: (list) {
          if (list.isEmpty) {
            return EmptyState(
              icon: Icons.handyman_outlined,
              title: 'No tools assigned',
              message: isManager
                  ? 'Add each tool this vehicle carries. Two identical ladders '
                      'are two rows, so a receipt can mark one missing and the '
                      'other present.'
                  : 'Nothing has been assigned to this vehicle yet.',
            );
          }

          final needing = list.where((r) => r.asset.needsAttention).length;

          return Column(
            children: [
              if (needing > 0) _AttentionBanner(count: needing),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) => _AssetTile(
                    resolved: list[index],
                    canEdit: isManager,
                    onEdit: () => _edit(context, ref, list[index]),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _assign(BuildContext context, WidgetRef ref) async {
    final tenantId = SyncContext.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      AppSnackBar.error(context, 'No active tenant is configured.');
      return;
    }

    final catalog = await ref.read(vehicleAssetCatalogProvider.future);
    if (!context.mounted) return;

    if (catalog.isEmpty) {
      // Pointing at the fix beats an empty dropdown that looks broken.
      AppSnackBar.error(
        context,
        'The tool catalog is empty. An admin adds tool types under '
        'Fleet → Tool Catalog first.',
      );
      return;
    }

    final draft = await showDialog<VehicleAsset>(
      context: context,
      builder: (_) => _AssetDialog(
        catalog: catalog,
        asset: null,
        tenantId: tenantId,
        vehicleId: vehicleId,
      ),
    );
    if (!context.mounted) return;
    await _persist(context, ref, draft);
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    ResolvedVehicleAsset resolved,
  ) async {
    final catalog = await ref.read(vehicleAssetCatalogProvider.future);
    if (!context.mounted) return;

    final draft = await showDialog<VehicleAsset>(
      context: context,
      builder: (_) => _AssetDialog(
        catalog: catalog,
        asset: resolved.asset,
        tenantId: resolved.asset.tenantId,
        vehicleId: resolved.asset.vehicleId,
        onRetire: () => Navigator.of(context).pop(
          resolved.asset.copyWith(
            retiredAt: DateTime.now().toUtc(),
            isMissing: false,
          ),
        ),
      ),
    );
    if (!context.mounted) return;
    await _persist(context, ref, draft);
  }

  Future<void> _persist(
    BuildContext context,
    WidgetRef ref,
    VehicleAsset? draft,
  ) async {
    if (draft == null || !context.mounted) return;

    try {
      await ref.read(vehicleAssetRepositoryProvider).saveAsset(draft);
      ref.invalidate(vehicleAssetsProvider(vehicleId));
      if (context.mounted) AppSnackBar.success(context, 'Saved.');
    } catch (error) {
      // A duplicate serial across vehicles lands here and names the conflict.
      if (context.mounted) AppSnackBar.error(context, '$error');
    }
  }
}

class _AttentionBanner extends StatelessWidget {
  const _AttentionBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      color: theme.colorScheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.warning_amber_outlined,
              size: 20, color: theme.colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              count == 1
                  ? '1 tool is missing or not mission capable'
                  : '$count tools are missing or not mission capable',
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  const _AssetTile({
    required this.resolved,
    required this.canEdit,
    required this.onEdit,
  });

  final ResolvedVehicleAsset resolved;
  final bool canEdit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final asset = resolved.asset;

    final flags = <String>[
      if (asset.isMissing) 'MISSING',
      if (asset.readiness == AssetReadiness.nmc) 'NMC',
    ];

    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: canEdit ? onEdit : null,
        leading: Icon(
          asset.needsAttention
              ? Icons.error_outline
              : Icons.check_circle_outline,
          color: asset.needsAttention
              ? theme.colorScheme.error
              : theme.status.success,
        ),
        title: Text(resolved.displayLabel),
        subtitle: Text(
          [
            if ((asset.serialNumber ?? '').isNotEmpty)
              'S/N ${asset.serialNumber}',
            if (flags.isEmpty) asset.readiness.description else flags.join(' · '),
          ].join('  ·  '),
          style: theme.textTheme.bodySmall?.copyWith(
            color: asset.needsAttention ? theme.colorScheme.error : null,
          ),
        ),
        trailing:
            canEdit ? const Icon(Icons.edit_outlined, size: 20) : null,
      ),
    );
  }
}

/// Assign a tool to this vehicle, or edit the one already here.
class _AssetDialog extends StatefulWidget {
  const _AssetDialog({
    required this.catalog,
    required this.asset,
    required this.tenantId,
    required this.vehicleId,
    this.onRetire,
  });

  final List<VehicleAssetCatalogItem> catalog;
  final VehicleAsset? asset;
  final String tenantId;
  final String vehicleId;
  final VoidCallback? onRetire;

  @override
  State<_AssetDialog> createState() => _AssetDialogState();
}

class _AssetDialogState extends State<_AssetDialog> {
  late VehicleAsset _draft = widget.asset ??
      VehicleAsset.newDraft(
        tenantId: widget.tenantId,
        vehicleId: widget.vehicleId,
        catalogId: widget.catalog.first.id,
      );

  bool get _isNew => widget.asset == null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isNew ? 'Add a tool to this vehicle' : 'Edit tool'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectionField<String>(
                label: 'Tool',
                value: _draft.catalogId,
                options: widget.catalog.map((i) => i.id).toList(),
                labelOf: (id) {
                  for (final item in widget.catalog) {
                    if (item.id == id) return item.displayLabel;
                  }
                  // The asset points at a catalog entry that has been
                  // deactivated or has not synced. Say so rather than showing
                  // a uuid.
                  return 'Unknown tool';
                },
                // Moving a tool to a different catalog entry would rewrite
                // history on every receipt that referenced it. Retire it and
                // add the right one instead.
                enabled: _isNew,
                onChanged: (id) {
                  if (id != null) setState(() => _draft = _rebuild(id));
                },
              ),
              LabeledField(
                label: 'Serial number',
                value: _draft.serialNumber ?? '',
                helper: 'Optional. Must be unique across the fleet.',
                textCapitalization: TextCapitalization.characters,
                onChanged: (v) => _draft = _draft.copyWith(
                  serialNumber: v.trim().isEmpty ? null : v,
                  clearSerialNumber: v.trim().isEmpty,
                ),
              ),
              SelectionField<AssetReadiness>(
                label: 'Readiness',
                value: _draft.readiness,
                options: AssetReadiness.values,
                labelOf: (r) => '${r.label} — ${r.description}',
                onChanged: (v) => setState(
                  () => _draft = _draft.copyWith(readiness: v ?? _draft.readiness),
                ),
              ),
              StatusSwitchTile(
                label: 'Missing',
                icon: Icons.help_outline,
                value: _draft.isMissing,
                accent: StatusTileAccent.error,
                margin: const EdgeInsets.symmetric(vertical: 8),
                onChanged: (v) =>
                    setState(() => _draft = _draft.copyWith(isMissing: v)),
              ),
              LabeledField(
                label: 'Notes',
                value: _draft.notes,
                maxLines: 2,
                onChanged: (v) => _draft = _draft.copyWith(notes: v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (widget.onRetire != null && !(widget.asset?.isRetired ?? false))
          TextButton(
            onPressed: widget.onRetire,
            child: const Text('Retire'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_draft),
          child: const Text('Save'),
        ),
      ],
    );
  }

  /// Rebuild against a different catalog entry. Only reachable while adding —
  /// catalogId is final on the entity because changing it after the fact would
  /// silently rewrite what past receipts referred to.
  VehicleAsset _rebuild(String catalogId) {
    return VehicleAsset.newDraft(
      tenantId: _draft.tenantId,
      vehicleId: _draft.vehicleId,
      catalogId: catalogId,
    ).copyWith(
      serialNumber: _draft.serialNumber,
      readiness: _draft.readiness,
      isMissing: _draft.isMissing,
      notes: _draft.notes,
    );
  }
}
