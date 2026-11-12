import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/action_runner.dart';
import '../../../../shared/widgets/app_page.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/lazy_head_list.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../domain/catalog_part.dart';
import '../../domain/purchase_order.dart';
import '../../domain/vendor.dart';
import '../../infra/inventory_repository.dart';
import '../../infra/orders_repository.dart';
import '../../infra/pricing_repository.dart';
import '../inventory_access.dart';

StatusTone poTone(PoStatus s) => switch (s) {
      PoStatus.draft => StatusTone.neutral,
      PoStatus.sent => StatusTone.info,
      PoStatus.partial => StatusTone.warning,
      PoStatus.received => StatusTone.success,
      PoStatus.cancelled => StatusTone.danger,
    };

final _dateFmt = DateFormat('MMM d, y');

/// Purchase orders by status, with totals. Admin only (they carry prices).
class PurchaseOrdersPage extends ConsumerStatefulWidget {
  const PurchaseOrdersPage({super.key});

  @override
  ConsumerState<PurchaseOrdersPage> createState() => _PurchaseOrdersPageState();
}

class _PurchaseOrdersPageState extends ConsumerState<PurchaseOrdersPage> {
  /// null = all.
  PoStatus? _filter;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        final n = await ref.read(ordersRepositoryProvider).refreshFromCloud();
        if (n > 0 && mounted) refreshOrders(ref);
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(purchaseOrdersProvider);
    final vendorNames = {
      for (final v in ref.watch(vendorsProvider).value ?? const <Vendor>[])
        v.id: v.name,
    };
    final theme = Theme.of(context);

    return AppPage(
      title: 'Purchase Orders',
      body: orders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => EmptyState.error(
          message: 'Purchase orders could not be loaded.',
          action: TextButton(
            onPressed: () => ref.invalidate(purchaseOrdersProvider),
            child: const Text('Retry'),
          ),
        ),
        data: (all) {
          if (all.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No purchase orders yet',
              message: 'Create them from Shortages: it groups what you need '
                  'by vendor and saves a draft for each.',
            );
          }
          final shown =
              _filter == null ? all : all.where((o) => o.status == _filter).toList();
          final openCents = all
              .where((o) => o.status.isOpen)
              .fold<int>(0, (s, o) => s + o.totalCents);
          return LazyHeadList(
            padding: const EdgeInsets.all(AppSpacing.lg),
            head: [
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _filter == null,
                    onSelected: (_) => setState(() => _filter = null),
                  ),
                  for (final s in PoStatus.values)
                    ChoiceChip(
                      key: Key('po_filter_${s.wire}'),
                      label: Text(
                          '${s.label} ${all.where((o) => o.status == s).length}'),
                      selected: _filter == s,
                      onSelected: (_) => setState(() => _filter = s),
                    ),
                ],
              ),
              if (openCents > 0) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'On order ${formatCents(openCents)}',
                  key: const Key('po_open_total'),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              if (shown.isEmpty)
                const EmptyState(
                    icon: Icons.search_off, title: 'Nothing here', compact: true),
            ],
            rowCount: shown.length,
            rowBuilder: (context, i) {
              final o = shown[i];
              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.cardAll,
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: ListTile(
                  key: ValueKey('po_${o.id}'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => PurchaseOrderDetailPage(orderId: o.id),
                  )),
                  title: Text(
                    '${o.displayNumber} · ${vendorNames[o.vendorId] ?? 'Vendor'}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text([
                    '${o.lines.length} ${o.lines.length == 1 ? 'line' : 'lines'}',
                    '${o.unitsReceived}/${o.unitsOrdered} received',
                    formatCents(o.totalCents),
                    if (o.expectedOn != null)
                      'due ${_dateFmt.format(o.expectedOn!.toLocal())}',
                  ].join(' · ')),
                  trailing:
                      StatusChip(label: o.status.label, tone: poTone(o.status)),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- detail

/// One order: lines, totals, and the actions that move it along.
class PurchaseOrderDetailPage extends ConsumerStatefulWidget {
  const PurchaseOrderDetailPage({super.key, required this.orderId});
  final String orderId;

  @override
  ConsumerState<PurchaseOrderDetailPage> createState() =>
      _PurchaseOrderDetailPageState();
}

