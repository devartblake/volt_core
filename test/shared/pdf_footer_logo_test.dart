import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:voltcore/shared/presenter/layout/pdf/pdf_template.dart';

Future<List<int>> _build(PdfPageFormat format, {String site = 'Main St'}) async {
  final doc = pw.Document();
  doc.addPage(
    pw.MultiPage(
      pageFormat: format,
      margin: const pw.EdgeInsets.fromLTRB(28, 26, 28, 30),
      footer: (ctx) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8),
        child: PdfTemplate.brandFooter(
          segments: ['A&S ELECTRIC INC', 'Maintenance Report', site, 'No. ABC123'],
          pageNumber: ctx.pageNumber,
          total: ctx.pagesCount,
          bleedX: 28,
          bleedBottom: 30,
        ),
      ),
      build: (ctx) => [pw.Text('Body')],
    ),
  );
  doc.addPage(
    pw.Page(
      pageFormat: format,
      margin: pw.EdgeInsets.zero,
      build: (ctx) => pw.Align(
        alignment: pw.Alignment.bottomCenter,
        child: PdfTemplate.pageFooter(2, total: 2),
      ),
    ),
  );
  return doc.save();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    PdfTemplate.useFooterLogo(null);
    PdfTemplate.useFooterArt(null);
  });

  test('footer logo asset loads and the footer contains the SVG logo', () async {
    await PdfTemplate.loadFooterArt();
    expect(PdfTemplate.footerLogo(), isA<pw.SvgImage>());
  });

  test('footer renders valid PDFs on Letter and A4 with a long site name', () async {
    await PdfTemplate.loadFooterArt();
    final long = 'A very long site name that goes on and on ' * 4;
    for (final f in [PdfPageFormat.letter, PdfPageFormat.a4]) {
      final bytes = await _build(f, site: long);
      expect(latin1.decode(bytes.sublist(0, 4)), '%PDF');
      if (f == PdfPageFormat.letter) {
        // Preview for a visual check (build/ is git-ignored).
        Directory('build').createSync(recursive: true);
        File('build/footer_preview.pdf').writeAsBytesSync(bytes);
      }
    }
  });

  test('missing logo: footer still renders without it', () async {
    PdfTemplate.useFooterLogo(null);
    expect(PdfTemplate.footerLogo(), isNull);
    final bytes = await _build(PdfPageFormat.letter);
    expect(latin1.decode(bytes.sublist(0, 4)), '%PDF');
  });

  test('invalid SVG logo: footer still renders without it', () async {
    PdfTemplate.useFooterLogo('<svg><not valid');
    expect(PdfTemplate.footerLogo(), isNull);
    final bytes = await _build(PdfPageFormat.a4);
    expect(latin1.decode(bytes.sublist(0, 4)), '%PDF');
  });
}
