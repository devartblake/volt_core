import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../shared/widgets/widgets.dart';
import '../../../../core/services/email/email_service.dart';
import '../../../../core/services/storage/pdf_library_service.dart';
import 'pdf_viewer_page.dart';

/// Library of all generated PDF reports (inspection + maintenance) with view,
/// share, email, and delete. The files already live in one managed tree, so
/// this simply enumerates it.
class DocumentLibraryPage extends StatefulWidget {
  const DocumentLibraryPage({super.key});

  @override
  State<DocumentLibraryPage> createState() => _DocumentLibraryPageState();
}

class _DocumentLibraryPageState extends State<DocumentLibraryPage> {
  final _dateFormat = DateFormat.yMMMd().add_jm();
  late Future<List<PdfDocumentInfo>> _future;

  String _search = '';
  PdfCategory? _filter; // null = all

  @override
  void initState() {
    super.initState();
    _future = PdfLibraryService.instance.listDocuments();
  }

  void _reload() {
    setState(() {
      _future = PdfLibraryService.instance.listDocuments();
    });
  }

  List<PdfDocumentInfo> _apply(List<PdfDocumentInfo> docs) {
    final q = _search.trim().toLowerCase();
    return docs.where((d) {
      if (_filter != null && d.category != _filter) return false;
      if (q.isNotEmpty && !d.name.toLowerCase().contains(q)) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Documents',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: _reload,
        ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search reports…',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          _CategoryFilterBar(
            selected: _filter,
            onChanged: (c) => setState(() => _filter = c),
          ),
          Expanded(
            child: FutureBuilder<List<PdfDocumentInfo>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingIndicator();
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Could not load documents: ${snapshot.error}'),
                  );
                }

                final all = snapshot.data ?? const [];
                final docs = _apply(all);

                if (docs.isEmpty) {
                  final filtered = all.isNotEmpty;
                  return EmptyState(
                    icon: Icons.folder_open,
                    title: filtered
                        ? 'No matching reports'
                        : 'No reports yet',
                    message: filtered
                        ? 'Try a different search or filter.'
                        : 'Generated inspection and maintenance PDFs '
                            'appear here.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) =>
                      _DocumentTile(
                    doc: docs[index],
                    dateFormat: _dateFormat,
                    onOpen: () => _open(docs[index]),
                    onShare: () => _share(docs[index]),
                    onEmail: () => _email(docs[index]),
                    onDelete: () => _confirmDelete(docs[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _open(PdfDocumentInfo doc) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(filePath: doc.path, title: doc.name),
      ),
    );
  }

  Future<void> _share(PdfDocumentInfo doc) async {
    if (!await File(doc.path).exists()) {
      _snack('File no longer exists');
      _reload();
      return;
    }
    await Share.shareXFiles(
      [XFile(doc.path, mimeType: 'application/pdf')],
      subject: doc.name,
    );
  }

  Future<void> _email(PdfDocumentInfo doc) async {
    final recipient = await _promptRecipient();
    if (recipient == null || recipient.isEmpty) return;

    _snack('Sending ${doc.name}…');
    try {
      await EmailService().sendReportEmail(
        recipient: recipient,
        subject: 'Report: ${doc.name}',
        body: 'Please find the attached report: ${doc.name}.',
        pdfPath: doc.path,
        fileName: doc.name,
      );
      _snack('Email sent to $recipient');
    } on EmailException catch (e) {
      _snack(e.message);
    } catch (e) {
      _snack('Could not send email: $e');
    }
  }

  Future<String?> _promptRecipient() async {
    final controller = TextEditingController(text: EmailService.kTo);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Email report'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Recipient email',
          ),
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
  }

  Future<void> _confirmDelete(PdfDocumentInfo doc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete report'),
        content: Text(
          'Delete "${doc.name}" from this device? '
          'Any cloud backup already uploaded is kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await PdfLibraryService.instance.deleteDocument(doc.path);
      _snack('Deleted ${doc.name}');
      _reload();
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _CategoryFilterBar extends StatelessWidget {
  const _CategoryFilterBar({required this.selected, required this.onChanged});

  final PdfCategory? selected;
  final ValueChanged<PdfCategory?> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, PdfCategory? value) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected == value,
          onSelected: (_) => onChanged(value),
        ),
      );
    }

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          chip('All', null),
          chip('Inspection', PdfCategory.inspection),
          chip('Maintenance', PdfCategory.maintenance),
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  const _DocumentTile({
    required this.doc,
    required this.dateFormat,
    required this.onOpen,
    required this.onShare,
    required this.onEmail,
    required this.onDelete,
  });

  final PdfDocumentInfo doc;
  final DateFormat dateFormat;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onEmail;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ListTile(
        onTap: onOpen,
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(
            Icons.picture_as_pdf,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(doc.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          '${doc.category.label} • ${doc.sizeLabel} • '
          '${dateFormat.format(doc.modified)}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'open':
                onOpen();
                break;
              case 'share':
                onShare();
                break;
              case 'email':
                onEmail();
                break;
              case 'delete':
                onDelete();
                break;
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'open', child: Text('Open')),
            PopupMenuItem(value: 'share', child: Text('Share')),
            PopupMenuItem(value: 'email', child: Text('Email')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}

