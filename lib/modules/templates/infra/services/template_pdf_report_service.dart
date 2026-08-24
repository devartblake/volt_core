import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/template_entities.dart';
import '../../domain/services/template_response_validation.dart';

typedef TemplateReportAttachmentResolver = Future<Uint8List?> Function(
  FormTemplateField field,
  Object value,
);

/// Generates a customer-ready PDF from one immutable template revision and one
/// response pinned to that revision.
///
/// This intentionally shares Voltcore's existing Noto Sans assets and US Letter
/// page format so template-driven reports can be compared against the legacy
/// generator report during the Phase 3 pilot.
class TemplatePdfReportService {
  const TemplatePdfReportService();

  static const _validator = TemplateResponseValidator();

  Future<Uint8List> build({
    required FormTemplateDefinition definition,
    required FormResponse response,
    TemplateReportAttachmentResolver? attachmentResolver,
  }) async {
    _requirePinnedRevision(definition, response);

    final baseFontData = await rootBundle.load(
      'assets/fonts/NotoSans/NotoSans-Regular.ttf',
    );
    final boldFontData = await rootBundle.load(
      'assets/fonts/NotoSans/NotoSans-Bold.ttf',
    );
    final baseFont = pw.Font.ttf(baseFontData);
    final boldFont = pw.Font.ttf(boldFontData);
    final attachmentBytes = await _loadAttachments(
      definition: definition,
      response: response,
      resolver: attachmentResolver,
    );

    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
    );
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.fromLTRB(32, 32, 32, 36),
        header: (context) => _header(definition, response, context),
        footer: (context) => _footer(context),
        build: (context) => [
          _reportSummary(definition, response),
          pw.SizedBox(height: 14),
          for (final section in definition.sections)
            if (_validator.isRuleVisible(
              rule: section.visibilityRule,
              values: response.values,
            ))
              _section(
                definition: definition,
                section: section,
                response: response,
                attachments: attachmentBytes,
              ),
          if (response.values['_legacy'] is Map) ...[
            pw.SizedBox(height: 12),
            _legacyNotice(response.values['_legacy']! as Map),
          ],
        ],
      ),
    );

    return pdf.save();
  }

  static void _requirePinnedRevision(
    FormTemplateDefinition definition,
    FormResponse response,
  ) {
    if (response.tenantId != definition.template.tenantId ||
        response.templateId != definition.template.id ||
        response.templateRevisionId != definition.revision.id) {
      throw ArgumentError(
        'A template report can only render the exact revision pinned to the response.',
      );
    }
  }

  Future<Map<String, Uint8List>> _loadAttachments({
    required FormTemplateDefinition definition,
    required FormResponse response,
    required TemplateReportAttachmentResolver? resolver,
  }) async {
    if (resolver == null) return const {};
    final result = <String, Uint8List>{};
    for (final field in definition.fields) {
      if (field.type != TemplateFieldType.photo &&
          field.type != TemplateFieldType.signature) {
        continue;
      }
      final value = response.values[field.key];
      if (value == null) continue;
      try {
        final bytes = await resolver(field, value);
        if (bytes != null && bytes.isNotEmpty) result[field.key] = bytes;
      } catch (_) {
        // A missing attachment must not prevent the rest of a compliance report
        // from being generated. The textual attachment reference is retained.
      }
    }
    return result;
  }

  pw.Widget _header(
    FormTemplateDefinition definition,
    FormResponse response,
    pw.Context context,
  ) =>
      pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 8),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(width: 0.7)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  definition.template.name,
                  style: pw.TextStyle(
                    fontSize: 17,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '${definition.revision.title} • Revision ${definition.revision.revisionNumber}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
            pw.Text(
              response.status.name.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      );

  pw.Widget _footer(pw.Context context) => pw.Container(
        padding: const pw.EdgeInsets.only(top: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(top: pw.BorderSide(width: 0.4)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Voltcore FieldOps', style: const pw.TextStyle(fontSize: 8)),
            pw.Text(
              'Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
      );

  pw.Widget _reportSummary(
    FormTemplateDefinition definition,
    FormResponse response,
  ) {
    final grade = response.values['siteGrade'];
    final deficiencies = response.values['deficienciesDocumented'];
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Response Summary',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
          ),
          pw.SizedBox(height: 5),
          _summaryRow('Response ID', response.id),
          _summaryRow('Subject', response.subjectType),
          _summaryRow('Revision', '${definition.revision.revisionNumber}'),
          if (response.completedAt != null)
            _summaryRow('Completed', _timestamp(response.completedAt!)),
          if (grade != null) _summaryRow('Grade', _plainValue(grade)),
          if (deficiencies != null)
            _summaryRow(
              'Deficiencies documented',
              deficiencies == true ? 'Yes' : 'No',
            ),
        ],
      ),
    );
  }

  pw.Widget _summaryRow(String label, String value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 120,
              child: pw.Text(
                label,
                style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.Expanded(
              child: pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
            ),
          ],
        ),
      );

  pw.Widget _section({
    required FormTemplateDefinition definition,
    required FormTemplateSection section,
    required FormResponse response,
    required Map<String, Uint8List> attachments,
  }) {
    final fields = definition
        .fieldsForSection(section.id)
        .where(
          (field) => _validator.isVisible(field: field, values: response.values),
        )
        .toList(growable: false);
    if (fields.isEmpty) return pw.SizedBox();

    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: PdfColors.grey200,
            child: pw.Text(
              section.title,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
            ),
          ),
          if (section.description.trim().isNotEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.fromLTRB(8, 5, 8, 2),
              child: pw.Text(
                section.description,
                style: const pw.TextStyle(fontSize: 8),
              ),
            ),
          for (final field in fields)
            _fieldRow(
              definition: definition,
              field: field,
              value: response.values[field.key] ?? field.defaultValue,
              attachment: attachments[field.key],
            ),
        ],
      ),
    );
  }

  pw.Widget _fieldRow({
    required FormTemplateDefinition definition,
    required FormTemplateField field,
    required Object? value,
    required Uint8List? attachment,
  }) {
    if ((field.type == TemplateFieldType.photo ||
            field.type == TemplateFieldType.signature) &&
        attachment != null) {
      return pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.4),
          ),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              field.label,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 5),
            pw.Image(
              pw.MemoryImage(attachment),
              width: field.type == TemplateFieldType.signature ? 220 : 300,
              height: field.type == TemplateFieldType.signature ? 90 : 210,
              fit: pw.BoxFit.contain,
            ),
          ],
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.4),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 190,
            child: pw.Text(
              field.label,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              _formatValue(definition, field, value),
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(
    FormTemplateDefinition definition,
    FormTemplateField field,
    Object? value,
  ) {
    if (value == null) return '—';
    return switch (field.type) {
      TemplateFieldType.boolean => value == true ? 'Yes' : 'No',
      TemplateFieldType.checklist => _formatChecklist(definition, field, value),
      TemplateFieldType.select => _optionLabel(definition, field, value),
      TemplateFieldType.reading => _reading(field, value),
      TemplateFieldType.photo || TemplateFieldType.signature =>
        'Attachment: ${_plainValue(value)}',
      _ => _plainValue(value),
    };
  }

  String _formatChecklist(
    FormTemplateDefinition definition,
    FormTemplateField field,
    Object value,
  ) {
    if (value is! List) return _plainValue(value);
    final labels = value
        .map((item) => _optionLabel(definition, field, item))
        .toList(growable: false);
    return labels.isEmpty ? '—' : labels.join(', ');
  }

  String _optionLabel(
    FormTemplateDefinition definition,
    FormTemplateField field,
    Object value,
  ) {
    final raw = value.toString();
    for (final option in definition.optionsForField(field.id)) {
      if (option.value == raw) return option.label;
    }
    return raw;
  }

  String _reading(FormTemplateField field, Object value) {
    final unit = field.validation['unit']?.toString().trim() ?? '';
    return unit.isEmpty ? _plainValue(value) : '${_plainValue(value)} $unit';
  }

  static String _plainValue(Object value) {
    if (value is List) return value.map((item) => item.toString()).join(', ');
    if (value is Map) {
      return value.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join(', ');
    }
    return value.toString();
  }

  static String _timestamp(DateTime value) =>
      value.toLocal().toString().split('.').first;

  pw.Widget _legacyNotice(Map metadata) => pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: PdfColors.amber50,
          border: pw.Border.all(color: PdfColors.amber300, width: 0.5),
        ),
        child: pw.Text(
          'Migrated legacy record • source: ${metadata['source'] ?? 'unknown'} • '
          'source ID: ${metadata['sourceId'] ?? 'unknown'}',
          style: const pw.TextStyle(fontSize: 8),
        ),
      );
}
