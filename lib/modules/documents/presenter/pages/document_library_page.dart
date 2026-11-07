import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/email/email_service.dart';
import '../../../../core/services/storage/pdf_library_service.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../domain/document_hub.dart';
import '../document_actions_provider.dart';

/// The one hub for every saved PDF: filter by type, group by date, search,
/// sort, open / print / share / email / delete (with undo), multi-select and
/// "clear old files".
class DocumentLibraryPage extends StatefulWidget {
  const DocumentLibraryPage({
    super.key,
    this.loadDocuments,
    this.deleteDocument,
    this.now,
    this.undoWindow = const Duration(seconds: 5),
  });

  /// Test seams. Default to [PdfLibraryService].
  final Future<List<PdfDocumentInfo>> Function()? loadDocuments;
  final Future<void> Function(String path)? deleteDocument;
  final DateTime Function()? now;

  /// How long the Undo snackbar (and the pending soft delete) lasts.
  final Duration undoWindow;

  @override
  State<DocumentLibraryPage> createState() => _DocumentLibraryPageState();
}

class _DocumentLibraryPageState extends State<DocumentLibraryPage> {
  final _dateFormat = DateFormat.yMMMd().add_jm();
  late Future<List<PdfDocumentInfo>> _future;

  String _search = '';
  DocumentTypeFilter _filter = DocumentTypeFilter.all;
  DocumentSort _sort = DocumentSort.newest;

  final Set<String> _selected = {};
  // Soft-deleted: hidden now, removed from disk when the undo window ends.
  final Map<String, Timer> _pending = {};
  final Map<String, PdfDocumentInfo> _pendingDocs = {};

  bool get _selecting => _selected.isNotEmpty;
  DateTime get _now => (widget.now ?? DateTime.now)();

  Future<List<PdfDocumentInfo>> _load() =>
      (widget.loadDocuments ?? PdfLibraryService.instance.listDocuments)();

