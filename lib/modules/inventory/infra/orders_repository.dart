import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/sync/sync_context.dart';
import '../../../core/services/sync/sync_service.dart';
import '../domain/purchase_order.dart';
import '../domain/stock.dart';
import '../domain/vendor.dart';
import 'inventory_repository.dart';
import 'pricing_repository.dart';

const String kPurchaseOrdersTable = 'purchase_orders';
const String kPurchaseOrderLinesTable = 'purchase_order_lines';

class DuplicatePoNumberException implements Exception {
  const DuplicatePoNumberException(this.number);
  final String number;

  @override
  String toString() => '$number is already used by another order.';
}

class ReceiveResult {
  const ReceiveResult({required this.order, required this.applied});

  /// The order after the receipt (unchanged when [applied] is false).
  final PurchaseOrder order;

  /// False when this receive action had already been applied.
  final bool applied;
}

/// Purchase orders, kept on the device and queued for the cloud. Same shape
/// as [PricingRepository]: plain `Box<String>` JSON stores.
class OrdersRepository {
  OrdersRepository({
    Box<String>? ordersBox,
    Box<String>? linesBox,
    Box<String>? receiptsBox,
    InventoryUpsert? upsert,
    InventoryFetch? fetch,
    PricingDelete? delete,
    String? Function()? tenantId,
    String? Function()? userId,
    String Function()? newId,
    DateTime Function()? now,
  })  : _ordersInjected = ordersBox,
        _linesInjected = linesBox,
        _receiptsInjected = receiptsBox,
        _upsert = upsert ?? _defaultUpsert,
        _fetch = fetch ?? _defaultFetch,
        _delete = delete ?? _defaultDelete,
        _tenantId = tenantId ?? (() => SyncContext.tenantId),
        _userId = userId ?? (() => SyncContext.userId),
        _newId = newId ?? generateInventoryId,
        _now = now ?? (() => DateTime.now().toUtc());

  static const String ordersBoxName = 'purchase_orders';
  static const String linesBoxName = 'purchase_order_lines';
  static const String receiptsBoxName = 'purchase_order_receipts';

  final Box<String>? _ordersInjected;
  final Box<String>? _linesInjected;
  final Box<String>? _receiptsInjected;
  final InventoryUpsert _upsert;
  final InventoryFetch _fetch;
  final PricingDelete _delete;
  final String? Function() _tenantId;
  final String? Function() _userId;
  final String Function() _newId;
  final DateTime Function() _now;

  Future<Box<String>> _open(String name, Box<String>? injected) async {
    if (injected != null) return injected;
    if (Hive.isBoxOpen(name)) return Hive.box<String>(name);
    return Hive.openBox<String>(name);
  }

  @visibleForTesting
  Box<String>? get debugOrdersBox => _ordersInjected;
  @visibleForTesting
  Box<String>? get debugLinesBox => _linesInjected;
  @visibleForTesting
  Box<String>? get debugReceiptsBox => _receiptsInjected;

  Future<Box<String>> _orders() => _open(ordersBoxName, _ordersInjected);
  Future<Box<String>> _lines() => _open(linesBoxName, _linesInjected);
  Future<Box<String>> _receipts() => _open(receiptsBoxName, _receiptsInjected);

  static Future<void> _defaultUpsert(
          String table, String id, Map<String, dynamic> row) =>
      SyncService.instance.enqueueUpsert(table: table, id: id, payload: row);

  static Future<void> _defaultDelete(String table, String id) =>
      SyncService.instance.enqueueDelete(table: table, id: id);

  static Future<List<Map<String, dynamic>>> _defaultFetch(String table) async {
    try {
      final rows = await Supabase.instance.client
          .from(table)
          .select()
          .timeout(const Duration(seconds: 8));
      return [for (final r in rows) Map<String, dynamic>.from(r as Map)];
    } catch (_) {
      return const [];
    }
  }

  bool get _syncing {
    final t = _tenantId();
    return t != null && t.isNotEmpty;
  }

  // ---- reads --------------------------------------------------------------

  /// Every order with its lines, newest first.
  Future<List<PurchaseOrder>> orders() async {
    final byOrder = await _linesByOrder();
    final box = await _orders();
    final list = [
      for (final raw in box.values)
        if (PurchaseOrder.decode(raw) case final o?)
          o.copyWith(lines: byOrder[o.id] ?? const []),
    ];
    list.sort((a, b) {
      final c = b.createdAt.compareTo(a.createdAt);
      return c != 0 ? c : b.number.compareTo(a.number);
    });
    return list;
  }

