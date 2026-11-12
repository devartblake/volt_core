import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/services/storage/pdf_library_service.dart';
import 'package:voltcore/modules/documents/presenter/document_actions_provider.dart';
import 'package:voltcore/modules/documents/presenter/pages/document_library_page.dart';
import 'package:voltcore/shared/widgets/app_page.dart';

import 'fake_document_actions.dart';

void main() {
  final doc = PdfDocumentInfo(
    path: '/pdfs/a_insp.pdf',
    name: 'a_insp.pdf',
    category: PdfCategory.inspection,
    sizeBytes: 500,
    modified: DateTime(2026, 11, 11, 8),
  );

  Future<void> pump(WidgetTester tester, FakeDocumentActions fake) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [documentActionsProvider.overrideWithValue(fake)],
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
  }

  testWidgets('Open, Print and Share on a row call the injected actions',
      (tester) async {
    final fake = FakeDocumentActions();
    await pump(tester, fake);

    Future<void> choose(String item) async {
      await tester.tap(find.byTooltip('Document actions').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(item).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    await choose('Open');
    await choose('Print');
    await choose('Share');

    expect(fake.opened, ['/pdfs/a_insp.pdf']);
    expect(fake.printed, ['/pdfs/a_insp.pdf']);
    expect(fake.shared, ['/pdfs/a_insp.pdf']);
  });
}
