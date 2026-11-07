import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_page.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/lazy_head_list.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/catalog_part.dart';
import '../../domain/inventory_location.dart';
import '../../domain/stock.dart';
import '../../domain/vendor.dart';
import '../../infra/inventory_repository.dart';
import '../../infra/pricing_repository.dart';
import '../inventory_access.dart';
import '../widgets/inventory_sheets.dart';
import '../widgets/location_sheets.dart';
import '../widgets/part_order_info.dart';
import '../widgets/part_scan_button.dart';
import '../widgets/pricing_sheets.dart';
import 'package:go_router/go_router.dart';

StatusTone _tone(StockStatus s) => switch (s) {
      StockStatus.ok => StatusTone.success,
      StockStatus.low => StatusTone.warning,
      StockStatus.out => StatusTone.danger,
    };

/// What is in the warehouse: counts, low and out-of-stock parts, and (for
/// admins) receive / adjust / count.
class StockPage extends ConsumerStatefulWidget {
  const StockPage({super.key});

  @override
  ConsumerState<StockPage> createState() => _StockPageState();
}

class _StockPageState extends ConsumerState<StockPage> {
  StockFilter _filter = StockFilter.all;
  String _query = '';
  StockGroup _group = StockGroup.manufacturer;

  /// null = every location (the company total).
  String? _location;

  /// null = every manufacturer.
  String? _mfr;

