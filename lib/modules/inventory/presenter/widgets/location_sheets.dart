import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../admin/domain/entities/tenant_member_entity.dart';
import '../../../fleet/domain/entities/vehicle_entity.dart';
import '../../../fleet/presenter/fleet_providers.dart';
import '../../domain/catalog_part.dart';
import '../../domain/inventory_location.dart';
import '../../domain/stock.dart';
import '../../infra/inventory_repository.dart';

/// Stock held at one location (warehouse or truck).
final locationStockProvider = FutureProvider.autoDispose
    .family<List<StockLevel>, String>(
  (ref, locationId) =>
      ref.watch(inventoryRepositoryProvider).stockAt(locationId),
);

void _refreshLocations(WidgetRef ref) {
  ref.invalidate(inventoryLocationsProvider);
  ref.invalidate(allInventoryLocationsProvider);
  ref.invalidate(stockLevelsProvider);
  ref.invalidate(partMovementsProvider);
  ref.invalidate(locationStockProvider);
}

// ---------------------------------------------------------------------------
// Locations (admin)
// ---------------------------------------------------------------------------

/// Add, rename and deactivate trucks. Admin only; callers check.
Future<void> showLocationsSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _LocationsSheet(ref: ref),
  );
}

class _LocationsSheet extends ConsumerWidget {
  const _LocationsSheet({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef sheetRef) {
    final theme = Theme.of(context);
    final locations = sheetRef.watch(allInventoryLocationsProvider).value ??
        [InventoryLocation.main()];
    final vehicles = {
      for (final v in sheetRef.watch(fleetVisibleVehiclesProvider).value ??
          const <VehicleEntity>[])
        v.id: v.displayTitle,
    };
    final members = {
      for (final m in sheetRef.watch(fleetAssignableMembersProvider).value ??
          const <TenantMemberEntity>[])
        m.userId: m.displayName,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Locations', style: theme.textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Stock is kept in the main warehouse and on trucks. Move parts '
            'between them with Transfer on a part.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final l in locations)
                  ListTile(
                    key: Key('location_${l.id}'),
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(l.isMain
                        ? Icons.warehouse_outlined
                        : Icons.local_shipping_outlined),
                    title: Text(l.name),
                    subtitle: Text([
                      if (l.isMain) 'Always on',
                      if (!l.isMain && !l.isActive) 'Deactivated',
                      if (l.vehicleId != null)
                        vehicles[l.vehicleId] ?? 'Linked vehicle',
                      if (l.assignedUserId != null)
                        members[l.assignedUserId] ?? 'Assigned technician',
                    ].join(' · ')),
                    trailing: l.isMain
                        ? null
                        : Wrap(children: [
                            IconButton(
                              tooltip: 'Edit ${l.name}',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => showTruckSheet(
                                  context, ref,
                                  truck: l),
                            ),
                            IconButton(
                              tooltip: l.isActive
                                  ? 'Deactivate ${l.name}'
                                  : 'Reactivate ${l.name}',
                              icon: Icon(l.isActive
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () async {
                                await ref
                                    .read(inventoryRepositoryProvider)
                                    .saveLocation(
                                        l.copyWith(isActive: !l.isActive));
                                _refreshLocations(ref);
                              },
                            ),
                          ]),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            key: const Key('add_truck'),
            onPressed: () => showTruckSheet(context, ref),
            icon: const Icon(Icons.add),
            label: const Text('Add a truck'),
          ),
        ],
      ),
    );
  }
}

/// Add a truck (when [truck] is null) or edit one.
Future<void> showTruckSheet(
  BuildContext context,
  WidgetRef ref, {
  InventoryLocation? truck,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _TruckSheet(truck: truck, ref: ref),
  );
}

class _TruckSheet extends ConsumerStatefulWidget {
  const _TruckSheet({required this.truck, required this.ref});
  final InventoryLocation? truck;
  final WidgetRef ref;

  @override
  ConsumerState<_TruckSheet> createState() => _TruckSheetState();
}

