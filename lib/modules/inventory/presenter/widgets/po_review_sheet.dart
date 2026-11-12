import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_snack_bar.dart';
import '../../domain/catalog_part.dart';
import '../../domain/reorder.dart';
import '../../domain/vendor.dart';
import '../../infra/orders_repository.dart';

/// Reviews proposed orders (lines grouped by vendor) and saves them as draft
/// purchase orders. Returns how many orders were saved, or null if closed.
Future<int?> showPoReviewSheet(
  BuildContext context,
  WidgetRef ref, {
  required Map<String, List<ProposedLine>> groups,
  required List<Vendor> vendors,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => PoReviewSheet(groups: groups, vendors: vendors, ref: ref),
  );
}

class _Row {
  _Row(ProposedLine l)
      : part = l.part,
        vendorPartNumber = l.vendorPartNumber,
        qty = TextEditingController(text: '${l.qty}'),
        price = TextEditingController(
            text: l.unitCents > 0 ? (l.unitCents / 100).toStringAsFixed(2) : '');

  final CatalogPart part;
  final String vendorPartNumber;
  final TextEditingController qty;
  final TextEditingController price;

  void dispose() {
    qty.dispose();
    price.dispose();
  }
}

class _Group {
  _Group(this.vendorId, List<ProposedLine> lines)
      : fixed = vendorId != null,
        rows = [for (final l in lines) _Row(l)];
  String? vendorId;

  /// The vendor came from the part's price history; it is not chosen here.
  final bool fixed;
  final List<_Row> rows;
}

class PoReviewSheet extends StatefulWidget {
  const PoReviewSheet({
    super.key,
    required this.groups,
    required this.vendors,
    required this.ref,
  });

  final Map<String, List<ProposedLine>> groups;
  final List<Vendor> vendors;
  final WidgetRef ref;

  @override
  State<PoReviewSheet> createState() => _PoReviewSheetState();
}

class _PoReviewSheetState extends State<PoReviewSheet> {
  late final List<_Group> _groups = [
    for (final e in widget.groups.entries)
      _Group(e.key == noVendorGroup ? null : e.key, e.value),
  ]..sort((a, b) {
      // Unassigned last.
      if ((a.vendorId == null) != (b.vendorId == null)) {
        return a.vendorId == null ? 1 : -1;
      }
      return 0;
    });
  String? _error;
  bool _saving = false;

  List<Vendor> get _active => widget.vendors.where((v) => v.isActive).toList();

  String _vendorName(String? id) => widget.vendors
      .firstWhere((v) => v.id == id,
          orElse: () => Vendor(
              id: '',
              name: 'Unknown vendor',
              createdAt: DateTime.fromMillisecondsSinceEpoch(0),
              updatedAt: DateTime.fromMillisecondsSinceEpoch(0)))
      .name;

  @override
  void dispose() {
    for (final g in _groups) {
      for (final r in g.rows) {
        r.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _save() async {
    final repo = widget.ref.read(ordersRepositoryProvider);
    // Merge groups that ended up on the same vendor.
    final byVendor = <String, List<_Row>>{};
    var skipped = 0;
    for (final g in _groups) {
      for (final r in g.rows) {
        final qty = int.tryParse(r.qty.text.trim()) ?? 0;
        if (qty <= 0) continue;
        if (g.vendorId == null) {
          skipped++;
          continue;
        }
        byVendor.putIfAbsent(g.vendorId!, () => []).add(r);
      }
    }
    if (byVendor.isEmpty) {
      setState(() => _error = skipped > 0
          ? 'Choose a vendor for the parts without one.'
          : 'There is nothing to order.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      var n = 0;
      for (final e in byVendor.entries) {
        final lines = [
          for (final r in e.value)
            repo.newLine(
              partId: r.part.id,
              qty: int.parse(r.qty.text.trim()),
              unitCents: parseCents(r.price.text) ?? 0,
              vendorPartNumber: r.vendorPartNumber,
            ),
        ];
        final order = await repo.newOrder(vendorId: e.key, lines: lines);
        await repo.saveOrder(order);
        n++;
      }
      refreshOrders(widget.ref);
      AppSnackBar.successOn(
          messenger,
          n == 1
              ? 'Saved 1 draft purchase order'
              : 'Saved $n draft purchase orders');
      nav.pop(n);
    } catch (_) {
      setState(() {
        _saving = false;
        _error = 'Could not save the orders. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var total = 0;
    for (final g in _groups) {
      if (g.vendorId == null) continue;
      for (final r in g.rows) {
        total += (int.tryParse(r.qty.text.trim()) ?? 0) *
            (parseCents(r.price.text) ?? 0);
      }
    }
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
          Text('Review purchase orders', style: theme.textTheme.titleLarge),
          Text(
            'One draft order per vendor. Change quantities and prices, or '
            'remove lines you do not want.',
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (var gi = 0; gi < _groups.length; gi++) _group(context, gi),
              ],
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            key: const Key('po_save'),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save draft orders · ${formatCents(total)}'),
          ),
        ],
      ),
    );
  }

  Widget _group(BuildContext context, int gi) {
    final theme = Theme.of(context);
    final g = _groups[gi];
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (g.fixed)
              Text(_vendorName(g.vendorId), style: theme.textTheme.titleMedium)
            else ...[
              Text('No vendor yet', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<String>(
                key: Key('po_vendor_$gi'),
                initialValue: g.vendorId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Order these from'),
                items: [
                  for (final v in _active)
                    DropdownMenuItem(value: v.id, child: Text(v.name)),
                ],
                onChanged: (v) => setState(() => g.vendorId = v),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            for (final r in List.of(g.rows)) _line(context, g, r),
          ],
        ),
      ),
    );
  }

  Widget _line(BuildContext context, _Group g, _Row r) {
    final id = r.part.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text(
                '${r.part.partNumber}${r.part.name.isEmpty ? '' : ' · ${r.part.name}'}',
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              key: Key('po_drop_$id'),
              tooltip: 'Remove this line',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                g.rows.remove(r);
                r.dispose();
              }),
            ),
          ]),
          Row(children: [
            Expanded(
              child: TextField(
                key: Key('po_qty_$id'),
                controller: r.qty,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Quantity'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: TextField(
                key: Key('po_price_$id'),
                controller: r.price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[\d.,$]')),
                ],
                decoration: const InputDecoration(
                    labelText: 'Price for one', prefixText: r'$ '),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
