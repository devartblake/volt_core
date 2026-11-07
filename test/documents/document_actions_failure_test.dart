import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/services/storage/pdf_library_service.dart';
import 'package:voltcore/modules/documents/presenter/document_actions.dart';
import 'package:voltcore/modules/documents/presenter/document_actions_provider.dart';
import 'package:voltcore/modules/documents/presenter/pages/document_library_page.dart';
import 'package:voltcore/shared/widgets/app_page.dart';

import 'fake_document_actions.dart';

class _ThrowingActions extends FakeDocumentActions {
  @override
  Future<bool> share(BuildContext context, PdfDocumentInfo doc) async =>
      throw StateError('boom');
}

void main() {
  PdfDocumentInfo info(String path) => PdfDocumentInfo(
        path: path,
        name: 'a_insp.pdf',
        category: PdfCategory.inspection,
        sizeBytes: 5,
        modified: DateTime(2026, 11, 11, 8),
      );

  late BuildContext ctx;
  Future<void> pumpHost(WidgetTester tester) => tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        })),
      ));

  testWidgets('sharePdfDocument: share failure shows error, returns false',
      (tester) async {
    await pumpHost(tester);
    final dir = await tester.runAsync(() => Directory.systemTemp.createTemp());
    final file = File('${dir!.path}/a_insp.pdf');
    await tester.runAsync(() => file.writeAsBytes([1, 2, 3]));
    // No share plugin in the test host: the platform call throws.
    final ok = await tester
        .runAsync(() => sharePdfDocument(ctx, info(file.path)));
    await tester.pump();
    expect(ok, isFalse);
    expect(find.text('Could not share a_insp.pdf. Please try again.'),
        findsOneWidget);
    expect(find.textContaining('MissingPlugin'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => dir.delete(recursive: true));
  });

  testWidgets('shareManyPdfDocuments: failure shows error, returns 0',
      (tester) async {
    await pumpHost(tester);
    final dir = await tester.runAsync(() => Directory.systemTemp.createTemp());
    final file = File('${dir!.path}/a_insp.pdf');
    await tester.runAsync(() => file.writeAsBytes([1, 2, 3]));
    final n = await tester
        .runAsync(() => shareManyPdfDocuments(ctx, [info(file.path)]));
    await tester.pump();
    expect(n, 0);
    expect(find.text('Could not share the reports. Please try again.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => dir.delete(recursive: true));
  });

  testWidgets('sharePdfDocument: missing file is an info, not an error',
      (tester) async {
    await pumpHost(tester);
    final ok = await tester
        .runAsync(() => sharePdfDocument(ctx, info('/nope/missing.pdf')));
    await tester.pump();
    expect(ok, isFalse);
    expect(find.text('File no longer exists'), findsOneWidget);
  });

  testWidgets('library page: a throwing DocumentActions shows an error',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final doc = info('/pdfs/a_insp.pdf');
    await tester.pumpWidget(ProviderScope(
      overrides: [
        documentActionsProvider.overrideWithValue(_ThrowingActions())
      ],
      child: MaterialApp(
        home: AppShellScope(
          isCompact: false,
          drawer: null,
          child: DocumentLibraryPage(
            loadDocuments: () async => [doc],
            now: () => DateTime(2026, 11, 11, 12),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byTooltip('Document actions').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Share').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Could not share a_insp.pdf. Please try again.'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
