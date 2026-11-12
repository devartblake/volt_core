import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:pdf/pdf.dart' show PdfPageFormat;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/storage/pdf_library_service.dart';
import '../../../core/services/storage/web_file_store.dart';
import '../../../shared/widgets/app_snack_bar.dart';
import 'pages/pdf_viewer_page.dart';

/// Opens a saved PDF in the in-app viewer. Returns false (after telling the
/// user) when the bytes or file are gone, so the caller can refresh its list.
bool openPdfDocument(BuildContext context, PdfDocumentInfo doc) {
  if (kIsWeb) {
    final bytes = WebFileStore.instance.getSync(doc.path);
    if (bytes == null) {
      AppSnackBar.info(context, 'Report bytes are no longer available');
      return false;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(bytes: bytes, title: doc.name),
      ),
    );
    return true;
  }

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PdfViewerPage(filePath: doc.path, title: doc.name),
    ),
  );
  return true;
}

/// Shares a saved PDF through the system share sheet. Returns false (after
/// telling the user) when the file is gone or the share could not start.
/// Dismissing the share sheet is not an error.
Future<bool> sharePdfDocument(BuildContext context, PdfDocumentInfo doc) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    if (kIsWeb) {
      final bytes = WebFileStore.instance.getSync(doc.path);
      if (bytes == null) {
        AppSnackBar.infoOn(messenger, 'Report bytes are no longer available');
        return false;
      }
      await Printing.sharePdf(bytes: bytes, filename: doc.name);
      return true;
    }

    if (!await File(doc.path).exists()) {
      if (messenger.mounted) {
        AppSnackBar.infoOn(messenger, 'File no longer exists');
      }
      return false;
    }
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(doc.path, mimeType: 'application/pdf')],
        subject: doc.name,
      ),
    );
    return true;
  } catch (e) {
    debugPrint('[document_actions] share failed for ${doc.name}: $e');
    if (messenger.mounted) {
      AppSnackBar.errorOn(
          messenger, 'Could not share ${doc.name}. Please try again.');
    }
    return false;
  }
}

/// Opens the system print dialog for a saved PDF. Returns false (after telling
/// the user) when the file is gone.
Future<bool> printPdfDocument(BuildContext context, PdfDocumentInfo doc) async {
  final messenger = ScaffoldMessenger.of(context);
  Uint8List? bytes;
  try {
    if (kIsWeb) {
      bytes = WebFileStore.instance.getSync(doc.path);
    } else {
      final file = File(doc.path);
      if (await file.exists()) bytes = await file.readAsBytes();
    }
  } catch (e) {
    debugPrint('[document_actions] could not read ${doc.name}: $e');
    if (messenger.mounted) {
      AppSnackBar.errorOn(
          messenger, 'Could not print ${doc.name}. Please try again.');
    }
    return false;
  }
  if (bytes == null) {
    AppSnackBar.infoOn(messenger, 'File no longer exists');
    return false;
  }
  final data = bytes;
  try {
    await Printing.layoutPdf(
      format: PdfPageFormat.letter,
      name: doc.name,
      onLayout: (_) async => data,
    );
  } catch (e) {
    debugPrint('[document_actions] print failed for ${doc.name}: $e');
    if (messenger.mounted) {
      AppSnackBar.errorOn(
          messenger, 'Could not print ${doc.name}. Please try again.');
    }
    return false;
  }
  return true;
}

/// Shares several saved PDFs in one share sheet (native) or one by one (web).
/// Missing files are skipped; returns how many were shared (0 after telling
/// the user when the share itself failed).
Future<int> shareManyPdfDocuments(
  BuildContext context,
  List<PdfDocumentInfo> docs,
) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    if (kIsWeb) {
      var n = 0;
      for (final d in docs) {
        final bytes = WebFileStore.instance.getSync(d.path);
        if (bytes == null) continue;
        await Printing.sharePdf(bytes: bytes, filename: d.name);
        n++;
      }
      if (n < docs.length && messenger.mounted) {
        AppSnackBar.infoOn(messenger, 'Some reports are no longer available');
      }
      return n;
    }
    final present = <PdfDocumentInfo>[];
    for (final d in docs) {
      if (await File(d.path).exists()) present.add(d);
    }
    if (present.length < docs.length && messenger.mounted) {
      AppSnackBar.infoOn(messenger, 'Some files no longer exist');
    }
    if (present.isEmpty) return 0;
    await SharePlus.instance.share(
      ShareParams(
        files: [
          for (final d in present) XFile(d.path, mimeType: 'application/pdf'),
        ],
        subject: present.length == 1 ? present.first.name : 'Reports',
      ),
    );
    return present.length;
  } catch (e) {
    debugPrint('[document_actions] shareMany failed: $e');
    if (messenger.mounted) {
      AppSnackBar.errorOn(
          messenger, 'Could not share the reports. Please try again.');
    }
    return 0;
  }
}
