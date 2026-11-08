import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/inventory/domain/catalog_part.dart';
import 'package:voltcore/modules/inventory/domain/generic_names.dart';
import 'package:voltcore/modules/inventory/domain/inventory_location.dart';
import 'package:voltcore/modules/inventory/domain/stock.dart';
import 'package:voltcore/modules/inventory/domain/vendor.dart';
import 'package:voltcore/modules/inventory/infra/inventory_repository.dart';
import 'package:voltcore/modules/inventory/infra/part_image_store.dart';
import 'package:voltcore/modules/inventory/infra/pricing_repository.dart';
import 'package:voltcore/modules/inventory/presenter/inventory_access.dart';
import 'package:voltcore/modules/inventory/presenter/pages/parts_catalog_page.dart';
import 'package:voltcore/modules/inventory/presenter/pages/stock_page.dart';
import 'package:voltcore/modules/inventory/presenter/widgets/inventory_sheets.dart';
import 'package:voltcore/modules/materials/domain/material_item.dart';

final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==');
final _t = DateTime.utc(2026, 1, 1);

CatalogPart _p(String id, String n,
        {String name = '', String? img, MaterialSlot? slot}) =>
    CatalogPart(
        id: id,
        partNumber: n,
        name: name,
        slot: slot,
        imagePath: img,
        createdAt: _t,
        updatedAt: _t);

class _NoPricing extends PricingRepository {
  _NoPricing() : super(tenantId: () => null);
  @override
  Future<List<Vendor>> vendors() async => const [];
  @override
  Future<List<PartPrice>> prices({String? partId}) async => const [];
  @override
  Future<int> refreshFromCloud() async => 0;
}

class _MemRepo extends InventoryRepository {
  _MemRepo(this.list) : super(tenantId: () => null);
  final List<CatalogPart> list;

  @override
  Future<List<InventoryLocation>> locations({bool includeInactive = false}) async =>
      [InventoryLocation.main()];
  @override
  Future<List<CatalogPart>> parts() async => List.of(list);
  @override
  Future<List<InventoryMovement>> movements({String? partId}) async => const [];
  @override
  Future<List<StockLevel>> stock() async => computeStock(list, const []);
  @override
  Future<int> refreshFromCloud() async => 0;
  @override
  Future<CatalogPart> savePart(CatalogPart part) async {
    list.removeWhere((p) => p.id == part.id);
    list.add(part);
    return part;
  }
}

class _FakeStore implements PartImageStore {
  _FakeStore({this.bytes, this.throwOnLoad = false});
  final Uint8List? bytes;
  final bool throwOnLoad;
  final saved = <String>[];
  final removed = <String>[];

  @override
  Future<Uint8List?> load(CatalogPart part) async {
    if (throwOnLoad) throw StateError('boom');
    return bytes;
  }

  @override
  Future<String> save(CatalogPart part, Uint8List b) async {
    saved.add(part.id);
    return 'part-images/t/${part.id}.jpg';
  }

  @override
  Future<void> remove(CatalogPart part) async => removed.add(part.id);
}

class _FakePicker implements PartImagePicker {
  int calls = 0;
  @override
  Future<Uint8List?> pick(PartImageSource source) async {
    calls++;
    return Uint8List.fromList(_png);
  }
}

const _sizes = [Size(360, 800), Size(1280, 800)];

