import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/storage/pdf_library_service.dart';
import 'document_actions.dart' as impl;

/// What a saved-PDF row can do. A seam over [document_actions.dart] (which
/// reaches printing / share_plus / the PDF viewer) so widget tests can
/// substitute a fake and assert on the file passed.
abstract class DocumentActions {
  const DocumentActions();

  /// Opens in the in-app viewer. False when the file is gone.
  bool open(BuildContext context, PdfDocumentInfo doc);

  /// Opens the system print dialog. False when the file is gone.
  Future<bool> print(BuildContext context, PdfDocumentInfo doc);

  /// Shares through the system share sheet. False when the file is gone.
  Future<bool> share(BuildContext context, PdfDocumentInfo doc);

  /// Shares several in one sheet; returns how many were shared.
  Future<int> shareMany(BuildContext context, List<PdfDocumentInfo> docs);
}

/// The real behaviour: straight calls to the helpers in document_actions.dart.
class DefaultDocumentActions extends DocumentActions {
  const DefaultDocumentActions();

  @override
  bool open(BuildContext context, PdfDocumentInfo doc) =>
      impl.openPdfDocument(context, doc);

  @override
  Future<bool> print(BuildContext context, PdfDocumentInfo doc) =>
      impl.printPdfDocument(context, doc);

  @override
  Future<bool> share(BuildContext context, PdfDocumentInfo doc) =>
      impl.sharePdfDocument(context, doc);

  @override
  Future<int> shareMany(BuildContext context, List<PdfDocumentInfo> docs) =>
      impl.shareManyPdfDocuments(context, docs);
}

final documentActionsProvider =
    Provider<DocumentActions>((ref) => const DefaultDocumentActions());

/// For plain (non-Riverpod) widgets such as the Documents hub: the provider's
/// value when there is a [ProviderScope] above, the real actions otherwise.
DocumentActions documentActionsOf(BuildContext context) {
  try {
    return ProviderScope.containerOf(context, listen: false)
        .read(documentActionsProvider);
  } catch (_) {
    // No ProviderScope above (a bare widget test).
    return const DefaultDocumentActions();
  }
}