  Future<void> _delete(String path) =>
      (widget.deleteDocument ?? PdfLibraryService.instance.deleteDocument)(
          path);

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    // Commit anything still inside its undo window.
    for (final entry in _pending.entries.toList()) {
      entry.value.cancel();
      unawaited(_delete(entry.key));
    }
    _pending.clear();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _selected.clear();
      _future = _load();
    });
  }

  List<PdfDocumentInfo> _visible(List<PdfDocumentInfo> all) =>
      all.where((d) => !_pending.containsKey(d.path)).toList();

  // ---------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: _selecting ? '${_selected.length} selected' : 'Documents',
      leading: _selecting
          ? IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Cancel selection',
              onPressed: () => setState(_selected.clear),
            )
          : null,
      actions: _selecting
          ? [
              IconButton(
                icon: const Icon(Icons.share),
                tooltip: 'Share selected',
                onPressed: _shareSelected,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Delete selected',
                onPressed: _deleteSelected,
              ),
            ]
          : [
              IconButton(
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
                onPressed: _reload,
              ),
            ],
      body: FutureBuilder<List<PdfDocumentInfo>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator();
          }
          if (snapshot.hasError) {
            return EmptyState.error(
              message: 'Could not load documents: ${snapshot.error}',
              action: OutlinedButton(
                onPressed: _reload,
                child: const Text('Retry'),
              ),
            );
          }

          final all = _visible(snapshot.data ?? const []);
          final searched = searchDocuments(all, _search);
          final counts = countByType(searched);
          final shown = sortDocuments(filterByType(searched, _filter), _sort);

          return Column(
            children: [
              _Controls(
                search: _search,
                onSearch: (v) => setState(() => _search = v),
                filter: _filter,
                counts: counts,
                onFilter: (f) => setState(() => _filter = f),
                sort: _sort,
                onSort: (s) => setState(() => _sort = s),
                summary: summaryLabel(all),
                canClear: documentsOlderThan(all, _now).isNotEmpty,
                onClear: () => _clearOld(all),
              ),
              Expanded(child: _buildList(all, shown)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildList(List<PdfDocumentInfo> all, List<PdfDocumentInfo> shown) {
    if (shown.isEmpty) {
      return _emptyFor(all);
    }

    // Date headers only make sense when the list is in date order.
    final items = <Object>[];
    if (_sort == DocumentSort.newest) {
      for (final g in groupByDate(shown, _now)) {
        items.add(g.label);
        items.addAll(g.documents);
      }
    } else {
      items.addAll(shown);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.xxl),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final item = items[i];
        if (item is String) {
          return Padding(
            padding: const EdgeInsets.only(
                top: AppSpacing.lg, bottom: AppSpacing.sm),
            child: Semantics(
              header: true,
              child: Text(
                item,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          );
        }
        final doc = item as PdfDocumentInfo;
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _DocumentTile(
            doc: doc,
            dateFormat: _dateFormat,
            selecting: _selecting,
            selected: _selected.contains(doc.path),
            onTap: () => _selecting ? _toggle(doc) : _open(doc),
            onLongPress: () => _toggle(doc),
            onAction: (a) => _onAction(a, doc),
          ),
        );
      },
    );
  }

  Widget _emptyFor(List<PdfDocumentInfo> all) {
    if (all.isEmpty) {
      return const EmptyState(
        icon: Icons.folder_open,
        title: 'No documents yet',
        message: 'Saved inspection, maintenance and vehicle PDFs '
            'appear here.',
      );
    }
    if (_search.trim().isNotEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: 'No matching documents',
        message: 'Nothing matches "${_search.trim()}"'
            '${_filter == DocumentTypeFilter.all ? '' : ' in ${_filter.label}'}.',
        action: TextButton(
          onPressed: () => setState(() {
            _search = '';
            _filter = DocumentTypeFilter.all;
          }),
          child: const Text('Clear search'),
        ),
      );
    }
    return EmptyState(
      icon: Icons.folder_open,
      title: 'No ${_filter.label.toLowerCase()} documents',
      message: 'PDFs of this type will appear here once saved.',
      action: TextButton(
        onPressed: () => setState(() => _filter = DocumentTypeFilter.all),
        child: const Text('Show all'),
      ),
    );
  }

  // -------------------------------------------------------------- actions

  void _toggle(PdfDocumentInfo doc) {
    setState(() {
      if (!_selected.remove(doc.path)) _selected.add(doc.path);
    });
  }

  void _onAction(_DocAction action, PdfDocumentInfo doc) {
    switch (action) {
      case _DocAction.open:
        _open(doc);
      case _DocAction.print:
        _print(doc);
      case _DocAction.share:
        _share(doc);
      case _DocAction.email:
        _email(doc);
      case _DocAction.delete:
        _confirmDelete(doc);
    }
  }

  void _open(PdfDocumentInfo doc) {
    if (!documentActionsOf(context).open(context, doc)) _reload();
  }

  Future<void> _print(PdfDocumentInfo doc) async {
    if (!await documentActionsOf(context).print(context, doc) && mounted) _reload();
  }

  Future<void> _share(PdfDocumentInfo doc) async {
    if (!await documentActionsOf(context).share(context, doc) && mounted) _reload();
  }

  Future<List<PdfDocumentInfo>> _selectedDocs() async {
    final all = await _future;
    return all.where((d) => _selected.contains(d.path)).toList();
  }

  Future<void> _shareSelected() async {
    final docs = await _selectedDocs();
    if (!mounted || docs.isEmpty) return;
    await documentActionsOf(context).shareMany(context, docs);
  }

  Future<void> _deleteSelected() async {
    final docs = await _selectedDocs();
    if (!mounted || docs.isEmpty) return;
    final ok = await _confirm(
      title: 'Delete ${docs.length} ${docs.length == 1 ? 'report' : 'reports'}',
      message: 'Delete the selected documents from this device? '
          'Any cloud backup already uploaded is kept.',
      confirmLabel: 'Delete',
    );
    if (ok != true || !mounted) return;
    setState(_selected.clear);
    _softDelete(docs);
  }

  Future<void> _confirmDelete(PdfDocumentInfo doc) async {
    final ok = await _confirm(
      title: 'Delete report',
      message: 'Delete "${doc.name}" from this device? '
          'Any cloud backup already uploaded is kept.',
      confirmLabel: 'Delete',
    );
    if (ok == true && mounted) _softDelete([doc]);
  }

  /// Hides [docs] now; deletes the files once the undo window passes.
  void _softDelete(List<PdfDocumentInfo> docs) {
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      for (final d in docs) {
        _pendingDocs[d.path] = d;
        _pending[d.path] = Timer(widget.undoWindow, () => _commit(d.path));
      }
    });
    final label = docs.length == 1 ? docs.first.name : '${docs.length} reports';
    messenger.hideCurrentSnackBar();
    AppSnackBar.infoOn(
      messenger,
      'Deleted $label',
      duration: widget.undoWindow,
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          if (!mounted) return;
          setState(() {
            for (final d in docs) {
              _pending.remove(d.path)?.cancel();
              _pendingDocs.remove(d.path);
            }
          });
        },
      ),
    );
  }

  Future<void> _commit(String path) async {
    if (_pending.remove(path) == null) return;
    _pendingDocs.remove(path);
    final messenger = mounted ? ScaffoldMessenger.of(context) : null;
    try {
      await _delete(path);
    } catch (e) {
      if (messenger != null) {
        AppSnackBar.errorOn(messenger, 'Could not delete file: $e');
      }
    }
    if (mounted) _reload();
  }

  Future<void> _clearOld(List<PdfDocumentInfo> all) async {
    final old = documentsOlderThan(all, _now);
    if (old.isEmpty) {
      AppSnackBar.info(context, 'No documents older than 90 days');
      return;
    }
    final ok = await _confirm(
      title: 'Clear old files',
      message: 'Delete ${old.length} '
          '${old.length == 1 ? 'document' : 'documents'} older than 90 days '
          '(${formatSize(totalBytes(old))})? This cannot be undone. '
          'Any cloud backup already uploaded is kept.',
      confirmLabel: 'Delete ${old.length}',
    );
    if (ok != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    var failed = 0;
    for (final d in old) {
      try {
        await _delete(d.path);
      } catch (_) {
        failed++;
      }
    }
    if (failed > 0) {
      AppSnackBar.errorOn(messenger, 'Could not delete $failed files');
    } else {
      AppSnackBar.successOn(
          messenger, 'Deleted ${old.length} old '
          '${old.length == 1 ? 'document' : 'documents'}');
    }
    if (mounted) _reload();
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _email(PdfDocumentInfo doc) async {
    final recipient = await _promptRecipient();
    if (recipient == null || recipient.isEmpty || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    AppSnackBar.infoOn(messenger, 'Sending ${doc.name}…');
    try {
      await EmailService().sendReportEmail(
        recipient: recipient,
        subject: 'Report: ${doc.name}',
        body: 'Please find the report: ${doc.name}.',
        pdfPath: doc.path,
        fileName: doc.name,
      );
      AppSnackBar.successOn(
          messenger,
          kIsWeb
              ? 'Email draft opened for $recipient'
              : 'Email sent to $recipient');
    } on EmailException catch (e) {
      AppSnackBar.errorOn(messenger, e.message);
    } catch (e) {
      AppSnackBar.errorOn(messenger, 'Could not send email: $e');
    }
  }

  Future<String?> _promptRecipient() async {
    final controller = TextEditingController(text: EmailService.kTo);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Email report'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Recipient email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
}

enum _DocAction { open, print, share, email, delete }

class _Controls extends StatelessWidget {
  const _Controls({
    required this.search,
    required this.onSearch,
    required this.filter,
    required this.counts,
    required this.onFilter,
    required this.sort,
    required this.onSort,
    required this.summary,
    required this.canClear,
    required this.onClear,
  });

  final String search;
  final ValueChanged<String> onSearch;
  final DocumentTypeFilter filter;
  final Map<DocumentTypeFilter, int> counts;
  final ValueChanged<DocumentTypeFilter> onFilter;
  final DocumentSort sort;
  final ValueChanged<DocumentSort> onSort;
  final String summary;
  final bool canClear;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.xs),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search by file name',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(borderRadius: AppRadius.fieldAll),
            ),
            onChanged: onSearch,
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: Row(
            children: [
              for (final f in DocumentTypeFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text('${f.label} (${counts[f] ?? 0})'),
                    selected: filter == f,
                    onSelected: (_) => onFilter(f),
                  ),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.xs, AppSpacing.sm, 0),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            runSpacing: AppSpacing.xs,
            children: [
              Text(summary, style: Theme.of(context).textTheme.bodyMedium),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (canClear)
                    TextButton.icon(
                      onPressed: onClear,
                      icon: const Icon(Icons.cleaning_services_outlined),
                      label: const Text('Clear old files'),
                    ),
                  PopupMenuButton<DocumentSort>(
                    tooltip: 'Sort',
                    initialValue: sort,
                    onSelected: onSort,
                    itemBuilder: (_) => [
                      for (final s in DocumentSort.values)
                        PopupMenuItem(value: s, child: Text(s.label)),
                    ],
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.sort, size: 20),
                          const SizedBox(width: AppSpacing.xs),
                          Text(sort.label),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.doc,
    required this.dateFormat,
    required this.selecting,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onAction,
  });

  final PdfDocumentInfo doc;
  final DateFormat dateFormat;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final ValueChanged<_DocAction> onAction;

  StatusTone get _tone => switch (doc.category) {
        PdfCategory.inspection => StatusTone.info,
        PdfCategory.maintenance => StatusTone.warning,
        PdfCategory.vehicle => StatusTone.success,
        PdfCategory.other => StatusTone.neutral,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: selected ? theme.colorScheme.secondaryContainer : null,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.fieldAll,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ListTile(
        onTap: onTap,
        onLongPress: onLongPress,
        leading: selecting
            ? Icon(selected ? Icons.check_circle : Icons.circle_outlined,
                color: theme.colorScheme.primary)
            : CircleAvatar(
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(Icons.picture_as_pdf,
                    color: theme.colorScheme.onPrimaryContainer),
              ),
        title: Text(doc.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusChip(label: doc.category.label, tone: _tone),
              Text('${formatSize(doc.sizeBytes)} • '
                  '${dateFormat.format(doc.modified)}'),
            ],
          ),
        ),
        trailing: selecting
            ? null
            : PopupMenuButton<_DocAction>(
                tooltip: 'Document actions',
                onSelected: onAction,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: _DocAction.open, child: Text('Open')),
                  PopupMenuItem(value: _DocAction.print, child: Text('Print')),
                  PopupMenuItem(value: _DocAction.share, child: Text('Share')),
                  PopupMenuItem(value: _DocAction.email, child: Text('Email')),
                  PopupMenuItem(
                      value: _DocAction.delete, child: Text('Delete')),
                ],
              ),
      ),
    );
  }
}