class _TruckSheetState extends ConsumerState<_TruckSheet> {
  late final _name = TextEditingController(text: widget.truck?.name);
  late String? _vehicleId = widget.truck?.vehicleId;
  late String? _userId = widget.truck?.assignedUserId;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Give the truck a name.');
      return;
    }
    final repo = widget.ref.read(inventoryRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final existing = widget.truck;
      await repo.saveLocation(existing == null
          ? repo
              .newTruck(
                  name: _name.text,
                  vehicleId: _vehicleId,
                  assignedUserId: _userId)
          : existing.copyWith(
              name: _name.text,
              vehicleId: _vehicleId,
              assignedUserId: _userId));
      _refreshLocations(widget.ref);
      AppSnackBar.successOn(
          messenger, existing == null ? 'Truck added' : 'Truck saved');
      nav.pop();
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'Could not save the truck. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vehicles =
        ref.watch(fleetVisibleVehiclesProvider).value ?? const <VehicleEntity>[];
    final members = ref.watch(fleetAssignableMembersProvider).value ??
        const <TenantMemberEntity>[];
    final vehicleIds = {for (final v in vehicles) v.id};
    final memberIds = {for (final m in members) m.userId};

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.truck == null ? 'Add a truck' : 'Edit truck',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('truck_name'),
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'Truck A',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String?>(
              key: const Key('truck_vehicle'),
              isExpanded: true,
              initialValue: vehicleIds.contains(_vehicleId) ? _vehicleId : null,
              decoration:
                  const InputDecoration(labelText: 'Fleet vehicle (optional)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                for (final v in vehicles)
                  DropdownMenuItem(
                    value: v.id,
                    child: Text(v.displayTitle, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() {
                _vehicleId = v;
                // A vehicle already stationed to someone suggests the driver.
                final driver = vehicles
                    .where((x) => x.id == v)
                    .map((x) => x.assignedToUserId)
                    .firstOrNull;
                if (_userId == null && driver != null && driver.isNotEmpty) {
                  _userId = driver;
                }
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String?>(
              key: const Key('truck_user'),
              isExpanded: true,
              initialValue: memberIds.contains(_userId) ? _userId : null,
              decoration: const InputDecoration(
                  labelText: 'Assigned technician (optional)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Nobody')),
                for (final m in members)
                  DropdownMenuItem(
                    value: m.userId,
                    child: Text(m.displayName, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _userId = v),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(_error!,
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const Key('save_truck'),
              onPressed: _saving ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Transfer
// ---------------------------------------------------------------------------

/// Move stock of [part] between locations. Admin, supervisor and dispatcher;
/// callers check.
Future<void> showTransferSheet(
  BuildContext context,
  WidgetRef ref, {
  required CatalogPart part,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _TransferSheet(part: part, ref: ref),
  );
}

class _TransferSheet extends ConsumerStatefulWidget {
  const _TransferSheet({required this.part, required this.ref});
  final CatalogPart part;
  final WidgetRef ref;

  @override
  ConsumerState<_TransferSheet> createState() => _TransferSheetState();
}

class _TransferSheetState extends ConsumerState<_TransferSheet> {
  final _qty = TextEditingController();
  final _note = TextEditingController();
  String _from = kMainLocationId;
  String? _to;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _qty.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(List<InventoryLocation> locations, int onHand) async {
    final qty = int.tryParse(_qty.text.trim()) ?? 0;
    final to = _to;
    if (to == null) {
      setState(() => _error = 'Choose where it is going.');
      return;
    }
    final problem = transferProblem(
      fromId: _from,
      toId: to,
      qty: qty,
      onHandAtSource: onHand,
    );
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.ref.read(inventoryRepositoryProvider).transfer(
            partId: widget.part.id,
            fromId: _from,
            toId: to,
            qty: qty,
            note: _note.text,
          );
      _refreshLocations(widget.ref);
      String name(String id) =>
          locations.where((l) => l.id == id).map((l) => l.name).firstOrNull ??
          'location';
      AppSnackBar.successOn(
          messenger, 'Moved $qty from ${name(_from)} to ${name(to)}');
      nav.pop();
    } on ArgumentError catch (e) {
      setState(() {
        _saving = false;
        _error = '${e.message}';
      });
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'Could not move the stock. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locations = ref.watch(inventoryLocationsProvider).value ??
        [InventoryLocation.main()];
    final moves = ref.watch(partMovementsProvider(widget.part.id)).value ??
        const [];
    final onHand = onHandAt(moves, widget.part.id, _from);
    final targets = [for (final l in locations) if (l.id != _from) l];

    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Transfer stock', style: theme.textTheme.titleLarge),
            Text(widget.part.title, style: theme.textTheme.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              key: const Key('transfer_from'),
              isExpanded: true,
              initialValue: _from,
              decoration: const InputDecoration(labelText: 'From'),
              items: [
                for (final l in locations)
                  DropdownMenuItem(
                    value: l.id,
                    child: Text(
                        '${l.name} (${onHandAt(moves, widget.part.id, l.id)} on hand)',
                        overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() {
                _from = v ?? kMainLocationId;
                if (_to == _from) _to = null;
              }),
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              key: const Key('transfer_to'),
              isExpanded: true,
              initialValue: targets.any((l) => l.id == _to) ? _to : null,
              decoration: const InputDecoration(labelText: 'To'),
              items: [
                for (final l in targets)
                  DropdownMenuItem(
                    value: l.id,
                    child: Text(l.name, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _to = v),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('transfer_qty'),
              controller: _qty,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Quantity',
                helperText: 'Up to $onHand at the source',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(_error!,
                    key: const Key('transfer_error'),
                    style: TextStyle(color: theme.colorScheme.error)),
              ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              key: const Key('save_transfer'),
              onPressed: _saving ? null : () => _save(locations, onHand),
              child: const Text('Move stock'),
            ),
          ],
        ),
      ),
    );
  }
}