  Future<PurchaseOrder?> order(String id) async {
    final box = await _orders();
    final o = PurchaseOrder.decode(box.get(id));
    if (o == null) return null;
    return o.copyWith(lines: (await _linesByOrder())[id] ?? const []);
  }

  Future<Map<String, List<PoLine>>> _linesByOrder() async {
    final box = await _lines();
    final out = <String, List<PoLine>>{};
    for (final raw in box.values) {
      final decoded = _decodeLine(raw);
      if (decoded == null) continue;
      out.putIfAbsent(decoded.orderId, () => []).add(decoded.line);
    }
    return out;
  }

  /// Open-order quantity still to arrive, per part id.
  Future<Map<String, int>> onOrder() async => onOrderByPart(await orders());

  /// Lines for one part across all orders, newest order first.
  Future<List<({PurchaseOrder order, PoLine line})>> historyFor(
      String partId) async {
    final out = <({PurchaseOrder order, PoLine line})>[];
    for (final o in await orders()) {
      if (o.status == PoStatus.cancelled) continue;
      for (final l in o.lines) {
        if (l.partId == partId) out.add((order: o, line: l));
      }
    }
    return out;
  }

  // ---- writes -------------------------------------------------------------

  /// A new draft. Without a [number] it gets a provisional "NEW-xxxxxxxx"
  /// number; the server assigns the real PO number when the order first syncs
  /// and [refreshFromCloud] brings it back. Not saved until [saveOrder].
  Future<PurchaseOrder> newOrder({
    required String vendorId,
    required List<PoLine> lines,
    String? number,
    DateTime? expectedOn,
    String note = '',
  }) async {
    final now = _now();
    final id = _newId();
    return PurchaseOrder(
      id: id,
      number: (number == null || number.trim().isEmpty)
          ? provisionalPoNumber(id)
          : number.trim(),
      vendorId: vendorId,
      createdAt: now,
      updatedAt: now,
      expectedOn: expectedOn,
      note: note,
      lines: lines,
    );
  }

  PoLine newLine({
    required String partId,
    required int qty,
    int unitCents = 0,
    String vendorPartNumber = '',
  }) =>
      PoLine(
        id: _newId(),
        partId: partId,
        qtyOrdered: qty,
        unitCents: unitCents,
        vendorPartNumber: vendorPartNumber.trim(),
      );

  /// Adds or updates an order and its lines (lines no longer on it are
  /// removed). Throws [DuplicatePoNumberException] when another order has the
  /// number.
  Future<PurchaseOrder> saveOrder(PurchaseOrder o) async {
    final number = o.number.trim();
    if (number.isEmpty) throw ArgumentError('A PO number is required.');
    for (final other in await orders()) {
      if (other.id != o.id &&
          other.number.trim().toLowerCase() == number.toLowerCase()) {
        throw DuplicatePoNumberException(number);
      }
    }
    for (final l in o.lines) {
      if (l.qtyOrdered <= 0) throw ArgumentError('Quantities must be above zero.');
    }
    final saved = o.copyWith(number: number, updatedAt: _now());
    final obox = await _orders();
    final lbox = await _lines();
    await obox.put(saved.id, PurchaseOrder.encode(saved));

    final keep = {for (final l in saved.lines) l.id};
    final stale = <String>[];
    for (final e in lbox.toMap().entries) {
      final d = _decodeLine(e.value);
      if (d != null && d.orderId == saved.id && !keep.contains(d.line.id)) {
        stale.add(e.key as String);
      }
    }
    for (final id in stale) {
      await lbox.delete(id);
      if (_syncing) await _delete(kPurchaseOrderLinesTable, id);
    }
    for (final l in saved.lines) {
      await lbox.put(l.id, _encodeLine(saved.id, l));
    }
    if (_syncing) {
      final tenant = _tenantId()!;
      await _upsert(kPurchaseOrdersTable, saved.id,
          orderToRow(saved, tenant, _userId()));
      for (final l in saved.lines) {
        await _upsert(kPurchaseOrderLinesTable, l.id,
            lineToRow(l, saved.id, tenant, _createdFor(saved)));
      }
    }
    return saved;
  }

