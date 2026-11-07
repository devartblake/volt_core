import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/services/storage/pdf_library_service.dart';
import 'package:voltcore/modules/documents/domain/document_hub.dart';
import 'package:voltcore/modules/documents/presenter/pages/document_library_page.dart';
import 'package:voltcore/shared/widgets/app_page.dart';

// Wednesday 2026-11-11 12:00.
final _now = DateTime(2026, 11, 11, 12);

PdfDocumentInfo _doc(String name, PdfCategory c, DateTime m,
        [int size = 1000]) =>
    PdfDocumentInfo(
      path: '/pdfs/$name',
      name: name,
      category: c,
      sizeBytes: size,
      modified: m,
    );

void main() {
  final docs = [
    _doc('a_insp.pdf', PdfCategory.inspection, DateTime(2026, 11, 11, 8), 500),
    _doc('b_maint.pdf', PdfCategory.maintenance, DateTime(2026, 11, 10), 3000),
    _doc('c_veh.pdf', PdfCategory.vehicle, DateTime(2026, 11, 2), 2000),
    _doc('d_other.pdf', PdfCategory.other, DateTime(2026, 8, 1), 4000),
    _doc('E_old.pdf', PdfCategory.maintenance, DateTime(2026, 5, 1), 10),
  ];

  group('pure logic', () {
    test('search is case-insensitive on name', () {
      expect(searchDocuments(docs, ' OLD ').map((d) => d.name), ['E_old.pdf']);
      expect(searchDocuments(docs, '').length, 5);
    });

    test('filter and counts', () {
      final counts = countByType(docs);
      expect(counts[DocumentTypeFilter.all], 5);
      expect(counts[DocumentTypeFilter.maintenance], 2);
      expect(counts[DocumentTypeFilter.vehicles], 1);
      expect(filterByType(docs, DocumentTypeFilter.other).single.name,
          'd_other.pdf');
    });

    test('sorting', () {
      expect(sortDocuments(docs, DocumentSort.newest).first.name, 'a_insp.pdf');
      expect(sortDocuments(docs, DocumentSort.name).first.name, 'a_insp.pdf');
      expect(sortDocuments(docs, DocumentSort.name).last.name, 'E_old.pdf');
      expect(sortDocuments(docs, DocumentSort.size).first.name, 'd_other.pdf');
    });

    test('date grouping', () {
      final g = groupByDate(sortDocuments(docs, DocumentSort.newest), _now);
      expect(g.map((e) => e.label),
          ['Today', 'This week', 'This month', 'Older']);
      expect(g[0].documents.single.name, 'a_insp.pdf');
      expect(g[1].documents.single.name, 'b_maint.pdf');
      expect(g[2].documents.single.name, 'c_veh.pdf');
      expect(g[3].documents.length, 2);
    });

    test('empty groups omitted, future counts as today', () {
      final g = groupByDate(
          [_doc('f.pdf', PdfCategory.other, DateTime(2027, 1, 1))], _now);
      expect(g.single.label, 'Today');
      expect(groupByDate(const [], _now), isEmpty);
    });

    test('older than 90 days', () {
      expect(documentsOlderThan(docs, _now).map((d) => d.name),
          ['d_other.pdf', 'E_old.pdf']);
    });

    test('summary and size format', () {
      expect(formatSize(512), '512 B');
      expect(formatSize(8808038), '8.4 MB');
      expect(summaryLabel([docs.first]), '1 document, 500 B');
      expect(summaryLabel(docs), '5 documents, 9.3 KB');
    });
  });

  group('page', () {
    late List<PdfDocumentInfo> store;
    late List<String> deleted;

    Future<void> pump(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c)
              .copyWith(textScaler: const TextScaler.linear(1.3)),
          child: child!,
        ),
        home: AppShellScope(
          isCompact: size.width < 600,
          drawer: null,
          child: DocumentLibraryPage(
            loadDocuments: () async => List.of(store),
            deleteDocument: (p) async {
              deleted.add(p);
              store.removeWhere((d) => d.path == p);
            },
            now: () => _now,
            undoWindow: const Duration(seconds: 2),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();
    }

    void noOverflow(WidgetTester tester) {
      Object? e;
      while ((e = tester.takeException()) != null) {
        if (!e.toString().contains('overflowed')) throw e!;
      }
    }

    setUp(() {
      store = List.of(docs);
      deleted = [];
    });

    for (final size in const [Size(400, 800), Size(900, 1200)]) {
      testWidgets('summary, chips, headers at ${size.width.toInt()}',
          (tester) async {
        await pump(tester, size);
        noOverflow(tester);
        expect(find.text('5 documents, 9.3 KB'), findsOneWidget);
        expect(find.text('All (5)'), findsOneWidget);
        expect(find.text('Maintenance (2)'), findsOneWidget);
        expect(find.text('Today'), findsOneWidget);
        expect(find.text('Clear old files'), findsOneWidget);

        await tester.ensureVisible(find.text('Other (1)'));
        await tester.pump();
        await tester.tap(find.text('Other (1)'));
        await tester.pump();
        expect(find.text('d_other.pdf'), findsOneWidget);
        expect(find.text('a_insp.pdf'), findsNothing);
        noOverflow(tester);
      });
    }

    testWidgets('documents list builds rows lazily (300 documents)',
        (tester) async {
      store = [
        for (var i = 0; i < 300; i++)
          _doc('doc_${i.toString().padLeft(3, '0')}.pdf', PdfCategory.other,
              DateTime(2026, 11, 11, 11).subtract(Duration(minutes: i))),
      ];
      await pump(tester, const Size(400, 700));
      noOverflow(tester);
      final tiles = find.textContaining('.pdf').evaluate().length;
      expect(tiles, greaterThan(0));
      expect(tiles, lessThan(60));
      await tester.scrollUntilVisible(find.text('doc_299.pdf'), 500,
          maxScrolls: 400,
          scrollable: find
              .byWidgetPredicate((w) =>
                  w is Scrollable && w.axisDirection == AxisDirection.down)
              .first);
      expect(find.text('doc_299.pdf'), findsOneWidget);
    });

    testWidgets('per-filter empty state', (tester) async {
      store = [docs.first];
      await pump(tester, const Size(400, 800));
      await tester.ensureVisible(find.text('Vehicles (0)'));
      await tester.pump();
      await tester.tap(find.text('Vehicles (0)'));
      await tester.pump();
      expect(find.text('No vehicles documents'), findsOneWidget);
    });

    Future<void> deleteFirstRow(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Document actions').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last); // dialog confirm
      await tester.pump();
      await tester.pump();
    }

    testWidgets('delete hides row, Undo restores, nothing deleted',
        (tester) async {
      await pump(tester, const Size(400, 800));
      await deleteFirstRow(tester);
      expect(find.text('a_insp.pdf'), findsNothing);
      expect(find.text('Undo'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Undo'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(find.text('a_insp.pdf'), findsOneWidget);
      expect(deleted, isEmpty);
    });

    testWidgets('delete commits after undo window', (tester) async {
      await pump(tester, const Size(400, 800));
      await deleteFirstRow(tester);
      expect(deleted, isEmpty);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(deleted, ['/pdfs/a_insp.pdf']);
    });

    testWidgets('long-press multi-select then delete', (tester) async {
      await pump(tester, const Size(400, 800));
      await tester.longPress(find.text('a_insp.pdf'));
      await tester.pump();
      await tester.tap(find.text('b_maint.pdf'));
      await tester.pump();
      expect(find.text('2 selected'), findsOneWidget);
      await tester.tap(find.byTooltip('Delete selected'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(deleted.toSet(), {'/pdfs/a_insp.pdf', '/pdfs/b_maint.pdf'});
    });

    testWidgets('clear old files confirms with count', (tester) async {
      await pump(tester, const Size(400, 800));
      await tester.tap(find.text('Clear old files'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Delete 2 documents older than 90 days'),
          findsOneWidget);
      await tester.tap(find.text('Delete 2'));
      await tester.pump();
      await tester.pump();
      expect(deleted.toSet(), {'/pdfs/d_other.pdf', '/pdfs/E_old.pdf'});
    });
  });

  test('real file in a temp dir is deleted', () async {
    final dir = await Directory.systemTemp.createTemp('docs_hub');
    addTearDown(() => dir.delete(recursive: true));
    final f = File('${dir.path}/x.pdf')..writeAsBytesSync([1, 2, 3]);
    await PdfLibraryService.instance.deleteDocument(f.path);
    expect(f.existsSync(), isFalse);
  });
}
