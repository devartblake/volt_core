import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/theme/status_colors.dart';
import 'package:voltcore/modules/inventory/domain/catalog_part.dart';
import 'package:voltcore/modules/inventory/domain/inventory_location.dart';
import 'package:voltcore/modules/inventory/domain/stock.dart';
import 'package:voltcore/modules/inventory/infra/inventory_repository.dart';
import 'package:voltcore/modules/materials/domain/material_item.dart';
import 'package:voltcore/modules/materials/domain/material_list.dart';
import 'package:voltcore/modules/materials/infra/material_usage.dart';
import 'package:voltcore/modules/materials/infra/materials_repository.dart';
import 'package:voltcore/modules/materials/presenter/materials_editor.dart';

final _t = DateTime.utc(2026, 1, 1);

class _MemMaterials extends MaterialsRepository {
  _MemMaterials(this.store);
  final Map<String, List<MaterialItem>> store;
  @override
  Future<List<MaterialItem>> load(MaterialOwner o) async =>
      store[o.storeKey] ?? const [];
  @override
  Future<List<MaterialItem>> save(MaterialOwner o, List<MaterialItem> i) async =>
      store[o.storeKey] = MaterialListOps.forSaving(i);
  @override
  Future<List<({MaterialOwnerType type, String id, List<MaterialItem> items})>>
      allJobLists() async => const [];
  @override
  Future<void> saveDraft(MaterialOwner o, List<MaterialItem> i) async =>
      store[o.storeKey] = i;
}

class _MemInventory extends InventoryRepository {
  _MemInventory() : super(tenantId: () => null);
  final parts_ = [
    CatalogPart(id: 'p', partNumber: 'AF-1', createdAt: _t, updatedAt: _t),
  ];
  final moves = <InventoryMovement>[
    InventoryMovement(
        id: 'r',
        partId: 'p',
        qtyDelta: 5,
        reason: MovementReason.receive,
        at: _t),
  ];
  var n = 0;
  @override
  Future<List<CatalogPart>> parts() async => parts_;
  @override
  Future<List<InventoryMovement>> movements({String? partId}) async => moves;
  @override
  Future<List<InventoryLocation>> locations(
          {bool includeInactive = false}) async =>
      [InventoryLocation.main()];
  @override
  Future<InventoryMovement?> movementById(String id) async =>
      moves.where((m) => m.id == id).firstOrNull;
  @override
  Future<InventoryMovement?> recordAt({
    required String locationId,
    required String partId,
    required int qty,
    required MovementReason reason,
    String note = '',
    String? jobRef,
  }) async {
    final m = InventoryMovement(
        id: 'm${n++}',
        partId: partId,
        qtyDelta: qty,
        reason: reason,
        at: _t,
        locationId: locationId,
        jobRef: jobRef);
    moves.add(m);
    return m;
  }
}

const _job = MaterialOwner.maintenance(id: 'job-1');

Future<void> _pump(WidgetTester tester, [int times = 6]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  for (final (name, size, scale) in [
    ('phone', const Size(390, 2400), 1.3),
    ('tablet', const Size(900, 2400), 1.3),
  ]) {
    testWidgets('Mark used is idempotent and undoable ($name, 1.3x text)',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final onErr = FlutterError.onError;
      FlutterError.onError = (d) {
        if (d.exceptionAsString().contains('overflowed')) return;
        onErr?.call(d);
      };
      addTearDown(() => FlutterError.onError = onErr);

      final inv = _MemInventory();
      final mats = _MemMaterials({
        _job.storeKey: [
          const MaterialItem(
              id: 'a',
              slot: MaterialSlot.airFilter,
              partNumber: 'AF-1',
              quantity: 2),
        ],
      });
      await tester.pumpWidget(ProviderScope(
        overrides: [
          materialsRepositoryProvider.overrideWithValue(mats),
          stockLevelsProvider.overrideWith((ref) async => const []),
          materialUsageServiceProvider.overrideWithValue(MaterialUsageService(
              inv,
              userId: () => 'U',
              today: () => DateTime(2026, 5, 6))),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: const [StatusColors.light]),
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: MaterialsEditor(owner: _job, mode: MaterialsMode.maintenance),
            ),
          ),
        ),
      ));
      await _pump(tester);

      final mark = find.byKey(const ValueKey('a-mark-used'));
      await tester.ensureVisible(mark);
      await tester.tap(mark);
      await _pump(tester);
      expect(mark, findsNothing); // swapped for the Used chip + Undo

      expect(inv.moves.where((m) => m.reason == MovementReason.issue),
          hasLength(1));
      expect(inv.moves.last.jobRef, 'maintenance:job-1');
      expect(mats.store[_job.storeKey]!.single.usedMovementId, isNotNull);
      expect(mats.store[_job.storeKey]!.single.dateUsed, DateTime(2026, 5, 6));
      expect(find.text('Used - stock updated'), findsOneWidget);

      final undo = find.byKey(const ValueKey('a-undo-used'));
      await tester.ensureVisible(undo);
      await tester.tap(undo);
      await _pump(tester);
      expect(inv.moves.where((m) => m.reason == MovementReason.returned),
          hasLength(1));
      expect(mats.store[_job.storeKey]!.single.usedMovementId, isNull);
      expect(find.byKey(const ValueKey('a-mark-used')), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));
    });
  }

  testWidgets('no Mark used on a generator profile', (tester) async {
    tester.view.physicalSize = const Size(600, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final mats = _MemMaterials({
      'generator:g': [
        const MaterialItem(
            id: 'a', slot: MaterialSlot.airFilter, partNumber: 'AF-1'),
      ],
    });
    await tester.pumpWidget(ProviderScope(
      overrides: [
        materialsRepositoryProvider.overrideWithValue(mats),
        stockLevelsProvider.overrideWith((ref) async => const []),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [StatusColors.light]),
        home: const Scaffold(
          body: SingleChildScrollView(
            child: MaterialsEditor(
                owner: MaterialOwner.generator(key: 'g'),
                mode: MaterialsMode.profile),
          ),
        ),
      ),
    ));
    await _pump(tester);
    expect(find.text('Mark used'), findsNothing);
  });
}