  DateTime _createdFor(PurchaseOrder o) => o.createdAt;

  /// Moves [o] to [to] when [canTransition] allows it.
  Future<PurchaseOrder> setStatus(String orderId, PoStatus to) async {
    final o = await order(orderId);
    if (o == null) throw StateError('Order not found.');
    if (!canTransition(o.status, to)) {
      throw StateError('A ${o.status.label.toLowerCase()} order cannot be '
          'marked ${to.label.toLowerCase()}.');
    }
    return saveOrder(o.copyWith(status: to));
  }

  /// Deletes a draft order. Other orders are cancelled, not deleted.
  Future<void> deleteDraft(String orderId) async {
    final o = await order(orderId);
    if (o == null) return;
    if (o.status != PoStatus.draft) {
      throw StateError('Only a draft can be deleted. Cancel it instead.');
    }
    final obox = await _orders();
    final lbox = await _lines();
    for (final l in o.lines) {
      await lbox.delete(l.id);
    }
    await obox.delete(orderId);
    if (_syncing) await _delete(kPurchaseOrdersTable, orderId);
  }

  /// Receives goods against an order: for each line in [quantities] (line id
  /// to quantity arrived) a 'receive' ledger movement noted with the PO
  /// number, a paid price entry at the PO's unit price, then the line's
  /// received count and the order's status.
  ///
  /// [receiptId] identifies this one receive action. Applying the same id
  /// again does nothing, so a double tap or a retry cannot add stock twice.
  Future<ReceiveResult> receive({
    required String orderId,
    required String receiptId,
    required Map<String, int> quantities,
    required InventoryRepository inventory,
    required PricingRepository pricing,
  }) async {
    final o = await order(orderId);
    if (o == null) throw StateError('Order not found.');
    final rbox = await _receipts();
    if (rbox.containsKey(receiptId)) {
      return ReceiveResult(order: o, applied: false);
    }
    if (o.status == PoStatus.draft || o.status == PoStatus.cancelled) {
      throw StateError('Mark the order as sent before receiving against it.');
    }

    // Mark first: a crash after this loses one receipt (visible, fixable by
    // hand) instead of silently doubling stock on a retry.
    await rbox.put(receiptId, orderId);

    final lines = <PoLine>[];
    for (final l in o.lines) {
      final qty = quantities[l.id] ?? 0;
      if (qty <= 0) {
        lines.add(l);
        continue;
      }
      await inventory.record(
        partId: l.partId,
        qty: qty,
        reason: MovementReason.receive,
        note: o.number,
      );
      if (l.unitCents > 0) {
        await pricing.addPrice(
          partId: l.partId,
          vendorId: o.vendorId,
          unitCents: l.unitCents,
          kind: PriceKind.paid,
          vendorPartNumber: l.vendorPartNumber,
          note: o.number,
        );
      }
      lines.add(l.copyWith(qtyReceived: l.qtyReceived + qty));
    }
    var next = o.copyWith(lines: lines);
    next = next.copyWith(status: statusAfterReceipt(next));
    final saved = await saveOrder(next);
    return ReceiveResult(order: saved, applied: true);
  }

  // ---- cloud --------------------------------------------------------------

  /// Pulls the cloud's orders and lines into the device. An order replaces the
  /// local one when it is newer, along with its lines. Returns how many rows
  /// changed.
  Future<int> refreshFromCloud() async {
    var changed = 0;
    final obox = await _orders();
    final lbox = await _lines();
    final replaced = <String>{};
    for (final row in await _fetch(kPurchaseOrdersTable)) {
      final remote = orderFromRow(row);
      if (remote == null) continue;
      final local = PurchaseOrder.decode(obox.get(remote.id));
      if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
        await obox.put(remote.id, PurchaseOrder.encode(remote));
        replaced.add(remote.id);
        changed++;
      } else if (local.numberPending && !remote.numberPending) {
        // The server assigned the real number. Adopt only the number: the
        // local copy may hold newer edits still waiting in the sync queue.
        // Lines stay linked by order id, so nothing else moves.
        await obox.put(
            local.id, PurchaseOrder.encode(local.copyWith(number: remote.number)));
        changed++;
      }
    }
    for (final row in await _fetch(kPurchaseOrderLinesTable)) {
      final parsed = lineFromRow(row);
      if (parsed == null) continue;
      final exists = lbox.containsKey(parsed.line.id);
      if (!exists || replaced.contains(parsed.orderId)) {
        await lbox.put(parsed.line.id, _encodeLine(parsed.orderId, parsed.line));
        changed++;
      }
    }
    return changed;
  }
}

