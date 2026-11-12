import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/services/pdf/pdf_service.dart';
import 'package:voltcore/core/theme/app_theme.dart';
import 'package:voltcore/modules/maintenance/infra/models/maintenance_record.dart';
import 'package:voltcore/modules/maintenance/infra/repositories/maintenance_hive_repository.dart';
import 'package:voltcore/modules/maintenance/presenter/utils/maintenance_pdf_actions.dart';

/// A repo that "generates" instantly (or fails) without Hive or a real PDF.
class _FakeRepo extends MaintenanceRepo {
  _FakeRepo({this.fail = false});

  final bool fail;
  int exports = 0;

  @override
  Future<PdfExportResult> exportMaintenancePdf(
    MaintenanceRecord record, {
    bool share = true,
  }) async {
    exports++;
    if (fail) throw StateError('boom');
    return const PdfExportResult(filePath: '/tmp/report_abc.pdf');
  }
}

void main() {
  Future<void> pumpButton(
    WidgetTester tester,
    Future<void> Function(BuildContext) onTap,
  ) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => onTap(context),
            child: const Text('export'),
          ),
        ),
      ),
    ));
  }

  testWidgets('exporting from the list shows progress, then the saved PDF '
      'with an Open action', (tester) async {
    final repo = _FakeRepo();
    final record = MaintenanceRecord(id: 'r1');

    await pumpButton(
      tester,
      (c) => exportMaintenancePdfWithFeedback(c, repo, record),
    );
    await tester.tap(find.text('export'));
    await tester.pump(); // progress snackbar
    expect(tester.takeException(), isNull);

    await tester.pump(const Duration(milliseconds: 400));
    expect(repo.exports, 1);
    expect(find.text('PDF saved'), findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a failed export says so and offers Retry', (tester) async {
    final repo = _FakeRepo(fail: true);

    await pumpButton(
      tester,
      (c) => exportMaintenancePdfWithFeedback(c, repo, MaintenanceRecord(id: 'r')),
    );
    await tester.tap(find.text('export'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Could not generate the PDF'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the saved-PDF snackbar used after saving a record works',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showMaintenancePdfSavedSnack(
              ScaffoldMessenger.of(context),
              Navigator.of(context),
              const PdfExportResult(filePath: '/tmp/x.pdf'),
              message: 'Maintenance record saved and PDF generated',
            ),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Maintenance record saved and PDF generated'),
        findsOneWidget);
    expect(find.text('Open'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
