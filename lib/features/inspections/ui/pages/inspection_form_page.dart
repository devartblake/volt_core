import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:voltcore/core/ui/app_drawer.dart';
import '../../data/models/inspection.dart';
import '../../data/repo/inspection_repo.dart';
import '../widgets/section_fdny_dep.dart';
import '../widgets/section_load_test.dart';
import '../widgets/section_location_safety.dart';
import '../widgets/section_materials.dart';
import '../widgets/section_operational_use.dart';
import '../widgets/section_post_inspection.dart';
import '../widgets/section_signatures.dart';
import '../widgets/section_site_info.dart';

class InspectionFormPage extends ConsumerStatefulWidget {
  const InspectionFormPage({super.key});
  @override
  ConsumerState<InspectionFormPage> createState() => _InspectionFormPageState();
}

class _InspectionFormPageState extends ConsumerState<InspectionFormPage> {
  final formKey = GlobalKey<FormState>();
  Inspection draft = Inspection(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    createdAt: DateTime.now(),
  );
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New Inspection'),
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
        key: formKey,
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final wide = constraints.maxWidth > 900;
            final children = [
              SectionSiteInfo(
                model: draft,
                onChanged: (m) => setState(() => draft = m),
              ),
              SectionLocationSafety(
                model: draft,
                onChanged: (m) => setState(() => draft = m),
              ),
              SectionFdnyDep(
                model: draft,
                onChanged: (m) => setState(() => draft = m),
              ),
              SectionOperationalUse(
                model: draft,
                onChanged: (m) => setState(() => draft = m),
              ),
              SectionPostInspection(
                model: draft,
                onChanged: (m) => setState(() => draft = m),
              ),
              SectionMaterials(
                model: draft,
                onChanged: (m) => setState(() => draft = m),
              ),
              SectionSignatures(
                model: draft,
                onChanged: (m) => setState(() => draft = m),
              ),
              SectionLoadTest(inspectionId: draft.id),
              const SizedBox(height: 120),
            ];

            return Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: wide
                      ? Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: children
                        .map((w) => SizedBox(
                      width: (constraints.maxWidth - 48) / 2,
                      child: w,
                    ))
                        .toList(),
                  )
                      : Column(children: children),
                ),
                // Progress indicator overlay
                if (_isSaving)
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
            label: const Text('Save & Generate PDF'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: _isSaving ? null : _handleSave,
          ),
        ),
      ),
    );
  }

  Future<void> _handleSave() async {
    if (!formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    formKey.currentState!.save();

    setState(() => _isSaving = true);

    try {
      await ref.read(inspectionRepoProvider).saveAndExport(draft, context);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}