void main() {
  group('CatalogPart.imagePath', () {
    test('old JSON without imagePath loads as null', () {
      final p = CatalogPart.fromJson({
        'id': 'a',
        'partNumber': 'X1',
        'name': 'Air filter',
      })!;
      expect(p.imagePath, isNull);
      expect(p.name, 'Air filter');
    });

    test('round trips and copyWith can set and clear it', () {
      final p = _p('a', 'X1', img: 'part-images/t/a.jpg');
      expect(CatalogPart.decode(CatalogPart.encode(p))!.imagePath,
          'part-images/t/a.jpg');
      expect(p.copyWith(name: 'n').imagePath, 'part-images/t/a.jpg');
      expect(p.copyWith(imagePath: null).imagePath, isNull);
      expect(p.copyWith(imagePath: 'z').imagePath, 'z');
      expect(CatalogPart.fromJson({...p.toJson(), 'imagePath': ' '})!.imagePath,
          isNull);
    });

    test('row mapping carries image_path both ways', () {
      final p = _p('a', 'X1', img: 'part-images/t/a.jpg');
      final row = partToRow(p, 't', 'u');
      expect(row['image_path'], 'part-images/t/a.jpg');
      expect(partFromRow(row)!.imagePath, 'part-images/t/a.jpg');
      final none = partToRow(_p('b', 'X2'), 't', null);
      expect(none['image_path'], isNull);
      expect(partFromRow(none)!.imagePath, isNull);
      expect(partImageObjectPath('t1', 'p1'), 'part-images/t1/p1.jpg');
    });
  });

  group('generic names', () {
    test('finds names equal to a slot label, case-insensitively', () {
      final parts = [
        _p('1', 'A', name: 'Air filter', slot: MaterialSlot.airFilter),
        _p('2', 'B', name: ' battery ', slot: MaterialSlot.battery),
        _p('3', 'C', name: 'BLOCK  HEATER'),
        _p('4', 'D', name: 'Fleetguard lube filter, spin-on'),
        _p('5', 'E'),
        _p('6', 'F', name: 'Oil filter', slot: MaterialSlot.airFilter),
      ];
      expect(partsWithGenericNames(parts).map((p) => p.id), ['1', '2', '3', '6']);
      expect(hasGenericName(parts[3]), isFalse);
      expect(hasGenericName(parts[4]), isFalse);
    });
  });

  Widget host(Widget page, _MemRepo repo,
      {required bool admin,
      PartImageStore? store,
      PartImagePicker? picker,
      List<String>? overflows}) {
    return ProviderScope(
      overrides: [
        inventoryRepositoryProvider.overrideWithValue(repo),
        pricingRepositoryProvider.overrideWithValue(_NoPricing()),
        canManageInventoryProvider.overrideWithValue(admin),
        canReserveStockProvider.overrideWithValue(admin),
        partImageStoreProvider.overrideWithValue(store ?? _FakeStore()),
        partImagePickerProvider.overrideWithValue(picker ?? _FakePicker()),
      ],
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: page,
      ),
    );
  }

  void tw(String name, Future<void> Function(WidgetTester t, List<String> overflows) body) {
    testWidgets(name, (t) async {
      final list = <String>[];
      final prev = FlutterError.onError;
      FlutterError.onError = (d) {
        if (d.exceptionAsString().contains('overflowed')) {
          list.add(d.exceptionAsString());
          // ignore: avoid_print
          print('OVF: ${d.toString().split('\n').take(16).join('\n')}');
          return;
        }
        prev?.call(d);
      };
      try {
        await body(t, list);
      } finally {
        FlutterError.onError = prev;
      }
    });
  }

  Future<void> pumpAll(WidgetTester t) async {
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  void setSize(WidgetTester t, Size s) {
    t.view.physicalSize = s;
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
  }

  for (final size in _sizes) {
    final tag = '${size.width.toInt()}x${size.height.toInt()}';

    group('part sheet $tag', () {
      Future<void> openSheet(WidgetTester t, _FakeStore store,
          {bool admin = false, String? img = 'part-images/t/1.jpg'}) async {
        setSize(t, size);
                final repo = _MemRepo([_p('1', 'LF3000', name: 'Fleetguard lube filter, spin-on, 4.5" tall', img: img)]);
        await t.pumpWidget(host(const StockPage(), repo, admin: admin, store: store));
        await pumpAll(t);
        await t.tap(find.ancestor(of: find.text('LF3000').first, matching: find.byType(ListTile)).first);
        await pumpAll(t);
        return;
      }

      tw('shows the image and the description', (t, overflows) async {
        await openSheet(t, _FakeStore(bytes: Uint8List.fromList(_png)));
        final open = find.byKey(const Key('part_image_open'));
        expect(open, findsOneWidget);
        expect(find.descendant(of: open, matching: find.byType(Image)), findsOneWidget);
        expect(find.descendant(of: open, matching: find.byIcon(Icons.inventory_2_outlined)), findsNothing);
        expect(find.text('Fleetguard lube filter, spin-on, 4.5" tall'), findsWidgets);
        expect(overflows, isEmpty);
      });

      tw('placeholder when the store returns null', (t, overflows) async {
        await openSheet(t, _FakeStore());
        expect(find.descendant(of: find.byKey(const Key('part_image_open')), matching: find.byIcon(Icons.inventory_2_outlined)), findsOneWidget);
        expect(overflows, isEmpty);
      });

      tw('placeholder when the store throws', (t, overflows) async {
        await openSheet(t, _FakeStore(throwOnLoad: true));
        expect(find.descendant(of: find.byKey(const Key('part_image_open')), matching: find.byIcon(Icons.inventory_2_outlined)), findsOneWidget);
        expect(overflows, isEmpty);
      });

      tw('no image block when the part has no photo', (t, overflows) async {
        await openSheet(t, _FakeStore(bytes: Uint8List.fromList(_png)), img: null);
        expect(find.byKey(const Key('part_image_open')), findsNothing);
      });

      tw('full-screen viewer opens and closes', (t, overflows) async {
        await openSheet(t, _FakeStore(bytes: Uint8List.fromList(_png)));
        await t.tap(find.byKey(const Key('part_image_open')));
        await pumpAll(t);
        expect(find.byKey(const Key('part_image_viewer')), findsOneWidget);
        await t.tap(find.byKey(const Key('part_image_close')));
        await pumpAll(t);
        expect(find.byKey(const Key('part_image_viewer')), findsNothing);
      });
    });

    group('catalog $tag', () {
      tw('rows have thumbnails and nothing overflows', (t, overflows) async {
        setSize(t, size);
                final repo = _MemRepo([
          _p('1', 'LF3000', name: 'Fleetguard lube filter, spin-on, 4.5" tall', img: 'part-images/t/1.jpg'),
          _p('2', 'AF25550'),
        ]);
        await t.pumpWidget(host(const PartsCatalogPage(), repo,
            admin: false, store: _FakeStore(bytes: Uint8List.fromList(_png))));
        await pumpAll(t);
        expect(find.byType(Image), findsOneWidget);
        expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
        expect(find.text('Fleetguard lube filter, spin-on, 4.5" tall'), findsOneWidget);
        expect(find.byKey(const Key('catalog_menu')), findsNothing);
        expect(overflows, isEmpty);
      });

      tw('editor: attach, replace, remove (admin)', (t, overflows) async {
        setSize(t, size);
                final repo = _MemRepo([_p('1', 'LF3000')]);
        final store = _FakeStore();
        final picker = _FakePicker();
        await t.pumpWidget(host(const PartsCatalogPage(), repo,
            admin: true, store: store, picker: picker));
        await pumpAll(t);
        await t.tap(find.text('LF3000'));
        await pumpAll(t);

        expect(find.text('Add photo'), findsOneWidget);
        expect(find.text('Remove'), findsNothing);
        await t.tap(find.byKey(const Key('part_photo_add')));
        await pumpAll(t);
        await t.tap(find.byKey(const Key('photo_gallery')));
        await pumpAll(t);
        expect(picker.calls, 1);
        expect(find.byKey(const Key('part_photo_preview')), findsOneWidget);
        expect(find.text('Replace'), findsOneWidget);
        expect(find.text('Remove'), findsOneWidget);

        // Replace picks again.
        await t.tap(find.byKey(const Key('part_photo_add')));
        await pumpAll(t);
        await t.tap(find.byKey(const Key('photo_camera')));
        await pumpAll(t);
        expect(picker.calls, 2);

        await t.ensureVisible(find.byKey(const Key('part_save')));
        await t.tap(find.byKey(const Key('part_save')));
        await pumpAll(t);
        expect(store.saved, ['1']);
        expect(repo.list.single.imagePath, 'part-images/t/1.jpg');

        // Open again and remove.
        await t.tap(find.text('LF3000'));
        await pumpAll(t);
        expect(find.text('Replace'), findsOneWidget);
        await t.tap(find.byKey(const Key('part_photo_remove')));
        await pumpAll(t);
        expect(find.text('Add photo'), findsOneWidget);
        await t.ensureVisible(find.byKey(const Key('part_save')));
        await t.tap(find.byKey(const Key('part_save')));
        await pumpAll(t);
        expect(store.removed, ['1']);
        expect(repo.list.single.imagePath, isNull);
        expect(overflows, isEmpty);
      });

      tw('cleanup clears generic names after confirming', (t, overflows) async {
        setSize(t, size);
                final repo = _MemRepo([
          _p('1', 'A1', name: 'Air filter', slot: MaterialSlot.airFilter),
          _p('2', 'B1', name: 'Battery', slot: MaterialSlot.battery),
          _p('3', 'C1', name: 'Fleetguard lube filter'),
        ]);
        await t.pumpWidget(host(const PartsCatalogPage(), repo, admin: true));
        await pumpAll(t);
        await t.tap(find.byKey(const Key('catalog_menu')));
        await pumpAll(t);
        await t.tap(find.text('Clean up generic names'));
        await pumpAll(t);
        expect(find.textContaining('2 parts have'), findsOneWidget);
        await t.tap(find.byKey(const Key('confirm_cleanup')));
        await pumpAll(t);
        final byId = {for (final p in repo.list) p.id: p.name};
        expect(byId, {'1': '', '2': '', '3': 'Fleetguard lube filter'});
        expect(find.text('Cleared 2 descriptions'), findsOneWidget);
        expect(overflows, isEmpty);
      });
    });
  }

  tw('editor has no photo buttons for a non-admin', (t, overflows) async {
    setSize(t, _sizes.first);
    // The editor is only reachable by admins; if it is ever shown to someone
    // else it must not offer photo changes.
    final repo = _MemRepo([_p('1', 'LF3000')]);
    await t.pumpWidget(host(
      Consumer(
          builder: (context, ref, _) => Scaffold(
                body: TextButton(
                  onPressed: () => showPartEditorSheet(context, ref,
                      part: _p('1', 'LF3000', img: 'part-images/t/1.jpg')),
                  child: const Text('open'),
                ),
              )),
      repo,
      admin: false,
    ));
    await t.tap(find.text('open'));
    await pumpAll(t);
    expect(find.byKey(const Key('part_number')), findsOneWidget);
    expect(find.byKey(const Key('part_photo_add')), findsNothing);
  });
}
