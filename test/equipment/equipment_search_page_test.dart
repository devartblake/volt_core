import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voltcore/core/theme/status_colors.dart';
import 'package:voltcore/modules/equipment/domain/entities/equipment_entity.dart'
    as domain;
import 'package:voltcore/modules/equipment/presenter/asset_code_scanner.dart';
import 'package:voltcore/modules/equipment/presenter/pages/equipment_search_page.dart';
import 'package:voltcore/modules/equipment/presenter/recent_equipment_searches_provider.dart';
import 'package:voltcore/providers/equipment_providers.dart';

import 'recent_equipment_searches_test.dart' show FakeRecentEquipmentStorage;

class FakeScanner implements AssetCodeScanner {
  FakeScanner({this.supported = true, this.result});
  final bool supported;
  final String? result;
  int scans = 0;

  @override
  bool get isSupported => supported;

  @override
  Future<String?> scan(BuildContext context) async {
    scans++;
    return result;
  }
}

final _assets = [
  Equipment(
    id: 'a1',
    name: 'Generator Alpha',
    make: 'Caterpillar',
    model: 'C32',
    serialNumber: 'CAT-001',
    voltage: '480V',
    location: '100 Broadway',
    siteCode: 'AS-100',
    lastInspection: DateTime.now().subtract(const Duration(days: 3)),
    inspectionCount: 2,
  ),
  const Equipment(
    id: 'a2',
    name: 'Switchgear Beta',
    make: 'Eaton',
    model: 'Pow-R',
    serialNumber: 'EAT-777',
    voltage: '208V',
    location: '5 Main St',
    assetType: domain.AssetType.switchgear,
    status: EquipmentStatus.maintenance,
    hasInspectionLink: false,
  ),
];

