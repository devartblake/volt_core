import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../shared/widgets/widgets.dart';

/// In-app PDF viewer. Renders a generated report from local storage using the
/// `printing` package (companion to the `pdf` package already used to build the
/// reports), with built-in print + share.
class PdfViewerPage extends StatelessWidget {
  const PdfViewerPage({
    super.key,
    this.filePath,
    this.bytes,
    required this.title,
  }) : assert(filePath != null || bytes != null);

  final String? filePath;
  final Uint8List? bytes;
  final String title;

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: '',
      titleWidget: Text(title, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          icon: const Icon(Icons.ios_share),
          tooltip: 'Share',
          onPressed: () => _share(context),
        ),
      ],
      body: PdfPreview(
        build: (format) => bytes ?? File(filePath!).readAsBytes(),
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        pdfFileName: title,
        loadingWidget: const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Future<void> _share(BuildContext context) async {
    final memoryBytes = bytes;
    if (memoryBytes != null) {
      await Printing.sharePdf(bytes: memoryBytes, filename: title);
      return;
    }

    final file = File(filePath!);
    if (!await file.exists()) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('File no longer exists')));
      }
      return;
    }
    await Share.shareXFiles([
      XFile(filePath!, mimeType: 'application/pdf'),
    ], subject: title);
  }
}
