import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/services/storage/file_storage_service.dart';
import '../../../../shared/presenter/layout/pdf/pdf_template.dart';
import '../../domain/entities/asset_disclaimer.dart';
import '../../domain/entities/vehicle_asset.dart';
import '../../domain/entities/vehicle_asset_check.dart';
import '../../domain/entities/vehicle_entity.dart';

/// Builds the printable asset receipt.
///
/// Laid out to match the paper it replaces — company header, the disclaimer in
/// a box, the vehicle designation, the operator/dispatcher block, then one row
/// per tool with nomenclature, part number, quantity, FMC/NMC, missing and
/// reason. Somebody who has been signing the paper version for years should
/// recognise this at a glance.
///
/// **The disclaimer printed here is the version that was signed**, passed in by
/// the caller — never today's wording. Reprinting a 2026 receipt with 2027
/// clauses would misrepresent what the person agreed to, which is the entire
/// reason the version is stored on the row.
class AssetReceiptPdfService {
  AssetReceiptPdfService._();

  static final AssetReceiptPdfService instance = AssetReceiptPdfService._();

  Future<Uint8List> buildBytes({
    required VehicleAssetCheck check,
    required VehicleEntity? vehicle,
    required AssetDisclaimer disclaimer,
  }) async {
    // Resolved before the document is built: the pdf widgets are synchronous,
    // and a signature that lives on another device has to become "not on this
    // device" text rather than an empty box nobody can explain.
    final operatorSignature =
        await _loadSignature(check.operatorSignaturePath);
    final dispatcherSignature =
        await _loadSignature(check.dispatcherSignaturePath);

    final document = pw.Document();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(28),
        footer: (context) => PdfTemplate.pageFooter(context.pageNumber),
        build: (context) => [
          PdfTemplate.companyHeader(),
          _disclaimerBox(disclaimer),
          pw.SizedBox(height: 12),
          _headerBlock(check, vehicle),
          pw.SizedBox(height: 12),
          _toolTable(check),
          pw.SizedBox(height: 16),
          if (check.notes.trim().isNotEmpty) ...[
            PdfTemplate.sectionHeader('Notes'),
            pw.Paragraph(text: check.notes.trim()),
            pw.SizedBox(height: 8),
          ],
          _signatures(check, operatorSignature, dispatcherSignature),
        ],
      ),
    );

    return document.save();
  }

  /// Build and store the PDF, returning the path it was written to.
  Future<String> generate({
    required VehicleAssetCheck check,
    required VehicleEntity? vehicle,
    required AssetDisclaimer disclaimer,
  }) async {
    final bytes = await buildBytes(
      check: check,
      vehicle: vehicle,
      disclaimer: disclaimer,
    );
    return FileStorageService.instance.saveFleetReceiptPdf(
      checkId: check.id,
      pdfBytes: bytes,
    );
  }

  Future<pw.MemoryImage?> _loadSignature(String? logicalPath) async {
    if (logicalPath == null || logicalPath.isEmpty) return null;
    try {
      final bytes =
          await FileStorageService.instance.readFleetSignatureBytes(logicalPath);
      return bytes == null ? null : pw.MemoryImage(bytes);
    } catch (_) {
      // A missing signature file must not stop the rest of the receipt
      // printing — the record of who signed and when is on the row itself.
      return null;
    }
  }

  pw.Widget _disclaimerBox(AssetDisclaimer disclaimer) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey700),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                disclaimer.title,
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                'Version ${disclaimer.version}',
                style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(disclaimer.intro, style: const pw.TextStyle(fontSize: 7.5)),
          pw.SizedBox(height: 4),
          for (var i = 0; i < disclaimer.clauses.length; i++)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.SizedBox(
                    width: 14,
                    child: pw.Text(
                      '${i + 1}.',
                      style: const pw.TextStyle(fontSize: 7.5),
                    ),
                  ),
                  pw.Expanded(
                    child: pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          pw.TextSpan(
                            text: '${disclaimer.clauses[i].heading}: ',
                            style: pw.TextStyle(
                              fontSize: 7.5,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                          pw.TextSpan(
                            text: disclaimer.clauses[i].body,
                            style: const pw.TextStyle(fontSize: 7.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          pw.SizedBox(height: 2),
          pw.Text(
            disclaimer.closing,
            style: pw.TextStyle(
              fontSize: 7.5,
              fontStyle: pw.FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _headerBlock(VehicleAssetCheck check, VehicleEntity? vehicle) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: 120,
          padding: const pw.EdgeInsets.all(8),
          decoration: const pw.BoxDecoration(color: PdfTemplate.lightGray),
          child: pw.Center(
            child: pw.Text(
              // The big designation in the black band on the paper. Falls back
              // to the id only when the vehicle record has not synced.
              vehicle?.displayTitle ?? 'Vehicle',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(
          child: PdfTemplate.formFieldsTable({
            'Operator / Co-operator': [
              check.operatorName.trim(),
              if (check.coOperatorName.trim().isNotEmpty)
                check.coOperatorName.trim(),
            ].where((s) => s.isNotEmpty).join(', '),
            'Dispatcher': check.dispatcherName.trim(),
            'Date / Time': _stamp(check.checkedAt),
            if (vehicle?.licensePlate.trim().isNotEmpty ?? false)
              'License plate': vehicle!.licensePlate.trim(),
          }),
        ),
      ],
    );
  }

  pw.Widget _toolTable(VehicleAssetCheck check) {
    final lines = [...check.lines]
      ..sort((a, b) => a.sortIndex.compareTo(b.sortIndex));

    return PdfTemplate.dataTable(
      headers: const [
        'ASSET Nomenclature',
        'Part Number',
        'QTY',
        'Serviceable',
        'Missing',
        'Reason',
      ],
      columnWidths: const [3.2, 1.3, 0.5, 1.0, 0.8, 2.6],
      rows: [
        for (final line in lines)
          [
            line.assetName,
            line.partNumber.isEmpty ? 'N/A' : line.partNumber,
            '${line.quantity}',
            // The circled FMC / NMC on the paper. Printing both with the
            // chosen one marked keeps the column readable at a glance, the way
            // the pen does.
            line.readiness == AssetReadiness.fmc ? '[FMC] / NMC' : 'FMC / [NMC]',
            line.isMissing ? '[Yes] / No' : 'Yes / [No]',
            line.reason,
          ],
      ],
    );
  }

  pw.Widget _signatures(
    VehicleAssetCheck check,
    pw.MemoryImage? operatorSignature,
    pw.MemoryImage? dispatcherSignature,
  ) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        _signature(
          label: 'Driver initial / signature',
          name: check.operatorName,
          signedAt: check.operatorSignedAt,
          image: operatorSignature,
          hasStoredSignature: check.operatorSignaturePath != null,
        ),
        _signature(
          label: 'Dispatcher verification',
          name: check.dispatcherName,
          signedAt: check.dispatcherSignedAt,
          image: dispatcherSignature,
          hasStoredSignature: check.dispatcherSignaturePath != null,
        ),
      ],
    );
  }

  pw.Widget _signature({
    required String label,
    required String name,
    required DateTime? signedAt,
    required pw.MemoryImage? image,
    required bool hasStoredSignature,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '$label:',
          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Container(
          width: 220,
          height: 66,
          padding: const pw.EdgeInsets.all(4),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey600),
          ),
          child: image != null
              ? pw.Image(image, fit: pw.BoxFit.contain)
              : pw.Center(
                  child: pw.Text(
                    // Says which of the two it is. A blank box could mean
                    // "unsigned" or "signed elsewhere", and those call for very
                    // different reactions from whoever is holding the printout.
                    hasStoredSignature
                        ? 'Signed — image not on this device'
                        : 'Not signed',
                    style: const pw.TextStyle(
                      fontSize: 7.5,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          name.trim().isEmpty ? '_' * 34 : name.trim(),
          style: const pw.TextStyle(fontSize: 9),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Date: ${signedAt == null ? '_' * 18 : _stamp(signedAt)}',
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    );
  }

  static String _stamp(DateTime value) {
    final local = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.month)}/${two(local.day)}/${local.year} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