  final _searchCtl = TextEditingController();

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  /// Fills the search with a scanned code; an exact part number (or
  /// alternate) opens that part, no match offers admins to add it.
  Future<void> _onScanned(String code) async {
    _searchCtl.text = code;
    setState(() => _query = code);
    final part = await findScannedPart(ref, code);
    if (!mounted) return;
    if (part != null) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => _PartDetail(partId: part.id),
      );
      return;
    }
    await offerAddScannedPart(context, ref, code);
  }

  @override
  void initState() {
    super.initState();
    // Bring in the cloud's latest once, then redraw. Failures are silent: the
    // device copy is what is shown.
    Future.microtask(() async {
      try {
        final n = await ref.read(inventoryRefreshProvider.future);
        if (n > 0 && mounted) {
          ref.invalidate(stockLevelsProvider);
          ref.invalidate(catalogPartsProvider);
        }
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final locations = ref.watch(inventoryLocationsProvider).value ??
        [InventoryLocation.main()];
    final loc = locations.any((l) => l.id == _location) ? _location : null;
    final levels = loc == null
        ? ref.watch(stockLevelsProvider)
        : ref.watch(locationStockProvider(loc));
    final canManage = ref.watch(canManageInventoryProvider);

    return AppPage(
      title: 'Stock',
      fab: canManage
          ? FloatingActionButton.extended(
              key: const Key('receive_stock'),
              onPressed: () => _receive(context),
              icon: const Icon(Icons.add_box_outlined),
              label: const Text('Receive stock'),
            )
          : null,
      body: levels.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState.error(
          message: 'Stock could not be loaded.',
          action: TextButton(
            onPressed: () => ref.invalidate(stockLevelsProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (all) => _body(context, all, canManage, locations),
      ),
    );
  }

  Widget _body(BuildContext context, List<StockLevel> all, bool canManage,
      List<InventoryLocation> locations) {
    final summary = stockSummary(all);
    final byFilter = filterStock(all, filter: _filter, query: _query);
    final makers = manufacturersOf(all.where((l) => l.part.isActive));
    final mfr = makers.any((m) => m.toLowerCase() == _mfr?.toLowerCase())
        ? _mfr
        : null;
    final shown = mfr == null
        ? byFilter
        : byFilter
            .where((l) =>
                l.part.manufacturer.trim().toLowerCase() == mfr.toLowerCase())
            .toList();
    final groups = groupStock(shown, _group);
    // Flattened header / tile entries, built lazily by the list.
    final rows = <Object>[
      if (shown.isNotEmpty)
        for (final g in groups) ...[
          if (_group != StockGroup.none) _GroupHead(g.label, g.levels.length),
          ...g.levels,
        ],
    ];
    final theme = Theme.of(context);
    final prices = canManage
        ? pricesByPart(ref.watch(allPricesProvider).value ?? const [])
        : const <String, List<PartPrice>>{};
    final value = canManage ? stockValue(all, prices) : null;

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(inventoryRepositoryProvider).refreshFromCloud();
        ref.invalidate(stockLevelsProvider);
      },
      child: LazyHeadList(
        padding: const EdgeInsets.all(AppSpacing.lg),
        rowCount: rows.length,
        rowBuilder: (context, i) {
          final r = rows[i];
          if (r is _GroupHead) {
            return Padding(
              key: Key('group_${r.label}'),
              padding: const EdgeInsets.only(
                  top: AppSpacing.md, bottom: AppSpacing.sm),
              child: Semantics(
                header: true,
                child: Text(
                  '${r.label.toUpperCase()} · ${r.count}',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            );
          }
          final l = r as StockLevel;
          return _StockTile(
            level: l,
            group: _group,
            price: prices.isEmpty
                ? null
                : summarizePrices(prices[l.part.id] ?? const []).lastPaid,
            onTap: () => _open(context, l),
          );
        },
        head: [
          Row(children: [
            Expanded(
              child: StatCard(
                icon: Icons.inventory_2_outlined,
                label: 'Parts',
                value: '${summary.parts}',
                compact: true,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatCard(
                icon: Icons.trending_down,
                label: 'Low',
                value: '${summary.low}',
                color: summary.low > 0 ? theme.colorScheme.tertiary : null,
                compact: true,
                onTap: () => setState(() => _filter = StockFilter.low),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: StatCard(
                icon: Icons.remove_shopping_cart_outlined,
                label: 'Out',
                value: '${summary.out}',
                color: summary.out > 0 ? theme.colorScheme.error : null,
                compact: true,
                onTap: () => setState(() => _filter = StockFilter.out),
              ),
            ),
          ]),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            key: const Key('stock_search'),
            controller: _searchCtl,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search part number, name or manufacturer',
              suffixIcon: PartScanButton(onScanned: _onScanned),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          if (value != null && value.cents > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Shelf value ${formatCents(value.cents)}'
              '${value.unpriced > 0 ? ' · ${value.unpriced} parts without a price' : ''}',
              key: const Key('stock_value'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          if (locations.length > 1 || canManage) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(
              key: const Key('location_chips'),
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (locations.length > 1) ...[
                  ChoiceChip(
                    key: const Key('location_all'),
                    label: const Text('All locations'),
                    selected: _location == null,
                    onSelected: (_) => setState(() => _location = null),
                  ),
                  for (final l in locations)
                    ChoiceChip(
                      key: Key('location_chip_${l.id}'),
                      avatar: Icon(
                          l.isMain
                              ? Icons.warehouse_outlined
                              : Icons.local_shipping_outlined,
                          size: 16),
                      label: Text(l.name),
                      selected: _location == l.id,
                      onSelected: (_) => setState(() => _location = l.id),
                    ),
                ],
                if (canManage)
                  ActionChip(
                    key: const Key('manage_locations'),
                    avatar: const Icon(Icons.edit_location_alt_outlined,
                        size: 16),
                    label: const Text('Locations'),
                    onPressed: () => showLocationsSheet(context, ref),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              for (final f in StockFilter.values)
                ChoiceChip(
                  label: Text(f.label),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            Text('Group by', style: theme.textTheme.labelLarge),
            const SizedBox(width: AppSpacing.md),
            SegmentedButton<StockGroup>(
              key: const Key('stock_group'),
              showSelectedIcon: false,
              segments: [
                for (final g in StockGroup.values)
                  ButtonSegment(value: g, label: Text(g.label)),
              ],
              selected: {_group},
              onSelectionChanged: (s) => setState(() => _group = s.first),
            ),
          ]),
          if (makers.length > 1) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.sm),
                    child: ChoiceChip(
                      label: const Text('All makers'),
                      selected: mfr == null,
                      onSelected: (_) => setState(() => _mfr = null),
                    ),
                  ),
                  for (final m in makers)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: ChoiceChip(
                        key: Key('maker_$m'),
                        label: Text(m),
                        selected: mfr?.toLowerCase() == m.toLowerCase(),
                        onSelected: (_) => setState(() => _mfr = m),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          if (all.where((l) => l.part.isActive).isEmpty)
            EmptyState(
              icon: Icons.inventory_2_outlined,
              title: 'No parts yet',
              message: canManage
                  ? 'Add parts to the catalog, then receive stock.'
                  : 'An admin adds parts to the catalog.',
              action: TextButton(
                onPressed: () => context.go(RoutePaths.inventoryCatalog),
                child: const Text('Open the catalog'),
              ),
            )
          else if (shown.isEmpty)
            const EmptyState(
              icon: Icons.search_off,
              title: 'Nothing matches',
              compact: true,
            )
        ],
      ),
    );
  }

  Future<void> _receive(BuildContext context) async {
    final parts = await ref.read(inventoryRepositoryProvider).stock();
    if (!context.mounted) return;
    final active = parts.where((l) => l.part.isActive).toList();
    if (active.isEmpty) {
      context.go(RoutePaths.inventoryCatalog);
      return;
    }
    final picked = await showModalBottomSheet<StockLevel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _PartPicker(levels: active),
    );
    if (picked == null || !context.mounted) return;
    await showStockActionSheet(context, ref,
        level: picked, action: StockAction.receive);
  }

  void _open(BuildContext context, StockLevel level) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _PartDetail(partId: level.part.id),
    );
  }
}

class _GroupHead {
  const _GroupHead(this.label, this.count);
  final String label;
  final int count;
}

class _StockTile extends StatelessWidget {
  const _StockTile({
    required this.level,
    required this.onTap,
    this.group = StockGroup.none,
    this.price,
  });

  final StockLevel level;
  final VoidCallback onTap;
  final StockGroup group;

  /// Last price paid, shown to admins.
  final PartPrice? price;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = level.part;
    // The heading already says the manufacturer (or the type) when grouped.
    final sub = [
      if (p.name.isNotEmpty && p.name != p.slot?.label) p.name,
      if (p.manufacturer.isNotEmpty && group != StockGroup.manufacturer)
        p.manufacturer,
      if (p.slot != null && group != StockGroup.slot) p.slot!.label,
      if (price != null) 'last ${formatCents(price!.unitCents)}',
    ].join(' · ');
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ListTile(
        onTap: onTap,
        title: Text(p.partNumber,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: sub.isEmpty ? null : Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('${level.onHand}',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            StatusChip(
              label: level.needsReconciliation
                  ? 'Needs recount'
                  : level.status.label,
              tone: level.needsReconciliation
                  ? StatusTone.danger
                  : _tone(level.status),
            ),
          ],
        ),
      ),
    );
  }
}

class _PartPicker extends StatefulWidget {
  const _PartPicker({required this.levels});
  final List<StockLevel> levels;

  @override
  State<_PartPicker> createState() => _PartPickerState();
}

class _PartPickerState extends State<_PartPicker> {
  String _q = '';
  final _searchCtl = TextEditingController();

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  /// A scanned code that is exactly a part number picks that part; anything
  /// else just fills the search.
  void _scanned(String code) {
    final hit =
        findPartByNumber([for (final l in widget.levels) l.part], code);
    if (hit != null) {
      Navigator.pop(context, widget.levels.firstWhere((l) => l.part.id == hit.id));
      return;
    }
    _searchCtl.text = code;
    setState(() => _q = code);
  }

  @override
  Widget build(BuildContext context) {
    final shown = filterStock(widget.levels, query: _q);
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Which part?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const Key('picker_search'),
            controller: _searchCtl,
            autofocus: true,
            decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search parts',
                suffixIcon: PartScanButton(onScanned: _scanned)),
            onChanged: (v) => setState(() => _q = v),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: shown.length,
              itemBuilder: (context, i) {
                final l = shown[i];
                return ListTile(
                  title: Text(l.part.partNumber),
                  subtitle: Text(l.part.title),
                  trailing: Text('${l.onHand} on hand'),
                  onTap: () => Navigator.pop(context, l),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PartDetail extends ConsumerWidget {
  const _PartDetail({required this.partId});
  final String partId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final canManage = ref.watch(canManageInventoryProvider);
    final canReserve = ref.watch(canReserveStockProvider);
    final locations = ref.watch(inventoryLocationsProvider).value ??
        [InventoryLocation.main()];
    final levels = ref.watch(stockLevelsProvider).value ?? const [];
    final matches = levels.where((l) => l.part.id == partId);
    if (matches.isEmpty) return const SizedBox(height: 120);
    final level = matches.first;
    final p = level.part;
    final moves = ref.watch(partMovementsProvider(partId)).value ?? const [];
    final fmt = DateFormat('MMM d, y');
    final priceList = canManage
        ? ref.watch(partPricesProvider(partId)).value ?? const <PartPrice>[]
        : const <PartPrice>[];
    final vendorNames = {
      for (final v in canManage
          ? ref.watch(vendorsProvider).value ?? const <Vendor>[]
          : const <Vendor>[])
        v.id: v.name,
    };
    final summary = summarizePrices(priceList);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(p.partNumber, style: theme.textTheme.titleLarge),
          if (p.title != p.partNumber) Text(p.title),
          if (p.manufacturer.isNotEmpty)
            Text(p.manufacturer,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          if (p.altPartNumbers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Text('Alternates: ${p.altPartNumbers.join(', ')}',
                  style: theme.textTheme.bodySmall),
            ),
          const SizedBox(height: AppSpacing.md),
          Row(children: [
            _Fact('On hand', '${level.onHand}'),
            _Fact('Reserved', '${level.reserved}'),
            _Fact('Available', '${level.available}'),
            _Fact('Minimum', p.minStock == 0 ? '—' : '${p.minStock}'),
          ]),
          if (locations.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                [
                  for (final l in locations)
                    '${l.name} ${onHandAt(moves, partId, l.id)}',
                ].join(' · '),
                key: const Key('location_breakdown'),
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          if (canReserve) ...[
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('transfer_stock'),
                onPressed: () => showTransferSheet(context, ref, part: p),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Transfer stock'),
              ),
            ),
          ],
          if (canManage) ...[
            const SizedBox(height: AppSpacing.md),
            Wrap(spacing: AppSpacing.sm, children: [
              OutlinedButton.icon(
                key: const Key('edit_part'),
                onPressed: () => showPartEditorSheet(context, ref, part: p),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit part'),
              ),
              OutlinedButton.icon(
                key: const Key('add_price'),
                onPressed: () => showPriceSheet(context, ref, part: p),
                icon: const Icon(Icons.sell_outlined, size: 18),
                label: const Text('Add price'),
              ),
              for (final a in StockAction.values)
                OutlinedButton(
                  key: Key('action_${a.name}'),
                  onPressed: () async {
                    await showStockActionSheet(context, ref, level: level, action: a);
                  },
                  child: Text(a.title),
                ),
            ]),
          ],
          if (canManage && priceList.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Prices', style: theme.textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(spacing: AppSpacing.lg, children: [
              if (summary.lastPaid != null)
                Text(
                    'Last paid ${formatCents(summary.lastPaid!.unitCents)}'
                    ' · ${vendorNames[summary.lastPaid!.vendorId] ?? 'vendor'}',
                    key: const Key('last_paid')),
              if (summary.best != null && summary.currentByVendor.length > 1)
                Text(
                    'Best ${formatCents(summary.best!.unitCents)}'
                    ' · ${vendorNames[summary.best!.vendorId] ?? 'vendor'}',
                    key: const Key('best_price')),
            ]),
            for (final pr in priceList.take(6))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                    '${formatCents(pr.unitCents)} · ${vendorNames[pr.vendorId] ?? 'vendor'}'),
                subtitle: Text([
                  pr.kind.label,
                  fmt.format(pr.pricedAt.toLocal()),
                  if (pr.vendorPartNumber.isNotEmpty) '#${pr.vendorPartNumber}',
                  if (pr.note.isNotEmpty) pr.note,
                ].join(' · ')),
                trailing: IconButton(
                  tooltip: 'Delete this price',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () async {
                    await ref.read(pricingRepositoryProvider).deletePrice(pr.id);
                    ref.invalidate(partPricesProvider);
                    ref.invalidate(allPricesProvider);
                  },
                ),
              ),
          ],
          if (canManage)
            PartOrderInfo(partId: partId, vendorNames: vendorNames),
          const SizedBox(height: AppSpacing.md),
          Text('History', style: theme.textTheme.titleSmall),
          Flexible(
            child: moves.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(AppSpacing.lg),
                    child: Text('No movements yet.'),
                  )
                : ListView(
                    shrinkWrap: true,
                    children: [
                      for (final m in moves)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                              '${m.reason.label}${m.note.isEmpty ? '' : ' · ${m.note}'}'),
                          subtitle: Text(fmt.format(m.at.toLocal())),
                          trailing: Text(
                            m.qtyDelta > 0 ? '+${m.qtyDelta}' : '${m.qtyDelta}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(children: [
        Text(value,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700)),
        Text(label, style: theme.textTheme.bodySmall),
      ]),
    );
  }
}
