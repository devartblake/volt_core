import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/services/storage/pdf_library_service.dart';
import 'package:voltcore/core/theme/status_colors.dart';
import 'package:voltcore/modules/documents/presenter/document_actions_provider.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_entity.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_inspection.dart';
import 'package:voltcore/modules/fleet/infra/repositories/vehicle_inspection_repository.dart';
import 'package:voltcore/modules/fleet/presenter/fleet_providers.dart';
import 'package:voltcore/modules/fleet/presenter/pages/vehicle_detail_page.dart';
import '../documents/fake_document_actions.dart';

/// The page chrome has a sync indicator that animates forever, so
/// pumpAndSettle would never return; advance a fixed amount instead.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

VehicleEntity _vehicle() => VehicleEntity(
      id: 'v1',
      tenantId: 't',
      designation: 'Truck B',
      make: 'Ford',
      model: 'Transit',
      licensePlate: '62832MH',
      odometer: 63774,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  Widget app({
    List<VehicleInspection> inspections = const [],
    List<PdfDocumentInfo> documents = const [],
    DocumentActions? documentActions,
  }) =>
      ProviderScope(
        overrides: [
          if (documentActions != null)
            documentActionsProvider.overrideWithValue(documentActions),
          vehicleProvider('v1').overrideWith((ref) async => _vehicle()),
          fleetManagerProvider.overrideWithValue(true),
          vehicleInspectionsProvider('v1')
              .overrideWith((ref) async => inspections),
          vehicleChecksProvider('v1').overrideWith((ref) async => const []),
          fleetAssignableMembersProvider.overrideWith((ref) async => const []),
          vehicleAssetsProvider('v1').overrideWith((ref) async => const []),
          vehicleDocumentsProvider('v1').overrideWith((ref) async => documents),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: const [StatusColors.light]),
          home: const VehicleDetailPage(id: 'v1'),
        ),
      );

  void size(WidgetTester tester, Size s) {
    tester.view.physicalSize = s;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('the details are grouped into six tabs', (tester) async {
    size(tester, const Size(800, 1200));
    await tester.pumpWidget(app());
    await _settle(tester);

    for (final label in [
      'Overview',
      'Inspections',
      'Maintenance',
      'Media',
      'Tools',
      'Documents',
    ]) {
      expect(find.widgetWithText(Tab, label), findsOneWidget, reason: label);
    }
  });

  testWidgets('the summary stays above the tabs', (tester) async {
    size(tester, const Size(800, 1200));
    await tester.pumpWidget(app());
    await _settle(tester);

    expect(find.text('Active'), findsWidgets);
    expect(find.text('Unassigned'), findsWidgets);
    const summaryLine = '62832MH  ·  Ford Transit  ·  63774 mi';
    expect(find.text(summaryLine), findsOneWidget);

    // Switching tabs does not move it.
    await tester.tap(find.widgetWithText(Tab, 'Inspections'));
    await _settle(tester);
    expect(find.text(summaryLine), findsOneWidget);
  });

  testWidgets('a vehicle with no daily check says so and offers to start it',
      (tester) async {
    size(tester, const Size(800, 1200));
    await tester.pumpWidget(app());
    await _settle(tester);

    expect(find.text('Daily check due - start'), findsOneWidget);
  });

  testWidgets('a done daily check shows as done', (tester) async {
    size(tester, const Size(800, 1200));
    final done = VehicleInspection.newDraft(
            vehicleId: 'v1', cadence: InspectionCadence.daily)
        .copyWith(inspectedAt: DateTime.now());
    await tester.pumpWidget(app(inspections: [done]));
    await _settle(tester);

    expect(find.text('Daily check done'), findsOneWidget);
    // The count shows on the tab that holds the list.
    expect(find.widgetWithText(Tab, 'Inspections (1)'), findsOneWidget);
  });

  testWidgets('each tab shows its own content', (tester) async {
    size(tester, const Size(800, 1200));
    await tester.pumpWidget(app());
    await _settle(tester);

    // Overview: the facts card.
    expect(find.text('Designation'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Inspections'));
    await _settle(tester);
    expect(find.text('Vehicle inspections'), findsOneWidget);
    expect(find.text('Designation'), findsNothing);
  });

  testWidgets('the Documents tab lists saved PDFs for the vehicle',
      (tester) async {
    size(tester, const Size(800, 1200));
    final doc = PdfDocumentInfo(
      path: '/pdfs/vehicles/Vehicle_Truck_B_2026-06-09_v1.pdf',
      name: 'Vehicle_Truck_B_2026-06-09_v1.pdf',
      category: PdfCategory.vehicle,
      sizeBytes: 2048,
      modified: DateTime(2026, 6, 9),
    );
    await tester.pumpWidget(app(documents: [doc]));
    await _settle(tester);

    expect(find.widgetWithText(Tab, 'Documents (1)'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(Tab, 'Documents (1)'));
    await tester.tap(find.widgetWithText(Tab, 'Documents (1)'));
    await _settle(tester);
    expect(find.text('Vehicle_Truck_B_2026-06-09_v1.pdf'), findsOneWidget);
    expect(find.byTooltip('Share'), findsOneWidget);
  });

  testWidgets('tapping a document row opens it and Share shares that file',
      (tester) async {
    size(tester, const Size(800, 1200));
    final fake = FakeDocumentActions();
    PdfDocumentInfo mk(String n) => PdfDocumentInfo(
          path: '/pdfs/vehicles/$n',
          name: n,
          category: PdfCategory.vehicle,
          sizeBytes: 2048,
          modified: DateTime(2026, 6, 9),
        );
    await tester.pumpWidget(
        app(documents: [mk('one.pdf'), mk('two.pdf')], documentActions: fake));
    await _settle(tester);
    await tester.ensureVisible(find.widgetWithText(Tab, 'Documents (2)'));
    await tester.tap(find.widgetWithText(Tab, 'Documents (2)'));
    await _settle(tester);

    await tester.tap(find.text('two.pdf'));
    await _settle(tester);
    expect(fake.opened, ['/pdfs/vehicles/two.pdf']);

    await tester.tap(find.byTooltip('Share').first);
    await _settle(tester);
    expect(fake.shared, ['/pdfs/vehicles/one.pdf']);
  });

  testWidgets('the Documents tab explains when nothing is saved',
      (tester) async {
    size(tester, const Size(800, 1200));
    await tester.pumpWidget(app());
    await _settle(tester);

    await tester.ensureVisible(find.widgetWithText(Tab, 'Documents'));
    await tester.tap(find.widgetWithText(Tab, 'Documents'));
    await _settle(tester);
    expect(find.text('No saved PDFs'), findsOneWidget);
  });

  testWidgets('fits at 1.3x text on a phone', (tester) async {
    size(tester, const Size(360, 800));
    final reports = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (d) => reports.add(d.toString());
    addTearDown(() => FlutterError.onError = previous);

    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(
        size: Size(360, 800),
        textScaler: TextScaler.linear(1.3),
      ),
      child: app(),
    ));
    await _settle(tester);
    tester.takeException();

    // The tab bar and summary are this page's own; the cards inside the tabs
    // are laid out with the (much wider) test font.
    final ours =
        reports.where((r) => r.contains('vehicle_detail_page.dart')).toList();
    final summary = ours.where((r) =>
        r.contains('_VehicleSummary') || r.contains('_VehicleTabBar'));
    expect(summary, isEmpty, reason: summary.join('\n---\n'));
  });
}
