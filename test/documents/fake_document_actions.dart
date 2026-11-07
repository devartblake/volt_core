import 'package:flutter/widgets.dart';
import 'package:voltcore/core/services/storage/pdf_library_service.dart';
import 'package:voltcore/modules/documents/presenter/document_actions_provider.dart';

/// Records which file each action was called with; touches no plugins.
class FakeDocumentActions extends DocumentActions {
  final opened = <String>[];
  final printed = <String>[];
  final shared = <String>[];
  final sharedMany = <List<String>>[];

  @override
  bool open(BuildContext context, PdfDocumentInfo doc) {
    opened.add(doc.path);
    return true;
  }

  @override
  Future<bool> print(BuildContext context, PdfDocumentInfo doc) async {
    printed.add(doc.path);
    return true;
  }

  @override
  Future<bool> share(BuildContext context, PdfDocumentInfo doc) async {
    shared.add(doc.path);
    return true;
  }

  @override
  Future<int> shareMany(
      BuildContext context, List<PdfDocumentInfo> docs) async {
    sharedMany.add([for (final d in docs) d.path]);
    return docs.length;
  }
}
