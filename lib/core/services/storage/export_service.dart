import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../modules/inspections/infra/models/inspection.dart';
import '../permissions/app_permissions.dart';
import 'path_resolver.dart';

class ExportService {
  /// Best-effort copy of a generated report into the device's Downloads
  /// folder.
  ///
  /// Two things limit this, both of them Android's, and both silent:
  ///
  /// 1. `Permission.storage` is *permanently denied* on Android 13+, where
  ///    READ_EXTERNAL_STORAGE no longer exists. The old code requested it and
  ///    returned early when it was refused, so on any modern phone this method
  ///    did nothing at all and said nothing. It now asks through
  ///    [AppPermissions.ensurePhotoLibrary], which accepts whichever of the
  ///    two the device actually implements.
  ///
  /// 2. Scoped storage (Android 11+) blocks writing to a raw
  ///    `/storage/emulated/0/...` path regardless of permission. The
  ///    `existsSync` check below fails closed there, so this stays a no-op
  ///    rather than throwing — sharing the PDF through the FileProvider, which
  ///    the app already does, is the path that works on a modern device.
  ///
  /// Kept because it still works on the older tablets in the field.
  Future<void> tryCopyToExternal(Inspection ins) async {
    if (!Platform.isAndroid) return;
    if (!await AppPermissions.ensurePhotoLibrary()) return;

    // This uses the "Downloads" directory as a safe default.
    final ext = Directory('/storage/emulated/0/Download');
    if (!ext.existsSync()) {
      if (kDebugMode) {
        debugPrint(
          '[Export] Downloads is not directly writable (scoped storage). '
          'Share the PDF instead — that path uses the FileProvider and works '
          'on every supported Android version.',
        );
      }
      return;
    }

    final src = File(await PathResolver.resolve(ins.pdfPath));
    if (!src.existsSync()) return;

    final out = File('${ext.path}/inspection-${ins.id}.pdf');
    await out.writeAsBytes(await src.readAsBytes(), flush: true);
  }
}
