import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:printing/printing.dart';

import '../../../../core/services/pdf/pdf_service.dart';
import '../../../../core/services/storage/web_file_store.dart';
import '../../../documents/presenter/pages/pdf_viewer_page.dart';
import '../../infra/models/maintenance_record.dart';
import '../../infra/repositories/maintenance_hive_repository.dart';
import '../../../../shared/widgets/app_snack_bar.dart';

/// Opens a generated maintenance report in the in-app PDF viewer.
///
/// Returns false when the file is gone (e.g. cleared storage) so callers can
/// tell the user instead of showing an empty viewer.
bool openMaintenancePdf(NavigatorState navigator, PdfExportResult result) {
  final path = result.filePath;
  if (path == null) return false;

  final title = path.split(RegExp(r'[\\/]')).last;

  if (kIsWeb) {
    final bytes = WebFileStore.instance.getSync(path);
    if (bytes == null) return false;
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => PdfViewerPage(bytes: bytes, title: title),
      ),
    );
    return true;
  }

  navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => PdfViewerPage(filePath: path, title: title),
    ),
  );
  return true;
}

/// Generates the maintenance report for [record] and reports the real outcome:
/// a saved-file snackbar with an Open action, or the failure with a Retry.
///
/// Used by the list and detail Export buttons so they no longer claim an
/// export "started" when nothing was produced.
Future<void> exportMaintenancePdfWithFeedback(
  BuildContext context,
  MaintenanceRepo repo,
  MaintenanceRecord record,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context, rootNavigator: true);

  AppSnackBar.infoOn(messenger, 'Generating PDF…');

  try {
    final result = await repo.exportMaintenancePdf(record);
    showMaintenancePdfSavedSnack(messenger, navigator, result);
  } catch (e) {
    messenger.hideCurrentSnackBar();
    debugPrint('[maintenance_pdf_actions] export failed: $e');
    AppSnackBar.errorOn(
      messenger,
      'Could not generate the PDF. Please try again.',
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'Retry',
        onPressed: () => exportMaintenancePdfWithFeedback(
          // The original context may be gone; the navigator's is stable.
          navigator.context,
          repo,
          record,
        ),
      ),
    );
  }
}

void showMaintenancePdfSavedSnack(
  ScaffoldMessengerState messenger,
  NavigatorState navigator,
  PdfExportResult result, {
  String message = 'PDF saved',
}) {
  messenger.hideCurrentSnackBar();
  AppSnackBar.successOn(
    messenger,
    message,
    duration: const Duration(seconds: 6),
    action: SnackBarAction(
      label: 'Open',
      onPressed: () {
        if (!openMaintenancePdf(navigator, result)) {
          AppSnackBar.errorOn(
            messenger,
            'The PDF file is no longer available',
          );
        }
      },
    ),
  );
}

/// Prints the maintenance report from the saved PDF, generating one only when
/// there is none yet or the record has changed since it was made.
///
/// Opens the system print dialog (any connected printer, or "Save as PDF").
Future<void> printMaintenancePdfWithFeedback(
  BuildContext context,
  MaintenanceRepo repo,
  MaintenanceRecord record,
) async {
  final messenger = ScaffoldMessenger.of(context);

  void say(String text) {
    messenger.hideCurrentSnackBar();
    AppSnackBar.infoOn(messenger, text);
  }

  try {
    say('Preparing to print…');

    var saved = await repo.findSavedMaintenancePdf(record);
    final reused = saved != null;
    saved ??= await repo.exportMaintenancePdf(record, share: false);

    final path = saved.filePath;
    final bytes = path == null ? null : await _readPdfBytes(path);
    if (path == null || bytes == null) {
      say('The PDF could not be read. Try Export PDF first.');
      return;
    }

    messenger.hideCurrentSnackBar();
    await Printing.layoutPdf(
      // The report is US Letter; without this the dialog starts on A4.
      format: PdfPageFormat.letter,
      name: path.split(RegExp(r'[\\/]')).last,
      onLayout: (_) async => bytes,
    );
    if (!reused) {
      say('A new PDF was generated for this print.');
    }
  } catch (e) {
    debugPrint('[maintenance_pdf_actions] print failed: $e');
    say('Could not print the report. Please try again.');
  }
}

Future<Uint8List?> _readPdfBytes(String path) async {
  if (kIsWeb) return WebFileStore.instance.getSync(path);
  final file = File(path);
  if (!await file.exists()) return null;
  return file.readAsBytes();
}
