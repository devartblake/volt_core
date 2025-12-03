import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import '../features/inspections/infra/models/inspection.dart';

class ExportService {
  Future<void> tryCopyToExternal(Inspection ins) async {
    if (!Platform.isAndroid) return;
    final status = await Permission.storage.request();
    if (!status.isGranted) return;

    // This uses the "Downloads" directory as a safe default.
    final ext = Directory('/storage/emulated/0/Download');
    if (!ext.existsSync()) return;

    final src = File(ins.pdfPath);
    if (!src.existsSync()) return;

    final out = File('${ext.path}/inspection-${ins.id}.pdf');
    await out.writeAsBytes(await src.readAsBytes(), flush: true);
  }
}