/// Hive-free: providers are overridden, nothing touches disk.
Widget _app({
  FakeRecentEquipmentStorage? storage,
  AssetCodeScanner? scanner,
  double textScale = 1.0,
}) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => const EquipmentSearchPage()),
    GoRoute(
      path: '/nameplate/:id',
      builder: (_, s) =>
          Scaffold(body: Text('NAMEPLATE ${s.pathParameters['id']}')),
    ),
    GoRoute(
      path: '/equipment/history/:id',
      builder: (_, s) =>
          Scaffold(body: Text('HISTORY ${s.pathParameters['id']}')),
    ),
  ]);
  return ProviderScope(
    overrides: [
      equipmentListProvider.overrideWith((ref) async => _assets),
      recentEquipmentSearchStorageProvider
          .overrideWithValue(storage ?? FakeRecentEquipmentStorage()),
      assetCodeScannerProvider
          .overrideWithValue(scanner ?? FakeScanner(supported: false)),
    ],
    child: MaterialApp.router(
      theme: ThemeData(extensions: const [StatusColors.light]),
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
}

/// The page chrome has an indefinitely animating sync indicator, so
/// pumpAndSettle never returns.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void _size(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

const _phone = Size(360, 800);
const _tablet = Size(1280, 800);

void main() {
  group('phone layout', () {
    testWidgets('lists results; no detail pane; tap opens the inspection',
        (tester) async {
      _size(tester, _phone);
      await tester.pumpWidget(_app());
      await _settle(tester);

      expect(find.text('Generator Alpha'), findsOneWidget);
      expect(find.text('Switchgear Beta'), findsOneWidget);
      expect(find.text('Select an asset'), findsNothing);
      expect(find.text('View history'), findsOneWidget);

      await tester.tap(find.text('Generator Alpha'));
      await _settle(tester);
      expect(find.text('NAMEPLATE a1'), findsOneWidget);
    });

    testWidgets('View history opens the history route', (tester) async {
      _size(tester, _phone);
      await tester.pumpWidget(_app());
      await _settle(tester);

      await tester.tap(find.text('View history'));
      await _settle(tester);
      expect(find.text('HISTORY a1'), findsOneWidget);
    });

    testWidgets('1.3x text does not overflow', (tester) async {
      _size(tester, _phone);
      await tester.pumpWidget(_app(
        textScale: 1.3,
        storage: FakeRecentEquipmentStorage(['CAT-001', 'Broadway']),
        scanner: FakeScanner(),
      ));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Generator Alpha'), findsOneWidget);
    });
  });

  group('tablet layout', () {
    testWidgets('shows a detail pane and selecting does not navigate',
        (tester) async {
      _size(tester, _tablet);
      await tester.pumpWidget(_app());
      await _settle(tester);

      expect(find.text('Select an asset'), findsOneWidget);
      expect(find.text('View history'), findsNothing);

      await tester.tap(find.text('Generator Alpha'));
      await _settle(tester);

      expect(find.text('NAMEPLATE a1'), findsNothing);
      expect(find.text('Select an asset'), findsNothing);
      expect(find.text('Make / model'), findsOneWidget);
      expect(find.text('Open inspection'), findsOneWidget);
      expect(find.text('Open full history'), findsOneWidget);
      expect(find.text('Parts profile'), findsOneWidget);
    });

    testWidgets('pane actions follow the selected asset', (tester) async {
      _size(tester, _tablet);
      await tester.pumpWidget(_app());
      await _settle(tester);

      await tester.tap(find.text('Switchgear Beta'));
      await _settle(tester);

      // Registered but never inspected, and not a generator.
      expect(find.text('Open inspection'), findsNothing);
      expect(find.text('Open full history'), findsNothing);
      expect(find.text('Parts profile'), findsNothing);
      expect(find.text('Edit site assignment'), findsOneWidget);
    });

    testWidgets('Open full history navigates', (tester) async {
      _size(tester, _tablet);
      await tester.pumpWidget(_app());
      await _settle(tester);

      await tester.tap(find.text('Generator Alpha'));
      await _settle(tester);
      await tester.ensureVisible(find.text('Open full history'));
      await _settle(tester);
      await tester.tap(find.text('Open full history'));
      await _settle(tester);
      expect(find.text('HISTORY a1'), findsOneWidget);
    });

    testWidgets('selection clears when the asset is filtered out',
        (tester) async {
      _size(tester, _tablet);
      await tester.pumpWidget(_app());
      await _settle(tester);

      await tester.tap(find.text('Generator Alpha'));
      await _settle(tester);
      expect(find.text('Open inspection'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'EAT-777');
      await _settle(tester);
      expect(find.text('Open inspection'), findsNothing);
      expect(find.text('Select an asset'), findsOneWidget);
    });

    testWidgets('1.3x text does not overflow, with and without selection',
        (tester) async {
      _size(tester, _tablet);
      await tester.pumpWidget(_app(
        textScale: 1.3,
        storage: FakeRecentEquipmentStorage(['CAT-001']),
        scanner: FakeScanner(),
      ));
      await _settle(tester);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Generator Alpha'));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Open full history'), findsOneWidget);
    });
  });

  group('recent searches', () {
    testWidgets('shows chips when empty; tap fills the field', (tester) async {
      _size(tester, _phone);
      await tester.pumpWidget(
          _app(storage: FakeRecentEquipmentStorage(['EAT-777', 'CAT-001'])));
      await _settle(tester);

      expect(find.text('Recent searches'), findsOneWidget);
      expect(find.widgetWithText(ActionChip, 'EAT-777'), findsOneWidget);

      await tester.tap(find.widgetWithText(ActionChip, 'EAT-777'));
      await _settle(tester);

      expect(find.text('Recent searches'), findsNothing);
      expect(find.text('Generator Alpha'), findsNothing);
      expect(find.text('Switchgear Beta'), findsOneWidget);
    });

    testWidgets('submitting stores the query; Clear removes them',
        (tester) async {
      _size(tester, _phone);
      final storage = FakeRecentEquipmentStorage();
      await tester.pumpWidget(_app(storage: storage));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), '  cat   001 ');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await _settle(tester);
      expect(storage.value, ['cat 001']);

      await tester.enterText(find.byType(TextField), '');
      await _settle(tester);
      expect(find.widgetWithText(ActionChip, 'cat 001'), findsOneWidget);

      await tester.tap(find.widgetWithText(TextButton, 'Clear'));
      await _settle(tester);
      expect(storage.value, isEmpty);
      expect(find.text('Recent searches'), findsNothing);
    });

    testWidgets('opening a result remembers the query', (tester) async {
      _size(tester, _phone);
      final storage = FakeRecentEquipmentStorage();
      await tester.pumpWidget(_app(storage: storage));
      await _settle(tester);

      await tester.enterText(find.byType(TextField), 'CAT-001');
      await _settle(tester);
      await tester.tap(find.text('Generator Alpha'));
      await _settle(tester);
      expect(storage.value, ['CAT-001']);
    });
  });

  group('scan', () {
    testWidgets('button hidden when scanning is unsupported', (tester) async {
      _size(tester, _phone);
      await tester.pumpWidget(_app(scanner: FakeScanner(supported: false)));
      await _settle(tester);
      expect(find.byTooltip('Scan'), findsNothing);
    });

    testWidgets('scanned text fills the search field', (tester) async {
      _size(tester, _phone);
      final scanner = FakeScanner(result: 'EAT-777');
      await tester.pumpWidget(_app(scanner: scanner));
      await _settle(tester);

      await tester.tap(find.byTooltip('Scan'));
      await _settle(tester);

      expect(scanner.scans, 1);
      expect(find.widgetWithText(TextField, 'EAT-777'), findsOneWidget);
      expect(find.text('Generator Alpha'), findsNothing);
      expect(find.text('Switchgear Beta'), findsOneWidget);
    });

    testWidgets('cancelled scan leaves the field alone', (tester) async {
      _size(tester, _phone);
      await tester.pumpWidget(_app(scanner: FakeScanner(result: null)));
      await _settle(tester);

      await tester.tap(find.byTooltip('Scan'));
      await _settle(tester);
      expect(find.text('Generator Alpha'), findsOneWidget);
      expect(find.text('Switchgear Beta'), findsOneWidget);
    });
  });
}
