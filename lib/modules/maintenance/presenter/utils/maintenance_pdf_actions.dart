import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../../../core/services/pdf/pdf_service.dart';
import '../../../../core/services/storage/web_file_store.dart';
import '../../../documents/presenter/pages/pdf_viewer_page.dart';
import '../../infra/models/maintenance_record.dart';
import '../../infra/repositories/maintenance_hive_repository.dart';

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

  messenger.showSnackBar(
    const SnackBar(
      content: Text('Generating PDF…'),
      behavior: SnackBarBehavior.floating,
    ),
  );

  try {
    final result = await repo.exportMaintenancePdf(record);
    showMaintenancePdfSavedSnack(messenger, navigator, result);
  } catch (e) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Could not generate PDF: $e'),
        behavior: SnackBarBehavior.floating,
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
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'Open',
        onPressed: () {
          if (!openMaintenancePdf(navigator, result)) {
            messenger.showSnackBar(
              const SnackBar(
                content: Text('The PDF file is no longer available'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
      ),
    ),
  );
}
