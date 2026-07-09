import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Uint8List;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';

import 'package:voltcore/shared/widgets/responsive_scaffold.dart';
import '../../../../core/services/pdf/pdf_prefs_service.dart';
import '../../../../core/services/pdf/pdf_service.dart';
import '../controllers/maintenance_form_controller.dart';
import '../controllers/maintenance_providers.dart';
import '../../infra/models/maintenance_record.dart';
import '../widgets/section_maint_site_info.dart';
import '../widgets/section_maint_walkthrough.dart';
import '../widgets/section_maint_general.dart';
import '../widgets/section_maint_actions.dart';
import '../widgets/section_maint_post_service.dart';
import '../widgets/section_maint_parts.dart';
import '../widgets/section_maint_signatures.dart';

class MaintenanceFormPage extends ConsumerStatefulWidget {
  final String? id;

  const MaintenanceFormPage({
    super.key,
    this.id,
  });

  @override
  ConsumerState<MaintenanceFormPage> createState() =>
      _MaintenanceFormPageState();
}

class _MaintenanceFormPageState extends ConsumerState<MaintenanceFormPage> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isSaving = false;
  bool _isGeneratingPdf = false;
  String? _savedPdfPath;

  /// Small helper to trigger rebuild when sections mutate the model.
  void _update(void Function() fn) {
    setState(fn);
  }

  /// Complete save flow: save record -> generate PDF -> save PDF
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Please fill in all required fields'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
      return;
    }

    _formKey.currentState!.save();

    setState(() => _isSaving = true);

    final controller =
    ref.read(maintenanceFormControllerProvider(widget.id).notifier);
    final repo = ref.read(maintenanceRepoProvider);

    try {
      // Step 1: Save the maintenance record
      await controller.save();

      // Get the saved record (now has a proper ID)
      final formState = ref.read(maintenanceFormControllerProvider(widget.id));
      if (formState == null) {
        throw Exception('Failed to retrieve saved record');
      }

      final savedRecord = formState.record;

      if (!mounted) return;

      // Step 2: Generate and save PDF
      setState(() => _isGeneratingPdf = true);

      _savedPdfPath = await _generateAndSavePdf(savedRecord);

      // Step 3: Refresh the list provider so list updates when navigating back
      ref.invalidate(maintenanceListProvider);

      if (!mounted) return;

      setState(() {
        _isSaving = false;
        _isGeneratingPdf = false;
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Maintenance record saved successfully',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'PDF generated and saved',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () {
              final path = _savedPdfPath;
              if (path != null) {
                OpenFilex.open(path);
              }
            },
          ),
        ),
      );

      // Navigate back after brief delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          context.pop();
        }
      });

    } catch (e) {
      setState(() {
        _isSaving = false;
        _isGeneratingPdf = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Text(
                    'Failed to save record',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                e.toString(),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }
  }

  /// Generate PDF with signatures and save to storage.
  /// Returns the saved file path.
  /// Throws if generation fails.
  Future<String> _generateAndSavePdf(MaintenanceRecord record) async {
    try {
      debugPrint('Generating PDF for maintenance record: ${record.id}');

      // Generate PDF bytes with the maintenance record data
      final Uint8List pdfBytes = await PdfService.instance
          .buildMaintenancePdfBytes(record);

      debugPrint('PDF generated successfully, size: ${pdfBytes.length} bytes');

      // Save PDF to file storage
      final String pdfPath = await PdfService.instance.saveMaintenancePdf(
        jobId: record.id,
        pdfBytes: pdfBytes,
      );

      debugPrint('PDF saved to: $pdfPath');

      // Optionally, you can also trigger email/share if preferences allow
      final prefs = await _getPdfPreferences();
      if (prefs.emailAllowed) {
        debugPrint('Email sharing is enabled');
      }

      return pdfPath;
    } catch (e) {
      debugPrint('Error generating/saving PDF: $e');
      rethrow; // Let the caller handle the error
    }
  }

  /// Load PDF export preferences from storage
  Future<PdfExportPrefs> _getPdfPreferences() async {
    try {
      final emailAllowed = await PdfPrefsService.instance.getEmailAllowed();
      final customDir = await PdfPrefsService.instance.getCustomDirectoryPath();
      final defaultRecipient = await PdfPrefsService.instance.getDefaultRecipient();

      return PdfExportPrefs(
        emailAllowed: emailAllowed,
        customDirectoryPath: customDir,
        defaultRecipient: defaultRecipient,
        appSubfolder: 'AandSElectric/Maintenance',
      );
    } catch (e) {
      debugPrint('Error loading PDF preferences: $e');
      return const PdfExportPrefs(emailAllowed: false);
    }
  }

  List<_FormSection> _buildSections(MaintenanceRecord m) => [
    _FormSection(
      title: 'Site Information',
      icon: Icons.location_on_outlined,
      widget: SectionMaintSiteInfo(
        model: m,
        onChanged: (_) => _update(() {}),
      ),
    ),
    _FormSection(
      title: 'Walkthrough',
      icon: Icons.explore_outlined,
      widget: SectionMaintWalkthrough(
        model: m,
        onChanged: (_) => _update(() {}),
      ),
    ),
    _FormSection(
      title: 'General Maintenance',
      icon: Icons.settings_outlined,
      widget: SectionMaintGeneral(
        model: m,
        onChanged: (_) => _update(() {}),
      ),
    ),
    _FormSection(
      title: 'Actions Performed',
      icon: Icons.build_outlined,
      widget: SectionMaintActions(
        model: m,
        onChanged: (_) => _update(() {}),
      ),
    ),
    _FormSection(
      title: 'Post-Service',
      icon: Icons.task_alt_outlined,
      widget: SectionMaintPostService(
        model: m,
        onChanged: (_) => _update(() {}),
      ),
    ),
    _FormSection(
      title: 'Parts & Materials',
      icon: Icons.inventory_2_outlined,
      widget: SectionMaintParts(
        model: m,
        onChanged: (_) => _update(() {}),
      ),
    ),
    _FormSection(
      title: 'Signatures',
      icon: Icons.draw_outlined,
      widget: SectionMaintSignatures(
        model: m,
        onChanged: (_) => _update(() {}),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Watch form state
    final formState =
    ref.watch(maintenanceFormControllerProvider(widget.id));

    if (formState == null) {
      // Initial loading while controller decides existing/new record
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final m = formState.record;
    final sections = _buildSections(m);

    return ResponsiveScaffold(
      appBar: AppBar(
        title: Text(
          widget.id == null
              ? 'New Maintenance Record'
              : 'Edit Maintenance Record',
        ),
        leading: Navigator.of(context).canPop()
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isSaving ? null : () => context.pop(),
        )
            : null,
        actions: [
          // Section indicator
          Container(
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Step ${_currentStep + 1} of ${sections.length}',
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Save button with loading indicator
          if (_isSaving || _isGeneratingPdf)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Save & Generate PDF',
              onPressed: _save,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 900;

            if (isWide) {
              // Desktop/Tablet: Show section navigation sidebar
              return Row(
                children: [
                  _SectionNavigation(
                    sections: sections,
                    currentStep: _currentStep,
                    onStepTapped: (index) {
                      if (!_isSaving) {
                        setState(() => _currentStep = index);
                      }
                    },
                  ),
                  Expanded(
                    child: _buildFormContent(constraints, sections),
                  ),
                ],
              );
            }

            // Mobile: Show stepped navigation
            return Column(
              children: [
                _StepProgress(
                  sections: sections,
                  currentStep: _currentStep,
                ),
                Expanded(
                  child: _buildFormContent(constraints, sections),
                ),
              ],
            );
          },
        ),
      ),
      fab: _buildFloatingActionButton(sections, colorScheme),
    );
  }

  Widget? _buildFloatingActionButton(
      List<_FormSection> sections,
      ColorScheme colorScheme,
      ) {
    // Show loading indicator while saving
    if (_isSaving || _isGeneratingPdf) {
      return FloatingActionButton.extended(
        onPressed: null,
        icon: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colorScheme.onPrimary,
          ),
        ),
        label: Text(_isGeneratingPdf ? 'Generating PDF...' : 'Saving...'),
      );
    }

    // Next button for non-final steps
    if (_currentStep < sections.length - 1) {
      return FloatingActionButton.extended(
        onPressed: () {
          setState(() => _currentStep++);
        },
        icon: const Icon(Icons.arrow_forward),
        label: const Text('Next'),
      );
    }

    // Save button on final step
    return FloatingActionButton.extended(
      onPressed: _save,
      icon: const Icon(Icons.check),
      label: const Text('Complete & Save'),
    );
  }

  Widget _buildFormContent(
      BoxConstraints constraints,
      List<_FormSection> sections,
      ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sections[_currentStep].widget,
          const SizedBox(height: 16),
          // Navigation buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (_currentStep > 0)
                OutlinedButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () {
                    setState(() => _currentStep--);
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                )
              else
                const SizedBox(),
              if (_currentStep < sections.length - 1)
                FilledButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () {
                    setState(() => _currentStep++);
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next'),
                )
              else
                FilledButton.icon(
                  onPressed: _isSaving ? null : _save,
                  icon: _isSaving || _isGeneratingPdf
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Icon(Icons.check),
                  label: Text(
                      _isGeneratingPdf
                          ? 'Generating PDF...'
                          : _isSaving
                          ? 'Saving...'
                          : 'Complete & Save'
                  ),
                ),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _FormSection {
  final String title;
  final IconData icon;
  final Widget widget;

  _FormSection({
    required this.title,
    required this.icon,
    required this.widget,
  });
}

class _SectionNavigation extends StatelessWidget {
  final List<_FormSection> sections;
  final int currentStep;
  final ValueChanged<int> onStepTapped;

  const _SectionNavigation({
    required this.sections,
    required this.currentStep,
    required this.onStepTapped,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          right: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Form Sections',
              style: theme.textTheme.titleSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...List.generate(sections.length, (index) {
            final section = sections[index];
            final isActive = index == currentStep;
            final isCompleted = index < currentStep;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: isActive
                    ? colorScheme.primaryContainer
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => onStepTapped(index),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: isActive
                                ? colorScheme.primary
                                : isCompleted
                                ? colorScheme.primaryContainer
                                : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: isCompleted
                              ? Icon(
                            Icons.check,
                            color: colorScheme.primary,
                            size: 20,
                          )
                              : Icon(
                            section.icon,
                            color: isActive
                                ? colorScheme.onPrimary
                                : colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                section.title,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(
                                  fontWeight: isActive
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isActive
                                      ? colorScheme.onPrimaryContainer
                                      : null,
                                ),
                              ),
                              if (isCompleted)
                                Text(
                                  'Completed',
                                  style:
                                  theme.textTheme.bodySmall?.copyWith(
                                    color: colorScheme.primary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StepProgress extends StatelessWidget {
  final List<_FormSection> sections;
  final int currentStep;

  const _StepProgress({
    required this.sections,
    required this.currentStep,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                sections[currentStep].icon,
                color: colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                sections[currentStep].title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: (currentStep + 1) / sections.length,
            backgroundColor: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }
}