import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:voltcore/shared/widgets/responsive_scaffold.dart';
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

  /// Small helper to trigger rebuild when sections mutate the model.
  void _update(void Function() fn) {
    setState(fn);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();

    final controller =
    ref.read(maintenanceFormControllerProvider(widget.id).notifier);
    final repo = ref.read(maintenanceRepoProvider);

    try {
      await controller.save();

      // Refresh the list provider so list updates when navigating back
      ref.invalidate(maintenanceListProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Maintenance record saved successfully'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save record: $e'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
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
          onPressed: () => context.pop(),
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
          IconButton(
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Save',
            onPressed: formState.isSaving ? null : _save,
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
                      setState(() => _currentStep = index);
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
      fab: _currentStep < sections.length - 1
          ? FloatingActionButton.extended(
        onPressed: () {
          setState(() => _currentStep++);
        },
        icon: const Icon(Icons.arrow_forward),
        label: const Text('Next'),
      )
          : FloatingActionButton.extended(
        onPressed: formState.isSaving ? null : _save,
        icon: const Icon(Icons.save),
        label: const Text('Save'),
      ),
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
                  onPressed: () {
                    setState(() => _currentStep--);
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                )
              else
                const SizedBox(),
              if (_currentStep < sections.length - 1)
                FilledButton.icon(
                  onPressed: () {
                    setState(() => _currentStep++);
                  },
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Next'),
                )
              else
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
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
