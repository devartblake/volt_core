import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../../data/models/inspection.dart';
import '../../data/sources/hive_boxes.dart';
import '../../data/repo/inspection_repo.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

class InspectionDetailPage extends ConsumerWidget {
  final String id;
  const InspectionDetailPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ins = HiveBoxes.inspections.get(id);
    final theme = Theme.of(context);

    if (ins == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inspection Detail')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 80,
                color: theme.colorScheme.error.withOpacity(0.5),
              ),
              const SizedBox(height: 24),
              Text(
                'Inspection not found',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final hasPdf = ins.pdfPath.isNotEmpty && File(ins.pdfPath).existsSync();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspection Detail'),
        elevation: 0,
      ),
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
                                ins.address.isEmpty
                                    ? '(No address)'
                                    : ins.address,
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
                          color: _getGradeColor(ins.siteGrade)
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: _getGradeColor(ins.siteGrade),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Grade: ${ins.siteGrade}',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: _getGradeColor(ins.siteGrade),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // PDF Preview
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
              clipBehavior: Clip.antiAlias,
              child: PdfPreview(
                build: (_) => File(ins.pdfPath).readAsBytes(),
              ),
            )
                : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 80,
                    color: theme.colorScheme.primary.withOpacity(0.3),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No PDF file available',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Generate a PDF to view it here',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: FilledButton.icon(
            icon: const Icon(Icons.send_outlined),
            label: const Text('Resend PDF'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () async {
              await ref.read(inspectionRepoProvider).saveAndExport(ins, context);
            },
          ),
        ),
      ),
    );
  }

  Color _getGradeColor(String grade) {
    switch (grade.toLowerCase()) {
      case 'green':
        return Colors.green;
      case 'amber':
        return Colors.orange;
      case 'red':
        return Colors.red;
      default:
        return Colors.blue;
    }
  }
}