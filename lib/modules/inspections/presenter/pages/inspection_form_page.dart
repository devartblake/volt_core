import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/app_drawer.dart';
import '../../domain/entities/inspection_entity.dart';
import '../controllers/inspection_form_controller.dart';

// Section widgets (now using InspectionEntity)
import '../widgets/section_site_info.dart';
import '../widgets/section_location_safety.dart';
import '../widgets/section_fdny_dep.dart';
import '../widgets/section_operational_use.dart';
import '../widgets/section_post_inspection.dart';
import '../widgets/section_materials.dart';
import '../widgets/section_signatures.dart';
import '../../../load_test/presenter/widgets/section_load_test.dart';

class InspectionFormPage extends ConsumerStatefulWidget {
  /// Optional: when non-null, page will load an existing inspection for edit.
  final String? inspectionId;

  const InspectionFormPage({
    super.key,
    this.inspectionId,
  });

  @override
  ConsumerState<InspectionFormPage> createState() => _InspectionFormPageState();
}

class _InspectionFormPageState extends ConsumerState<InspectionFormPage> {
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    // Initialize controller state: new draft vs edit existing
    final controller = ref.read(inspectionFormControllerProvider.notifier);

    if (widget.inspectionId != null) {
      // Edit mode: load from repository via ListInspectionsUsecase
      controller.loadForEdit(widget.inspectionId!);
    } else {
      // New inspection: start from a blank draft entity
      controller.reset();
      controller.updateDraft(
        InspectionEntity.newDraft(), // see helper below if you don’t have this
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formState = ref.watch(inspectionFormControllerProvider);
    final controller = ref.read(inspectionFormControllerProvider.notifier);

    final inspection = formState.inspection;
    final isSaving = formState.isSaving;
    final isLoading = formState.isLoading;

    // While loading an existing inspection, show a progress UI
    if (isLoading || inspection == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Inspection'),
          leading: Navigator.of(context).canPop()
              ? IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          )
              : null,
        ),
        drawer: const AppDrawer(),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final isEditing = formState.isEditing;
    final title = isEditing ? 'Edit Inspection' : 'New Inspection';

    // Build all the section widgets with the current inspection as the model
    final children = [
      SectionSiteInfo(
        model: inspection,
        onChanged: controller.updateDraft,
      ),
      SectionLocationSafety(
        model: inspection,
        onChanged: controller.updateDraft,
      ),
      SectionFdnyDep(
        model: inspection,
        onChanged: controller.updateDraft,
      ),
      SectionOperationalUse(
        model: inspection,
        onChanged: controller.updateDraft,
      ),
      SectionPostInspection(
        model: inspection,
        onChanged: controller.updateDraft,
      ),
      SectionMaterials(
        model: inspection,
        onChanged: controller.updateDraft,
      ),
      SectionSignatures(
        model: inspection,
        onChanged: controller.updateDraft,
      ),
      // Load test section still works off inspection.id (Hive records)
      SectionLoadTest(inspectionId: inspection.id),
      const SizedBox(height: 120),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: Navigator.of(context).canPop()
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        )
            : null,
        elevation: 0,
      ),
      drawer: const AppDrawer(),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final wide = constraints.maxWidth > 900;

            return Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: wide
                      ? Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: children
                        .map(
                          (w) => SizedBox(
                        width: (constraints.maxWidth - 48) / 2,
                        child: w,
                      ),
                    )
                        .toList(),
                  )
                      : Column(children: children),
                ),

                // Saving overlay driven by controller state
                if (isSaving)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Saving and generating PDF...'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
            icon: const Icon(Icons.check_circle_outline),
            label: Text(isSaving
                ? 'Saving...'
                : isEditing
                ? 'Save Changes'
                : 'Save & Generate PDF'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: isSaving ? null : () => _handleSave(context, inspection),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave(
      BuildContext context,
      InspectionEntity current,
      ) async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    _formKey.currentState!.save();
    final controller = ref.read(inspectionFormControllerProvider.notifier);

    try {
      await controller.save(current);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Inspection saved & PDF generated'),
        ),
      );

      // Optionally pop back to list
      if (Navigator.of(context).canPop()) {
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving inspection: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
