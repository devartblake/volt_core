import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voltcore/modules/inventory/domain/catalog_part.dart';
import 'package:voltcore/modules/inventory/domain/stock.dart';
import 'package:voltcore/modules/inventory/infra/inventory_repository.dart';
import 'package:voltcore/modules/inventory/presenter/inventory_access.dart';
import 'package:voltcore/modules/inventory/presenter/movement_providers.dart';
import 'package:voltcore/modules/inventory/presenter/pages/movements_page.dart';
import 'package:voltcore/modules/inventory/presenter/widgets/usage_report_sheet.dart';
import 'package:voltcore/modules/materials/domain/material_item.dart';
import 'package:voltcore/modules/materials/presenter/job_context_providers.dart';

final _t = DateTime.utc(2026);
final _now = DateTime(2026, 6, 15, 12);

final _parts = [
  CatalogPart(id: 'p1', partNumber: 'LF3000', name: 'Oil filter', manufacturer: 'Fleetguard', createdAt: _t, updatedAt: _t),
  CatalogPart(id: 'p2', partNumber: 'AF25', name: 'Air filter', manufacturer: 'Donaldson', createdAt: _t, updatedAt: _t),
];

final _ledger = [
  InventoryMovement(id: 'm1', partId: 'p1', qtyDelta: 10, reason: MovementReason.receive,
      at: DateTime(2026, 6, 15, 9), userId: 'user-1234567', note: 'PO 55'),
  InventoryMovement(id: 'm2', partId: 'p1', qtyDelta: -2, reason: MovementReason.issue,
      at: DateTime(2026, 6, 15, 10), userId: 'u2', jobRef: 'inspection:abc'),
  InventoryMovement(id: 'm3', partId: 'p2', qtyDelta: -4, reason: MovementReason.issue,
      at: DateTime(2026, 6, 10, 8), jobRef: 'maintenance:m9'),
  InventoryMovement(id: 'm4', partId: 'p2', qtyDelta: 3, reason: MovementReason.receive,
      at: DateTime(2026, 2, 1, 8)),
];

final _jobs = {
  'inspection:abc': const JobContext(
      type: MaterialOwnerType.inspection, id: 'abc', title: '12 Main St',
      generatorKey: 'g1', generatorLabel: 'Generac RG048, SN 1'),
  'maintenance:m9': const JobContext(
      type: MaterialOwnerType.maintenance, id: 'm9', title: '5 Oak Ave',
      generatorKey: 'g2', generatorLabel: 'Kohler 20'),
};

Widget _host(Widget home, {bool admin = false, UsageCsvExporter? export, GoRouter? router}) {
  final overrides = [
    ledgerProvider.overrideWith((ref) async => _ledger),
    catalogPartsProvider.overrideWith((ref) async => _parts),
    memberNamesProvider.overrideWith((ref) async => {'u2': 'Dana Tech'}),
    jobContextsProvider.overrideWith((ref) => _jobs),
    canManageInventoryProvider.overrideWithValue(admin),
    lastPaidByPartProvider.overrideWith((ref) async => {'p1': 1000}),
    if (export != null) usageCsvExporterProvider.overrideWithValue(export),
  ];
  return ProviderScope(
    overrides: overrides,
    child: router != null
        ? MaterialApp.router(routerConfig: router)
        : MaterialApp(home: home),
  );
}

void _quiet() {
  final prev = FlutterError.onError;
  FlutterError.onError = (d) {
    if (d.exceptionAsString().contains('overflowed')) return;
    prev?.call(d);
  };
  addTearDown(() => FlutterError.onError = prev);
}

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

Widget _scaled(Widget child) => MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
      child: child,
    );