class _PurchaseOrderDetailPageState
    extends ConsumerState<PurchaseOrderDetailPage> {
  PurchaseOrder? _order;
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final o = await ref.read(ordersRepositoryProvider).order(widget.orderId);
    if (!mounted) return;
    setState(() {
      _order = o;
      _loaded = true;
    });
    refreshOrders(ref);
  }

  Map<String, CatalogPart> get _parts => {
        for (final p in ref.read(catalogPartsProvider).value ?? const <CatalogPart>[])
          p.id: p,
      };

  Future<void> _setStatus(PoStatus to) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(ordersRepositoryProvider).setStatus(widget.orderId, to);
      await _reload();
    } catch (e) {
      AppSnackBar.errorOn(messenger, '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Cancel this order?'),
        content: const Text('Nothing already received is taken back.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep')),
          FilledButton(
              key: const Key('po_cancel_confirm'),
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Cancel order')),
        ],
      ),
    );
    if (ok == true) await _setStatus(PoStatus.cancelled);
  }

  Future<void> _delete() async {
    final nav = Navigator.of(context);
    await ref.read(ordersRepositoryProvider).deleteDraft(widget.orderId);
    refreshOrders(ref);
    nav.pop();
  }

  Future<void> _share(PurchaseOrder o, Map<String, String> vendorNames) async {
    final parts = _parts;
    final text = poShareText(
      o,
      vendorName: vendorNames[o.vendorId] ?? 'Vendor',
      partLabel: (id) => parts[id]?.partNumber ?? 'Part',
      money: formatCents,
      date: (d) => _dateFmt.format(d.toLocal()),
    );
    await runUserAction(
      context,
      label: 'share the purchase order',
      action: () async {
        await SharePlus.instance.share(
            ShareParams(text: text, subject: 'Purchase order ${o.displayNumber}'));
        return true;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canManage = ref.watch(canManageInventoryProvider);
    final vendorNames = {
      for (final v in ref.watch(vendorsProvider).value ?? const <Vendor>[])
        v.id: v.name,
    };
    final parts = {
      for (final p in ref.watch(catalogPartsProvider).value ?? const <CatalogPart>[])
        p.id: p,
    };
    final o = _order;
    if (o == null) {
      return AppPage(
        title: 'Purchase order',
        body: _loaded
            ? const EmptyState(
                icon: Icons.receipt_long_outlined, title: 'Order not found')
            : const Center(child: CircularProgressIndicator()),
      );
    }

    return AppPage(
      title: o.displayNumber,
      actions: [
        IconButton(
          key: const Key('po_share'),
          tooltip: 'Share as text',
          icon: const Icon(Icons.ios_share),
          onPressed: () => _share(o, vendorNames),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Row(children: [
            Expanded(
              child: Text(vendorNames[o.vendorId] ?? 'Vendor',
                  style: theme.textTheme.titleLarge),
            ),
            StatusChip(
                key: const Key('po_status'),
                label: o.status.label,
                tone: poTone(o.status)),
          ]),
          const SizedBox(height: AppSpacing.xs),
          Text(
            [
              'Created ${_dateFmt.format(o.createdAt.toLocal())}',
              if (o.expectedOn != null)
                'expected ${_dateFmt.format(o.expectedOn!.toLocal())}',
            ].join(' · '),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (o.note.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(o.note),
          ],
          const SizedBox(height: AppSpacing.md),
          for (final l in o.lines)
            Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.cardAll,
                side: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
              child: ListTile(
                key: ValueKey('po_line_${l.id}'),
                title: Text(parts[l.partId]?.partNumber ?? 'Part',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text([
                  if ((parts[l.partId]?.name ?? '').isNotEmpty) parts[l.partId]!.name,
                  '${l.qtyReceived} of ${l.qtyOrdered} received',
                  if (l.unitCents > 0) '${formatCents(l.unitCents)} each',
                  if (l.vendorPartNumber.isNotEmpty) '#${l.vendorPartNumber}',
                ].join(' · ')),
                trailing: Text(formatCents(l.totalCents),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: Text('Total ${formatCents(o.totalCents)}',
                key: const Key('po_total'), style: theme.textTheme.titleMedium),
          ),
          if (canManage) ...[
            const SizedBox(height: AppSpacing.lg),
            Wrap(spacing: AppSpacing.sm, runSpacing: AppSpacing.sm, children: [
              if (o.status == PoStatus.draft)
                FilledButton.icon(
                  key: const Key('po_mark_sent'),
                  onPressed: _busy ? null : () => _setStatus(PoStatus.sent),
                  icon: const Icon(Icons.send_outlined, size: 18),
                  label: const Text('Mark sent'),
                ),
              if (o.status == PoStatus.sent || o.status == PoStatus.partial)
                FilledButton.icon(
                  key: const Key('po_receive'),
                  onPressed: _busy
                      ? null
                      : () async {
                          final done = await showPoReceiveSheet(context, ref,
                              order: o, parts: parts);
                          if (done == true) await _reload();
                        },
                  icon: const Icon(Icons.move_to_inbox_outlined, size: 18),
                  label: const Text('Receive'),
                ),
              if (o.status.isEditable)
                OutlinedButton.icon(
                  key: const Key('po_edit'),
                  onPressed: _busy
                      ? null
                      : () async {
                          final saved = await showPoEditSheet(context, ref,
                              order: o, parts: parts);
                          if (saved == true) await _reload();
                        },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
              if (!o.status.isFinal)
                OutlinedButton(
                  key: const Key('po_cancel'),
                  onPressed: _busy ? null : _cancel,
                  child: const Text('Cancel order'),
                ),
              if (o.status == PoStatus.draft)
                TextButton(
                  key: const Key('po_delete'),
                  onPressed: _busy ? null : _delete,
                  child: const Text('Delete draft'),
                ),
            ]),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- receive

/// Receive goods against [order]. Returns true when stock was added.
Future<bool?> showPoReceiveSheet(
  BuildContext context,
  WidgetRef ref, {
  required PurchaseOrder order,
  required Map<String, CatalogPart> parts,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _ReceiveSheet(order: order, parts: parts, ref: ref),
  );
}

class _ReceiveSheet extends StatefulWidget {
  const _ReceiveSheet(
      {required this.order, required this.parts, required this.ref});
  final PurchaseOrder order;
  final Map<String, CatalogPart> parts;
  final WidgetRef ref;

  @override
  State<_ReceiveSheet> createState() => _ReceiveSheetState();
}

class _ReceiveSheetState extends State<_ReceiveSheet> {
  /// One id for this sheet: tapping Receive twice cannot add stock twice.
  final String _receiptId = generateInventoryId();
  late final Map<String, TextEditingController> _qty = {
    for (final l in widget.order.lines)
      if (l.outstanding > 0)
        l.id: TextEditingController(text: '${l.outstanding}'),
  };
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _qty.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final quantities = <String, int>{};
    for (final l in widget.order.lines) {
      final c = _qty[l.id];
      if (c == null) continue;
      final n = int.tryParse(c.text.trim()) ?? 0;
      if (n > l.outstanding) {
        setState(() => _error = '${widget.parts[l.partId]?.partNumber ?? 'A part'}: '
            'only ${l.outstanding} still to arrive. Edit the order first if '
            'more came.');
        return;
      }
      if (n > 0) quantities[l.id] = n;
    }
    if (quantities.isEmpty) {
      setState(() => _error = 'Enter how many arrived.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      final r = await widget.ref.read(ordersRepositoryProvider).receive(
            orderId: widget.order.id,
            receiptId: _receiptId,
            quantities: quantities,
            inventory: widget.ref.read(inventoryRepositoryProvider),
            pricing: widget.ref.read(pricingRepositoryProvider),
          );
      widget.ref
        ..invalidate(stockLevelsProvider)
        ..invalidate(allPricesProvider)
        ..invalidate(partPricesProvider)
        ..invalidate(partMovementsProvider);
      refreshOrders(widget.ref);
      AppSnackBar.successOn(
          messenger,
          r.order.status == PoStatus.received
              ? '${r.order.displayNumber} fully received'
              : 'Received against ${r.order.displayNumber}');
      nav.pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = '$e';
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
            Text('Receive ${widget.order.displayNumber}',
                style: theme.textTheme.titleLarge),
            Text('Stock is added and the price paid is recorded.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: AppSpacing.md),
            for (final l in widget.order.lines)
              if (_qty[l.id] case final c?)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: TextField(
                    key: Key('receive_qty_${l.id}'),
                    controller: c,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: widget.parts[l.partId]?.partNumber ?? 'Part',
                      helperText: '${l.outstanding} still to arrive',
                    ),
                  ),
                ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            FilledButton(
              key: const Key('po_receive_confirm'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Receiving…' : 'Receive'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- edit

/// Edit an order's number, expected date, note and lines. Returns true when
/// saved.
Future<bool?> showPoEditSheet(
  BuildContext context,
  WidgetRef ref, {
  required PurchaseOrder order,
  required Map<String, CatalogPart> parts,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _EditSheet(order: order, parts: parts, ref: ref),
  );
}

class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.order, required this.parts, required this.ref});
  final PurchaseOrder order;
  final Map<String, CatalogPart> parts;
  final WidgetRef ref;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _number = TextEditingController(
      text: widget.order.numberPending ? '' : widget.order.number);
  late final _note = TextEditingController(text: widget.order.note);
  late DateTime? _expected = widget.order.expectedOn;
  late final List<PoLine> _lines = List.of(widget.order.lines);
  late final Map<String, TextEditingController> _qty = {
    for (final l in _lines) l.id: TextEditingController(text: '${l.qtyOrdered}'),
  };
  late final Map<String, TextEditingController> _price = {
    for (final l in _lines)
      l.id: TextEditingController(
          text: l.unitCents > 0 ? (l.unitCents / 100).toStringAsFixed(2) : ''),
  };
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _number.dispose();
    _note.dispose();
    for (final c in [..._qty.values, ..._price.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _expected ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (d != null) setState(() => _expected = d);
  }

  Future<void> _save() async {
    final next = <PoLine>[];
    for (final l in _lines) {
      final q = int.tryParse(_qty[l.id]!.text.trim()) ?? 0;
      if (q <= 0) {
        setState(() => _error = 'Quantities must be above zero. Remove a line '
            'you do not want.');
        return;
      }
      if (q < l.qtyReceived) {
        setState(() => _error = '${widget.parts[l.partId]?.partNumber ?? 'A part'}'
            ': ${l.qtyReceived} already received.');
        return;
      }
      next.add(l.copyWith(
          qtyOrdered: q, unitCents: parseCents(_price[l.id]!.text) ?? 0));
    }
    if (next.isEmpty) {
      setState(() => _error = 'An order needs at least one line.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final nav = Navigator.of(context);
    try {
      var o = widget.order.copyWith(
        // Left blank on a pending order keeps the provisional number, which
        // the server replaces on sync; a typed number is kept as is.
        number: _number.text.trim().isEmpty && widget.order.numberPending
            ? widget.order.number
            : _number.text,
        note: _note.text.trim(),
        lines: next,
        expectedOn: _expected,
        clearExpected: _expected == null,
      );
      if (o.status == PoStatus.sent) {
        o = o.copyWith(status: statusAfterReceipt(o));
      }
      await widget.ref.read(ordersRepositoryProvider).saveOrder(o);
      refreshOrders(widget.ref);
      nav.pop(true);
    } on DuplicatePoNumberException catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'Could not save the order. Try again.';
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
            Text('Edit order', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            Row(children: [
              Expanded(
                child: TextField(
                  key: const Key('po_number'),
                  controller: _number,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'PO number',
                    helperText: widget.order.numberPending
                        ? 'Number pending: assigned when it syncs'
                        : null,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.event_outlined),
                label: Text(_expected == null
                    ? 'Expected on'
                    : _dateFmt.format(_expected!)),
              ),
            ]),
            const SizedBox(height: AppSpacing.md),
            TextField(
              key: const Key('po_note'),
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note'),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final l in List.of(_lines))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(widget.parts[l.partId]?.partNumber ?? 'Part',
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      if (l.qtyReceived == 0)
                        IconButton(
                          key: Key('po_edit_drop_${l.id}'),
                          tooltip: 'Remove this line',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _lines.remove(l)),
                        ),
                    ]),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          key: Key('po_edit_qty_${l.id}'),
                          controller: _qty[l.id],
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(labelText: 'Quantity'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextField(
                          key: Key('po_edit_price_${l.id}'),
                          controller: _price[l.id],
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
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ),
            FilledButton(
              key: const Key('po_edit_save'),
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }
}
