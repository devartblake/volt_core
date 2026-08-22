import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:open_filex/open_filex.dart'; // NEW: open with system viewer
import 'package:voltcore/core/services/hive/hive_boxes.dart';
import 'package:voltcore/core/services/storage/path_resolver.dart';
import 'package:voltcore/core/services/storage/web_file_store.dart';
import 'package:voltcore/core/theme/status_colors.dart';

import '../../../schedule/presenter/pages/schedule_task_page.dart';
import '../../../schedule/presenter/widgets/dialogs/schedule_dialog.dart';
import '../../domain/entities/inspection_entity.dart';
import '../../infra/models/inspection.dart';
import '../../infra/repositories/inspection_repository_impl.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../documents/presenter/pages/pdf_viewer_page.dart';

class InspectionDetailPage extends ConsumerWidget {
  final String id;
  const InspectionDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuild on every write to the box. The PDF is rendered in the background
    // after save and lands as a *second* write to this record, so a page that
    // read Hive once would show "no PDF" until it was navigated away from and
    // back.
    return ValueListenableBuilder<Box<Inspection>>(
      valueListenable: HiveBoxes.inspections.listenable(),
      builder: (context, box, _) => _buildContent(context, ref, box),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Box<Inspection> box,
  ) {
    // Lookup by string-id key first; fall back to scanning values for records
    // stored under legacy auto-int keys (older saves used box.add()).
    Inspection? found = box.get(id);
    if (found == null) {
      for (final candidate in box.values) {
        if (candidate.id == id) {
          found = candidate;
          break;
        }
      }
    }
    final theme = Theme.of(context);

    if (found == null) {
      return AppPage(
        title: 'Inspection Detail',
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: theme.colorScheme.error.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              Text(
                'Inspection not found',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Effectively-final binding so closures below can use it non-nullably.
    final Inspection ins = found;

    // Re-anchor the stored path to the current app-data root (iOS containers
    // change across updates), then check existence.
    final resolvedPdfPath = PathResolver.resolveSync(ins.pdfPath);
    final hasPdf =
        ins.pdfPath.isNotEmpty &&
        (kIsWeb
            ? WebFileStore.instance.existsSync(ins.pdfPath)
            : File(resolvedPdfPath).existsSync());

    return AppPage(
      title: 'Inspection Detail',
      actions: [
        // ⭐ NEW: Schedule button in app bar
        IconButton(
          icon: const Icon(Icons.calendar_today),
          tooltip: 'Schedule',
          onPressed: () async {
            final scheduled = await showScheduleDialog(
              context: context,
              taskType: TaskType.inspection,
              siteCode: ins.siteCode,
              address: ins.address,
              inspectionId: ins.id,
              siteGrade: ins.siteGrade,
            );

            if (scheduled == true && context.mounted) {
              AppSnackBar.success(context, 'Inspection scheduled successfully');
            }
          },
        ),
      ],
      body: Column(
        children: [
          // Header Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.settings_input_antenna,
                            color: theme.colorScheme.onPrimaryContainer,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ins.toEntity().displayTitle,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                ins.siteCode,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (ins.siteGrade.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme
                              .gradeColor(
                                ins.siteGrade,
                                fallback: theme.colorScheme.primary,
                              )
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: theme.gradeColor(
                                ins.siteGrade,
                                fallback: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Grade: ${ins.siteGrade}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: theme.gradeColor(
                                  ins.siteGrade,
                                  fallback: theme.colorScheme.primary,
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // ⭐ NEW: Schedule button in card
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.event_available),
                        label: const Text('Schedule This Inspection'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final scheduled = await showScheduleDialog(
                            context: context,
                            taskType: TaskType.inspection,
                            siteCode: ins.siteCode,
                            address: ins.address,
                            inspectionId: ins.id,
                            siteGrade: ins.siteGrade,
                          );

                          if (scheduled == true && context.mounted) {
                            AppSnackBar.success(context, 'Added to schedule');
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // PDF area (no more PdfPreview)
          Expanded(
            child: hasPdf
                ? Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.picture_as_pdf_outlined,
                            size: 80,
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.4,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'PDF ready',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            kIsWeb
                                ? 'Tap below to preview, print, or download the report.'
                                : 'Tap the button below to open in your system PDF viewer.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => _openPdf(
                              context,
                              pdfPath: ins.pdfPath,
                              resolvedPdfPath: resolvedPdfPath,
                              title: ins.toEntity().displayTitle,
                            ),
                            icon: const Icon(Icons.open_in_new),
                            label: Text(kIsWeb ? 'Preview PDF' : 'Open PDF'),
                          ),
                        ],
                      ),
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 80,
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.3,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'No PDF file available',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Generate a PDF to view it here',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
      bottomBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: _PdfActionButton(
            inspection: ins,
            resolvedPdfPath: resolvedPdfPath,
            hasPdf: hasPdf,
          ),
        ),
      ),
    );
  }
}

Future<void> _openPdf(
  BuildContext context, {
  required String pdfPath,
  required String resolvedPdfPath,
  required String title,
}) async {
  if (kIsWeb) {
    final bytes = WebFileStore.instance.getSync(pdfPath);
    if (bytes == null) {
      if (context.mounted)
        AppSnackBar.error(context, 'PDF data is unavailable.');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PdfViewerPage(bytes: bytes, title: title),
      ),
    );
    return;
  }

  final result = await OpenFilex.open(resolvedPdfPath);
  if (result.type != ResultType.done && context.mounted) {
    AppSnackBar.error(context, 'Could not open PDF: ${result.message}');
  }
}

/// Opens the inspection's PDF, or renders one when it has none.
///
/// The second case is not just a retry for a failed background render: every
/// inspection saved before the export path was wired up has an empty
/// `pdfPath`, and this is how those get a document without re-entering the
/// form.
class _PdfActionButton extends ConsumerStatefulWidget {
  const _PdfActionButton({
    required this.inspection,
    required this.resolvedPdfPath,
    required this.hasPdf,
  });

  final Inspection inspection;
  final String resolvedPdfPath;
  final bool hasPdf;

  @override
  ConsumerState<_PdfActionButton> createState() => _PdfActionButtonState();
}

class _PdfActionButtonState extends ConsumerState<_PdfActionButton> {
  bool _generating = false;

  Future<void> _open() async {
    if (kIsWeb) {
      await _openPdf(
        context,
        pdfPath: widget.inspection.pdfPath,
        resolvedPdfPath: widget.resolvedPdfPath,
        title: widget.inspection.toEntity().displayTitle,
      );
      return;
    }

    final file = File(widget.resolvedPdfPath);
    if (!await file.exists()) {
      if (mounted) {
        AppSnackBar.error(context, 'PDF file not found on device.');
      }
      return;
    }

    final result = await OpenFilex.open(widget.resolvedPdfPath);
    if (result.type != ResultType.done && mounted) {
      AppSnackBar.error(context, 'Could not open PDF: ${result.message}');
    }
  }

  Future<void> _generate() async {
    setState(() => _generating = true);
    final repo = ref.read(inspectionRepositoryProvider);

    final result = await repo.generatePdf(widget.inspection.toEntity());

    if (!mounted) return;
    setState(() => _generating = false);

    if (result == null) {
      AppSnackBar.error(context, 'Could not generate the PDF.');
      return;
    }
    // The Hive write from generatePdf rebuilds the page around us, so there is
    // nothing to refresh here.
    AppSnackBar.success(context, 'PDF ready');
  }

  @override
  Widget build(BuildContext context) {
    if (_generating) {
      return FilledButton.icon(
        icon: const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        label: const Text('Generating PDF...'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        onPressed: null,
      );
    }

    return FilledButton.icon(
      icon: Icon(
        widget.hasPdf ? Icons.print_outlined : Icons.picture_as_pdf_outlined,
      ),
      label: Text(widget.hasPdf ? 'Open / Print PDF' : 'Generate PDF'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      onPressed: widget.hasPdf ? _open : _generate,
    );
  }
}
