import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/modules/inventory/domain/catalog_part.dart';
import 'package:voltcore/modules/inventory/domain/stock.dart';
import 'package:voltcore/modules/inventory/domain/vendor.dart';
import 'package:voltcore/modules/inventory/infra/pricing_repository.dart';
import 'package:voltcore/modules/inventory/presenter/inventory_access.dart';
import 'package:voltcore/modules/inventory/presenter/pages/vendors_page.dart';

final _t = DateTime.utc(2026, 1, 1);

CatalogPart part(String id, String number, {String mfr = '', String name = ''}) =>
    CatalogPart(
        id: id, partNumber: number, manufacturer: mfr, name: name,
        createdAt: _t, updatedAt: _t);

StockLevel level(CatalogPart p, int onHand) => StockLevel(
    part: p, onHand: onHand, reserved: 0);

PartPrice price(String id, String part, String vendor, int cents,
        {DateTime? on, PriceKind kind = PriceKind.paid}) =>
    PartPrice(
        id: id, partId: part, vendorId: vendor, unitCents: cents, kind: kind,
        pricedAt: on ?? _t, createdAt: on ?? _t);

void main() {
  group('money', () {
    test('parses what people type', () {
      expect(parseCents('24.50'), 2450);
      expect(parseCents(r'$1,234.5'), 123450);
      expect(parseCents('12'), 1200);
      expect(parseCents('0.07'), 7);
      expect(parseCents(''), isNull);
      expect(parseCents('abc'), isNull);
      expect(parseCents('1.234'), isNull);
      expect(parseCents('-3'), isNull);
    });

    test('formats with thousands separators', () {
      expect(formatCents(2450), r'$24.50');
      expect(formatCents(123456), r'$1,234.56');
      expect(formatCents(5), r'$0.05');
      expect(formatCents(100000000), r'$1,000,000.00');
    });
  });

  group('price summary', () {
    test('current price is the newest per vendor; best is the lowest of those', () {
      final s = summarizePrices([
        price('1', 'p', 'a', 3000, on: DateTime.utc(2026, 1, 1)),
        price('2', 'p', 'a', 2500, on: DateTime.utc(2026, 3, 1)),
        price('3', 'p', 'b', 2700, on: DateTime.utc(2026, 2, 1)),
      ]);
      expect(s.currentByVendor['a']!.unitCents, 2500);
      expect(s.currentByVendor['b']!.unitCents, 2700);
      expect(s.best!.vendorId, 'a');
      expect(s.lastPaid!.id, '2');
    });

    test('a quote is not "last paid"', () {
      final s = summarizePrices([
        price('1', 'p', 'a', 3000, on: DateTime.utc(2026, 1, 1)),
        price('2', 'p', 'b', 1000,
            on: DateTime.utc(2026, 5, 1), kind: PriceKind.quote),
      ]);
      expect(s.lastPaid!.unitCents, 3000);
      expect(s.best!.unitCents, 1000);
    });

    test('shelf value is on hand times last paid; unpriced parts are counted', () {
      final a = part('a', 'A'), b = part('b', 'B'), c = part('c', 'C');
      final v = stockValue([level(a, 3), level(b, 2), level(c, 0)], {
        'a': [price('1', 'a', 'v', 1050)],
      });
      expect(v.cents, 3150);
      expect(v.unpriced, 1); // b; c has nothing on the shelf
    });
  });

  group('grouping by manufacturer', () {
    final baldwin = part('1', 'BF2', mfr: 'Baldwin');
    final baldwin2 = part('2', 'BF1', mfr: 'baldwin');
    final don = part('3', 'P55', mfr: 'Donaldson');
    final none = part('4', 'ZZ');
    final all = [level(don, 1), level(none, 1), level(baldwin, 1), level(baldwin2, 1)];

    test('groups are alphabetical, spelling variants share one, none is last', () {
      final g = groupStock(all, StockGroup.manufacturer);
      expect(g.map((x) => x.label), ['Baldwin', 'Donaldson', noManufacturerLabel]);
      expect(g.first.levels.map((l) => l.part.partNumber), ['BF1', 'BF2']);
    });

    test('no grouping gives one list in part-number order', () {
      final g = groupStock(all, StockGroup.none);
      expect(g.single.levels.map((l) => l.part.partNumber),
          ['BF1', 'BF2', 'P55', 'ZZ']);
    });

    test('lists each manufacturer once', () {
      expect(manufacturersOf(all), ['Baldwin', 'Donaldson']);
    });
  });

  group('PricingRepository', () {
    late PricingRepository repo;
    var n = 0;
    final synced = <String>[];

    setUp(() async {
      Hive.init('${Directory.systemTemp.path}/price_test_${DateTime.now().microsecondsSinceEpoch}');
      synced.clear();
      var id = 0;
      repo = PricingRepository(
        vendorsBox: await Hive.openBox<String>('v${n++}'),
        pricesBox: await Hive.openBox<String>('p$n'),
        upsert: (table, rowId, row) async => synced.add('$table:$rowId'),
        delete: (table, rowId) async => synced.add('del $table:$rowId'),
        fetch: (_) async => const [],
        tenantId: () => 'tenant',
        userId: () => 'user',
        newId: () => 'id${id++}',
        now: () => DateTime.utc(2026, 6, 1),
      );
    });

    test('saves vendors, rejects a duplicate name, and queues the sync', () async {
      final a = await repo.saveVendor(repo.newVendor(name: ' Ace Wire & Cable '));
      expect(a.name, 'Ace Wire & Cable');
      expect(
        () => repo.saveVendor(repo.newVendor(name: 'ace wire cable')),
        throwsA(isA<DuplicateVendorException>()),
      );
      // Editing the same vendor is not a duplicate.
      await repo.saveVendor(a.copyWith(phone: '555'));
      expect((await repo.vendors()).single.phone, '555');
      expect(synced.where((s) => s.startsWith('vendors:')), isNotEmpty);
    });

    test('records prices newest first, and deletes a wrong one', () async {
      final v = await repo.saveVendor(repo.newVendor(name: 'Graybar'));
      await repo.addPrice(
          partId: 'p', vendorId: v.id, unitCents: 1000, pricedAt: DateTime.utc(2026, 1, 1));
      final newer = await repo.addPrice(
          partId: 'p', vendorId: v.id, unitCents: 1200, pricedAt: DateTime.utc(2026, 3, 1));
      final list = await repo.prices(partId: 'p');
      expect(list.map((p) => p.unitCents), [1200, 1000]);
      expect(await repo.prices(partId: 'other'), isEmpty);

      await repo.deletePrice(newer.id);
      expect((await repo.prices(partId: 'p')).single.unitCents, 1000);
      expect(synced, contains('del part_prices:${newer.id}'));
    });

    test('a price must be above zero', () async {
      expect(
        () => repo.addPrice(partId: 'p', vendorId: 'v', unitCents: 0),
        throwsArgumentError,
      );
    });

    test('cloud rows round-trip', () {
      final v = Vendor(id: 'v', name: 'Graybar', contact: 'Sam', createdAt: _t, updatedAt: _t);
      expect(vendorFromRow(vendorToRow(v, 't', 'u'))!.contact, 'Sam');
      final p = price('1', 'p', 'v', 2450, on: DateTime.utc(2026, 2, 3));
      final back = priceFromRow(priceToRow(p, 't', 'u'))!;
      expect(back.unitCents, 2450);
      expect(back.pricedAt.toUtc().toIso8601String().substring(0, 10), '2026-02-03');
    });
  });

  testWidgets('Vendors page lists vendors; only admins can add', (t) async {
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) return;
      prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);

    final repo = _MemPricing([
      Vendor(id: 'v1', name: 'Graybar', phone: '555-1', createdAt: _t, updatedAt: _t),
    ], [price('1', 'p', 'v1', 1000)]);

    Widget host(bool admin) => ProviderScope(
          overrides: [
            pricingRepositoryProvider.overrideWithValue(repo),
            canManageInventoryProvider.overrideWithValue(admin),
          ],
          child: const MaterialApp(home: VendorsPage()),
        );

    await t.pumpWidget(host(true));
    await t.pump();
    await t.pump();
    expect(find.text('Graybar'), findsOneWidget);
    expect(find.textContaining('1 prices recorded'), findsOneWidget);
    expect(find.byKey(const Key('add_vendor')), findsOneWidget);

    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(host(false));
    await t.pump();
    await t.pump();
    expect(find.byKey(const Key('add_vendor')), findsNothing);
  });
}

class _MemPricing extends PricingRepository {
  _MemPricing(this._vendors, this._prices) : super(tenantId: () => null);
  final List<Vendor> _vendors;
  final List<PartPrice> _prices;

  @override
  Future<List<Vendor>> vendors() async => List.of(_vendors);

  @override
  Future<List<PartPrice>> prices({String? partId}) async => [
        for (final p in _prices)
          if (partId == null || p.partId == partId) p,
      ];

  @override
  Future<int> refreshFromCloud() async => 0;
}
