import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'backup_service.dart';

class UserDataExportResult {
  const UserDataExportResult({required this.saved, this.destination});

  final bool saved;
  final String? destination;
}

/// User-initiated JSON export of the current inspection history.
///
/// Uses the existing inspection/load-test payload builder in [BackupService],
/// then hands the bytes to the platform save dialog. On web, file_picker uses
/// the browser download flow.
class UserDataExportService {
  UserDataExportService._();

  static final UserDataExportService instance = UserDataExportService._();

  Future<UserDataExportResult> exportInspectionData() async {
    final bytes = Uint8List.fromList(
      await BackupService().exportAllAsJsonBytes(),
    );
    final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final fileName = 'voltcore-inspections-$stamp.json';

    final destination = await FilePicker.platform.saveFile(
      dialogTitle: 'Export Voltcore inspection data',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: bytes,
    );

    return UserDataExportResult(
      saved: destination != null,
      destination: destination,
    );
  }
}
