import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/inventory/domain/catalog_part.dart';
import 'package:voltcore/modules/inventory/domain/import/parts_import.dart';
import 'package:voltcore/modules/inventory/domain/import/sheet_reader.dart';
import 'package:voltcore/modules/inventory/domain/stock.dart';
import 'package:voltcore/modules/inventory/infra/inventory_repository.dart';
import 'package:voltcore/modules/inventory/presenter/widgets/parts_import_sheet.dart';
import 'package:voltcore/modules/materials/domain/material_item.dart';
import 'package:voltcore/modules/materials/infra/materials_repository.dart';

class _MemRepo extends InventoryRepository {
  _MemRepo(this.catalog) : super(tenantId: () => null);

  final List<CatalogPart> catalog;
  final moves = <InventoryMovement>[];

  @override
  Future<List<CatalogPart>> parts() async => List.of(catalog);

  @override
  Future<List<StockLevel>> stock() async => computeStock(catalog, moves);

  @override
  Future<CatalogPart> savePart(CatalogPart part) async {
    catalog.removeWhere((p) => p.id == part.id);
    catalog.add(part);
    return part;
  }

  @override
  Future<InventoryMovement?> record({
    required String partId,
    required int qty,
    required MovementReason reason,
    String note = '',
    String? jobRef,
  }) async {
    final m = InventoryMovement(
        id: 'm${moves.length}', partId: partId, qtyDelta: qty, reason: reason,
        at: DateTime.now(), note: note);
    moves.add(m);
    return m;
  }
}

ParsedImport _parsed() => parseInventorySheets([
      SheetData('Stock', [
        ['Part Number', 'Description', 'Manufacturer', 'Qty'],
        ['lf3000', 'Lube filter', 'fleetguard', '4'],
        ['AF25550', 'Air filter', '', '2'],
        ['', 'no number', '', ''],
      ]),
    ]);

class _MemMaterials extends MaterialsRepository {
  _MemMaterials([Map<String, List<MaterialItem>>? seed]) : lists = seed ?? {};
  final Map<String, List<MaterialItem>> lists;

  @override
  Future<List<MaterialItem>> load(MaterialOwner owner) async =>
      lists[owner.storeKey] ?? const [];

  @override
  Future<List<MaterialItem>> save(MaterialOwner owner, List<MaterialItem> items) async {
    lists[owner.storeKey] = items;
    return items;
  }
}

ParsedImport _tracker() => parseInventorySheets([
      SheetData('Q', [
        ['School', 'Make', 'Model', 'Serial Number', 'Air Filter', '', '', '', 'Battery', '', '', '', 'Coolant Filter', '', '', ''],
        ['', '', '', '', 'Part Number', 'QTY Used', 'Date Used', 'Part Name', 'Part Number', 'QTY Used', 'Date Used', 'Part Name', 'Part Number', 'QTY Used', 'Date Used', 'Part Name'],
        ['Q1', 'Kohler', '250', '111', 'PA1', '1', '', 'Baldwin', '4D-MHD 1000 CCA RC 295', '2', '', 'Interstate', '', '', '', ''],
        ['Q2', 'Cummins', '100', '222', 'PA2', '1', '', 'Baldwin', '', '', '', '', '', '', '', ''],
      ]),
    ]);

void main() {
  void ignoreOverflow() {
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) return;
      prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);
  }

  Future<void> open(WidgetTester t, _MemRepo repo,
      {ParsedImport? parsed, _MemMaterials? mats}) async {
    await t.pumpWidget(ProviderScope(
      overrides: [
        inventoryRepositoryProvider.overrideWithValue(repo),
        materialsRepositoryProvider.overrideWithValue(mats ?? _MemMaterials()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: PartsImportPreview(
              parsed: parsed ?? _parsed(), fileName: 'parts.csv'),
        ),
      ),
    ));
    await t.pump();
    await t.pump();
  }

  testWidgets('shows what is new, existing and left out', (t) async {
    ignoreOverflow();
    final now = DateTime.utc(2026);
    final repo = _MemRepo([
      CatalogPart(id: 'x', partNumber: 'AF-25550', name: 'Air filter',
          manufacturer: 'Baldwin', createdAt: now, updatedAt: now),
    ]);
    await open(t, repo);

    expect(find.text('LF3000'), findsOneWidget);
    expect(find.text('1 new'), findsOneWidget);
    expect(find.text('Fill slot'), findsOneWidget);
    expect(find.text('1 left out'), findsWidgets);
    expect(find.text('Import 2'), findsOneWidget);
  });

  testWidgets('importing adds the part and records opening stock', (t) async {
    ignoreOverflow();
    final repo = _MemRepo([]);
    await open(t, repo);

    await t.tap(find.byKey(const Key('import_confirm')));
    await t.pump();
    await t.pump();

    expect(repo.catalog.map((p) => p.partNumber).toSet(), {'LF3000', 'AF25550'});
    expect(repo.catalog.firstWhere((p) => p.partNumber == 'LF3000').manufacturer,
        'Fleetguard');
    expect(repo.moves.map((m) => m.qtyDelta).toSet(), {4, 2});
    expect(repo.moves.first.reason, MovementReason.receive);
  });

  testWidgets('unticking a row leaves it out; opening stock can be off', (t) async {
    ignoreOverflow();
    final repo = _MemRepo([]);
    await open(t, repo);

    await t.tap(find.byKey(const ValueKey('import_row_AF25550')));
    await t.tap(find.byKey(const Key('import_opening_stock')));
    await t.pump();
    await t.tap(find.byKey(const Key('import_confirm')));
    await t.pump();
    await t.pump();

    expect(repo.catalog.map((p) => p.partNumber), ['LF3000']);
    expect(repo.moves, isEmpty);
  });

  testWidgets('generator lists are saved; one that already has a list is not',
      (t) async {
    ignoreOverflow();
    final repo = _MemRepo([]);
    final mats = _MemMaterials({
      'generator:cummins|100|222': [
        const MaterialItem(id: 'old', slot: MaterialSlot.airFilter, partNumber: 'X'),
      ],
    });
    await open(t, repo, parsed: _tracker(), mats: mats);

    expect(find.text('Import 3 parts + 1 lists'), findsOneWidget);
    await t.tap(find.byKey(const Key('import_confirm')));
    await t.pump();
    await t.pump();

    expect(mats.lists['generator:kohler|250|111']!.length, 2);
    expect(mats.lists['generator:cummins|100|222']!.single.id, 'old');
  });
}