// ---- line storage --------------------------------------------------------

String _encodeLine(String orderId, PoLine l) {
  final m = l.toJson()..['orderId'] = orderId;
  return jsonEncode(m);
}

({String orderId, PoLine line})? _decodeLine(String raw) {
  try {
    final m = jsonDecode(raw);
    if (m is! Map<String, dynamic>) return null;
    final orderId = m['orderId'];
    final line = PoLine.fromJson(m);
    if (orderId is! String || line == null) return null;
    return (orderId: orderId, line: line);
  } catch (_) {
    return null;
  }
}

// ---- row mapping ---------------------------------------------------------

String _day(DateTime d) => d.toUtc().toIso8601String().split('T').first;

Map<String, dynamic> orderToRow(PurchaseOrder o, String tenantId, String? userId) =>
    {
      'id': o.id,
      'tenant_id': tenantId,
      'po_number': o.number,
      'vendor_id': o.vendorId,
      'status': o.status.wire,
      'expected_on': o.expectedOn == null ? null : _day(o.expectedOn!),
      'note': o.note,
      'created_at': o.createdAt.toUtc().toIso8601String(),
      'updated_at': o.updatedAt.toUtc().toIso8601String(),
      if (userId != null) 'updated_by': userId,
    };

PurchaseOrder? orderFromRow(Map<String, dynamic> row) => PurchaseOrder.fromJson({
      'id': row['id'],
      'number': row['po_number'],
      'vendorId': row['vendor_id'],
      'status': row['status'],
      'createdAt': row['created_at'],
      'updatedAt': row['updated_at'],
      'expectedOn': row['expected_on'],
      'note': row['note'],
    });

Map<String, dynamic> lineToRow(
        PoLine l, String orderId, String tenantId, DateTime createdAt) =>
    {
      'id': l.id,
      'tenant_id': tenantId,
      'order_id': orderId,
      'part_id': l.partId,
      'qty_ordered': l.qtyOrdered,
      'qty_received': l.qtyReceived,
      'unit_price_cents': l.unitCents,
      'vendor_part_number': l.vendorPartNumber,
      'created_at': createdAt.toUtc().toIso8601String(),
    };

({String orderId, PoLine line})? lineFromRow(Map<String, dynamic> row) {
  final orderId = row['order_id'];
  final line = PoLine.fromJson({
    'id': row['id'],
    'partId': row['part_id'],
    'qtyOrdered': row['qty_ordered'],
    'qtyReceived': row['qty_received'],
    'unitCents': row['unit_price_cents'],
    'vendorPartNumber': row['vendor_part_number'],
  });
  if (orderId is! String || line == null) return null;
  return (orderId: orderId, line: line);
}

// ---- providers -----------------------------------------------------------

final ordersRepositoryProvider =
    Provider<OrdersRepository>((ref) => OrdersRepository());

final purchaseOrdersProvider = FutureProvider.autoDispose<List<PurchaseOrder>>(
  (ref) => ref.watch(ordersRepositoryProvider).orders(),
);

/// Quantity still to arrive per part id, from open orders.
final onOrderProvider = FutureProvider.autoDispose<Map<String, int>>((ref) async {
  try {
    return await ref.watch(ordersRepositoryProvider).onOrder();
  } catch (_) {
    // A decoration on other pages: never let it break them.
    return const <String, int>{};
  }
});

/// A part's lines on past and current orders, newest first.
final partOrderHistoryProvider = FutureProvider.autoDispose
    .family<List<({PurchaseOrder order, PoLine line})>, String>(
        (ref, partId) async {
  try {
    return await ref.watch(ordersRepositoryProvider).historyFor(partId);
  } catch (_) {
    return const [];
  }
});

void refreshOrders(WidgetRef ref) {
  ref.invalidate(purchaseOrdersProvider);
  ref.invalidate(onOrderProvider);
  ref.invalidate(partOrderHistoryProvider);
}
