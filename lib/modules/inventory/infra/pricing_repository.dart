import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/sync/sync_context.dart';
import '../../../core/services/sync/sync_service.dart';
import '../domain/vendor.dart';
import 'inventory_repository.dart';

const String kVendorsTable = 'vendors';
const String kPartPricesTable = 'part_prices';

typedef PricingDelete = Future<void> Function(String table, String id);

class DuplicateVendorException implements Exception {
  const DuplicateVendorException(this.existing);
  final Vendor existing;

  @override
  String toString() => '${existing.name} is already in the vendor list.';
}

/// Vendors and the prices paid to them, kept on the device and queued for the
/// cloud. Plain `Box<String>` JSON stores, like the rest of inventory.
class PricingRepository {
  PricingRepository({
    Box<String>? vendorsBox,
    Box<String>? pricesBox,
    InventoryUpsert? upsert,
    InventoryFetch? fetch,
    PricingDelete? delete,
    String? Function()? tenantId,
    String? Function()? userId,
    String Function()? newId,
    DateTime Function()? now,
  })  : _vendorsInjected = vendorsBox,
        _pricesInjected = pricesBox,
        _upsert = upsert ?? _defaultUpsert,
        _fetch = fetch ?? _defaultFetch,
        _delete = delete ?? _defaultDelete,
        _tenantId = tenantId ?? (() => SyncContext.tenantId),
        _userId = userId ?? (() => SyncContext.userId),
        _newId = newId ?? generateInventoryId,
        _now = now ?? (() => DateTime.now().toUtc());

  static const String vendorsBoxName = 'vendors';
  static const String pricesBoxName = 'part_prices';

  final Box<String>? _vendorsInjected;
  final Box<String>? _pricesInjected;
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

  Future<Box<String>> _vendors() => _open(vendorsBoxName, _vendorsInjected);
  Future<Box<String>> _prices() => _open(pricesBoxName, _pricesInjected);

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

  // ---- vendors ------------------------------------------------------------

  Future<List<Vendor>> vendors() async {
    final box = await _vendors();
    final list = [
      for (final raw in box.values)
        if (Vendor.decode(raw) case final v?) v,
    ];
    list.sort((a, b) => vendorKey(a.name).compareTo(vendorKey(b.name)));
    return list;
  }

