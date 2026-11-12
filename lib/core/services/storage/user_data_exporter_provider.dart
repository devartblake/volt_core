import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'user_data_export_service.dart';

/// Seam over [UserDataExportService] so the Settings export button can be
/// tested without the platform save dialog.
typedef UserDataExporter = Future<UserDataExportResult> Function();

final userDataExporterProvider = Provider<UserDataExporter>(
  (ref) => UserDataExportService.instance.exportInspectionData,
);