void main() {
  for (final size in [const Size(390, 2600), const Size(1024, 1800)]) {
    testWidgets('lists the ledger newest first, grouped by day, at 1.3x on ${size.width.toInt()}px', (t) async {
      _quiet();
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(_host(_scaled(MovementsPage(now: () => _now))));
      await _settle(t);

      // 30 days by default: the February receipt is out.
      expect(find.byKey(const Key('qty_m1')), findsOneWidget);
      expect(find.byKey(const Key('qty_m2')), findsOneWidget);
      expect(find.byKey(const Key('qty_m3')), findsOneWidget);
      expect(find.byKey(const Key('qty_m4')), findsNothing);
      expect(t.widget<Text>(find.byKey(const Key('qty_m1'))).data, '+10');
      expect(t.widget<Text>(find.byKey(const Key('qty_m2'))).data, '-2');
      // Newest first.
      expect(t.getTopLeft(find.byKey(const Key('qty_m2'))).dy,
          lessThan(t.getTopLeft(find.byKey(const Key('qty_m1'))).dy));
      expect(find.text('Dana Tech'), findsOneWidget);
      expect(find.text('user-1'), findsOneWidget);
      expect(find.text('PO 55'), findsOneWidget);
      expect(find.text('Inspection · 12 Main St'), findsOneWidget);
      expect(find.text('Maintenance · 5 Oak Ave'), findsOneWidget);
    });
  }

  testWidgets('reason chips, period and part search filter the list', (t) async {
    _quiet();
    t.view.physicalSize = const Size(900, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(MovementsPage(now: () => _now)));
    await _settle(t);

    await t.tap(find.byKey(const Key('reason_issue')));
    await t.pump();
    expect(find.byKey(const Key('qty_m1')), findsNothing);
    expect(find.byKey(const Key('qty_m2')), findsOneWidget);

    await t.tap(find.byKey(const Key('reason_issue')));
    await t.tap(find.byKey(const Key('period_all')));
    await t.pump();
    expect(find.byKey(const Key('qty_m4')), findsOneWidget);

    await t.enterText(find.byKey(const Key('movement_search')), 'air');
    await t.pump();
    expect(find.byKey(const Key('qty_m4')), findsOneWidget);
    expect(find.byKey(const Key('qty_m1')), findsNothing);

    await t.enterText(find.byKey(const Key('movement_search')), 'zzz');
    await t.pump();
    expect(find.text('Nothing matches'), findsOneWidget);
  });

  testWidgets('tapping a job reference opens the job', (t) async {
    _quiet();
    final router = GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => MovementsPage(now: () => _now)),
      GoRoute(path: '/inspections/detail/:id', builder: (_, s) => Text('inspection ${s.pathParameters['id']}')),
      GoRoute(path: '/maintenance/detail/:id', builder: (_, s) => Text('maintenance ${s.pathParameters['id']}')),
    ]);
    await t.pumpWidget(_host(const SizedBox(), router: router));
    await _settle(t);
    await t.tap(find.byKey(const Key('job_m2')));
    await _settle(t);
    expect(find.text('inspection abc'), findsOneWidget);
  });

  testWidgets('usage report: totals by part, generator, cost for admins, CSV export', (t) async {
    _quiet();
    t.view.physicalSize = const Size(900, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final shared = <(String, String)>[];
    await t.pumpWidget(_host(
      _scaled(Scaffold(body: UsageReportView(now: () => _now))),
      admin: true,
      export: (name, csv) async => shared.add((name, csv)),
    ));
    await _settle(t);

    expect(find.text('Parts usage'), findsOneWidget);
    expect(find.text('By part'), findsOneWidget);
    expect(find.text('LF3000'), findsOneWidget);
    expect(find.text('Generac RG048, SN 1'), findsOneWidget);
    expect(find.text('Kohler 20'), findsOneWidget);
    // 2 x $10.00 for the oil filter; the air filter has no price.
    expect(find.text(r'$20.00'), findsWidgets);
    expect(find.textContaining('no price paid'), findsOneWidget);

    await t.tap(find.byKey(const Key('export_usage_csv')));
    await t.pump();
    expect(shared.single.$1, 'parts-usage-20260615.csv');
    expect(shared.single.$2, contains('Breakdown,Name,Detail,Qty issued,Cost'));
    expect(shared.single.$2, contains('Part,LF3000'));
  });

  testWidgets('usage report hides cost for non-admins', (t) async {
    _quiet();
    t.view.physicalSize = const Size(900, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final shared = <(String, String)>[];
    await t.pumpWidget(_host(
      Scaffold(body: UsageReportView(now: () => _now)),
      export: (name, csv) async => shared.add((name, csv)),
    ));
    await _settle(t);
    expect(find.text('Cost'), findsNothing);
    expect(find.textContaining(r'$'), findsNothing);
    await t.tap(find.byKey(const Key('export_usage_csv')));
    await t.pump();
    expect(shared.single.$2, isNot(contains('Cost')));
  });

  testWidgets('usage report period chips narrow the window', (t) async {
    _quiet();
    t.view.physicalSize = const Size(900, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(Scaffold(body: UsageReportView(now: () => _now))));
    await _settle(t);
    expect(find.text('AF25'), findsOneWidget);
    await t.tap(find.byKey(const Key('usage_period_days30')));
    await t.pump();
    expect(find.text('AF25'), findsOneWidget); // 10 June is inside 30 days
    await t.pumpWidget(_host(Scaffold(body: UsageReportView(now: () => DateTime(2027, 6, 15)))));
    await _settle(t);
    await t.tap(find.byKey(const Key('usage_period_days30')));
    await t.pump();
    expect(find.text('Nothing issued'), findsOneWidget);
  });
}