  Vendor newVendor({
    required String name,
    String contact = '',
    String phone = '',
    String email = '',
    String accountNumber = '',
    String notes = '',
  }) {
    final now = _now();
    return Vendor(
      id: _newId(),
      name: name,
      contact: contact,
      phone: phone,
      email: email,
      accountNumber: accountNumber,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Adds or updates a vendor. Throws [DuplicateVendorException] when another
  /// vendor has the same name.
  Future<Vendor> saveVendor(Vendor v) async {
    if (vendorKey(v.name).isEmpty) {
      throw ArgumentError('A vendor name is required.');
    }
    for (final other in await vendors()) {
      if (other.id != v.id && vendorKey(other.name) == vendorKey(v.name)) {
        throw DuplicateVendorException(other);
      }
    }
    final saved = v.copyWith(
      name: v.name.trim(),
      contact: v.contact.trim(),
      phone: v.phone.trim(),
      email: v.email.trim(),
      accountNumber: v.accountNumber.trim(),
      notes: v.notes.trim(),
      updatedAt: _now(),
    );
    final box = await _vendors();
    await box.put(saved.id, Vendor.encode(saved));
    final tenant = _tenantId();
    if (tenant != null && tenant.isNotEmpty) {
      await _upsert(kVendorsTable, saved.id, vendorToRow(saved, tenant, _userId()));
    }
    return saved;
  }

  // ---- prices -------------------------------------------------------------

  Future<List<PartPrice>> prices({String? partId}) async {
    final box = await _prices();
    final all = [
      for (final raw in box.values)
        if (PartPrice.decode(raw) case final p?) p,
    ];
    final list = partId == null ? all : all.where((p) => p.partId == partId).toList();
    list.sort((a, b) {
      final c = b.pricedAt.compareTo(a.pricedAt);
      return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  /// Records a price. [unitCents] must be positive.
  Future<PartPrice> addPrice({
    required String partId,
    required String vendorId,
    required int unitCents,
    PriceKind kind = PriceKind.paid,
    String vendorPartNumber = '',
    DateTime? pricedAt,
    String note = '',
  }) async {
    if (unitCents <= 0) throw ArgumentError('A price must be above zero.');
    final now = _now();
    final p = PartPrice(
      id: _newId(),
      partId: partId,
      vendorId: vendorId,
      unitCents: unitCents,
      kind: kind,
      vendorPartNumber: vendorPartNumber.trim(),
      pricedAt: pricedAt ?? now,
      note: note.trim(),
      createdAt: now,
    );
    final box = await _prices();
    await box.put(p.id, PartPrice.encode(p));
    final tenant = _tenantId();
    if (tenant != null && tenant.isNotEmpty) {
      await _upsert(kPartPricesTable, p.id, priceToRow(p, tenant, _userId()));
    }
    return p;
  }

  /// Removes a wrongly entered price.
  Future<void> deletePrice(String id) async {
    final box = await _prices();
    await box.delete(id);
    final tenant = _tenantId();
    if (tenant != null && tenant.isNotEmpty) await _delete(kPartPricesTable, id);
  }

  /// Pulls the cloud's vendors and prices into the device. Vendors by newest
  /// `updatedAt`; prices are added if missing. Returns how many changed.
  Future<int> refreshFromCloud() async {
    var changed = 0;
    final vbox = await _vendors();
    for (final row in await _fetch(kVendorsTable)) {
      final remote = vendorFromRow(row);
      if (remote == null) continue;
      final local = Vendor.decode(vbox.get(remote.id));
      if (local == null || remote.updatedAt.isAfter(local.updatedAt)) {
        await vbox.put(remote.id, Vendor.encode(remote));
        changed++;
      }
    }
    final pbox = await _prices();
    for (final row in await _fetch(kPartPricesTable)) {
      final p = priceFromRow(row);
      if (p == null || pbox.containsKey(p.id)) continue;
      await pbox.put(p.id, PartPrice.encode(p));
      changed++;
    }
    return changed;
  }
}

// ---- row mapping ---------------------------------------------------------

Map<String, dynamic> vendorToRow(Vendor v, String tenantId, String? userId) => {
      'id': v.id,
      'tenant_id': tenantId,
      'name': v.name,
      'contact_name': v.contact,
      'phone': v.phone,
      'email': v.email,
      'account_number': v.accountNumber,
      'notes': v.notes,
      'is_active': v.isActive,
      'created_at': v.createdAt.toUtc().toIso8601String(),
      'updated_at': v.updatedAt.toUtc().toIso8601String(),
      if (userId != null) 'updated_by': userId,
    };

Vendor? vendorFromRow(Map<String, dynamic> row) => Vendor.fromJson({
      'id': row['id'],
      'name': row['name'],
      'contact': row['contact_name'],
      'phone': row['phone'],
      'email': row['email'],
      'accountNumber': row['account_number'],
      'notes': row['notes'],
      'isActive': row['is_active'],
      'createdAt': row['created_at'],
      'updatedAt': row['updated_at'],
    });

String _day(DateTime d) => d.toUtc().toIso8601String().split('T').first;

Map<String, dynamic> priceToRow(PartPrice p, String tenantId, String? userId) => {
      'id': p.id,
      'tenant_id': tenantId,
      'part_id': p.partId,
      'vendor_id': p.vendorId,
      'unit_price_cents': p.unitCents,
      'kind': p.kind.wire,
      'vendor_part_number': p.vendorPartNumber,
      'priced_on': _day(p.pricedAt),
      'note': p.note,
      'created_at': p.createdAt.toUtc().toIso8601String(),
      if (userId != null) 'created_by': userId,
    };

PartPrice? priceFromRow(Map<String, dynamic> row) => PartPrice.fromJson({
      'id': row['id'],
      'partId': row['part_id'],
      'vendorId': row['vendor_id'],
      'unitCents': row['unit_price_cents'],
      'kind': row['kind'],
      'vendorPartNumber': row['vendor_part_number'],
      'pricedAt': row['priced_on'],
      'note': row['note'],
      'createdAt': row['created_at'],
    });

// ---- providers -----------------------------------------------------------

final pricingRepositoryProvider =
    Provider<PricingRepository>((ref) => PricingRepository());

final vendorsProvider = FutureProvider.autoDispose<List<Vendor>>(
  (ref) => ref.watch(pricingRepositoryProvider).vendors(),
);

final allPricesProvider = FutureProvider.autoDispose<List<PartPrice>>(
  (ref) => ref.watch(pricingRepositoryProvider).prices(),
);

final partPricesProvider =
    FutureProvider.autoDispose.family<List<PartPrice>, String>(
  (ref, partId) => ref.watch(pricingRepositoryProvider).prices(partId: partId),
);
