import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/forms/form_draft_service.dart';
import '../../../../app/nav_extensions.dart';
import '../../../../shared/widgets/widgets.dart';
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
import '../../../../core/services/photos/photo_attachment.dart';
import '../../../../shared/presenter/widgets/photo_attachments_section.dart';

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
  final _scrollController = ScrollController();

  /// One key per section so the section list can scroll to it, and so a failed
  /// validation can jump to the first section that needs attention.
  final Map<_FormSection, GlobalKey> _sectionKeys = {
    for (final s in _FormSection.values) s: GlobalKey(),
  };

  /// True once the user has edited anything — drives the unsaved-changes guard.
  bool _dirty = false;

  /// Set after a save so the guard doesn't prompt on the way out.
  bool _saved = false;

  @override
  void initState() {
    super.initState();

    // ✅ FIX: Delay state modification until after the widget tree is built
    // This prevents "modifying provider during build" error
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final controller = ref.read(inspectionFormControllerProvider.notifier);

      if (widget.inspectionId != null) {
        // Edit mode: load from repository via ListInspectionsUsecase
        await controller.loadForEdit(widget.inspectionId!);
        await _offerDraftIfNewer(widget.inspectionId!);
      } else {
        // New inspection: start from a blank draft entity
        controller.reset();
        controller.updateDraft(InspectionEntity.newDraft());
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// If an autosaved draft exists for this inspection and is newer than the
  /// saved record, offer to restore it rather than silently discarding work.
  Future<void> _offerDraftIfNewer(String id) async {
    final draft = FormDraftService.instance.loadDraft(id);
    if (draft == null || !mounted) return;

    // Use the draft's recorded write time, not the entity's updatedAt — the
    // Hive model doesn't persist that field, so a loaded draft always reports
    // "now" and would always look newer than the saved record.
    final draftTime = FormDraftService.instance.draftSavedAt(id);

    final controller = ref.read(inspectionFormControllerProvider.notifier);
    final saved = ref.read(inspectionFormControllerProvider).inspection;
    if (saved != null &&
        draftTime != null &&
        !draftTime.isAfter(saved.updatedAt)) {
      // Draft is stale relative to what was saved; drop it.
      await FormDraftService.instance.clearDraft(id);
      return;
    }

    final restore = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Unsaved changes found'),
        content: Text(
          draftTime == null
              ? 'You have unsaved edits to this inspection. Restore them?'
              : 'You have unsaved edits to this inspection from '
                  '${_relativeTime(draftTime)}. Restore them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (restore == true) {
      controller.updateDraft(draft);
      setState(() => _dirty = true);
    } else {
      await FormDraftService.instance.clearDraft(id);
    }
  }

  /// Record an edit: mark dirty and queue a debounced draft write.
  void _onSectionChanged(InspectionEntity updated) {
    ref.read(inspectionFormControllerProvider.notifier).updateDraft(updated);
    FormDraftService.instance.saveDraftDebounced(updated);
    if (!_dirty) setState(() => _dirty = true);
  }

  /// Scroll a section into view (from the section jump list, or on validation
  /// failure).
  Future<void> _scrollToSection(_FormSection section) async {
    final key = _sectionKeys[section];
    final ctx = key?.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
      alignment: 0.05,
    );
  }

  static String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'a moment ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    return '${diff.inDays} d ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formState = ref.watch(inspectionFormControllerProvider);

    final inspection = formState.inspection;
    final isSaving = formState.isSaving;
    final isLoading = formState.isLoading;

    // While loading an existing inspection, show a progress UI
    if (isLoading || inspection == null) {
      return const AppPage(
        title: 'Inspection',
        body: LoadingIndicator(message: 'Loading inspection…'),
      );
    }

    final isEditing = formState.isEditing;
    final title = isEditing ? 'Edit Inspection' : 'New Inspection';

    // Each section is keyed so the jump list (and validation failures) can
    // scroll straight to it.
    Widget keyed(_FormSection section, Widget child) =>
        KeyedSubtree(key: _sectionKeys[section], child: child);

    final children = [
      keyed(
        _FormSection.siteInfo,
        SectionSiteInfo(model: inspection, onChanged: _onSectionChanged),
      ),
      keyed(
        _FormSection.locationSafety,
        SectionLocationSafety(model: inspection, onChanged: _onSectionChanged),
      ),
      keyed(
        _FormSection.fdnyDep,
        SectionFdnyDep(model: inspection, onChanged: _onSectionChanged),
      ),
      keyed(
        _FormSection.operationalUse,
        SectionOperationalUse(model: inspection, onChanged: _onSectionChanged),
      ),
      keyed(
        _FormSection.postInspection,
        SectionPostInspection(model: inspection, onChanged: _onSectionChanged),
      ),
      keyed(
        _FormSection.materials,
        SectionMaterials(model: inspection, onChanged: _onSectionChanged),
      ),
      keyed(
        _FormSection.signatures,
        SectionSignatures(model: inspection, onChanged: _onSectionChanged),
      ),
      // Load test section still works off inspection.id (Hive records)
      keyed(
        _FormSection.loadTest,
        SectionLoadTest(inspectionId: inspection.id),
      ),
      // Photos are self-managed by owner id (Hive-backed, like load tests)
      keyed(
        _FormSection.photos,
        PhotoAttachmentsSection(
          ownerType: PhotoAttachment.ownerInspection,
          ownerId: inspection.id,
        ),
      ),
      const SizedBox(height: 120),
    ];

    return PopScope(
      // Don't let a back gesture / nav tap silently bin the work.
      canPop: !_dirty || _saved,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await _confirmDiscard();
        if (leave && mounted) {
          FormDraftService.instance.cancelPending(inspection.id);
          // popIfPossible, not pop: the navigation that triggered this may
          // have been a `go` that already replaced the form, in which case
          // there is nothing to pop and the technician is where they asked
          // to be.
          if (context.mounted) context.popIfPossible();
        }
      },
      child: AppPage(
      title: title,
      actions: [
        IconButton(
          icon: const Icon(Icons.list_alt_outlined),
          tooltip: 'Jump to section',
          onPressed: () => _showSectionSheet(inspection),
        ),
      ],
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (ctx, constraints) {
            final wide = constraints.maxWidth > 900;

            return Stack(
              children: [
                SingleChildScrollView(
                  controller: _scrollController,
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
                  ColoredBox(
                    color: Colors.black54,
                    child: const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: LoadingIndicator(
                            message: 'Saving and generating PDF...',
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
      bottomBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_dirty && !isSaving)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.edit_note,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Unsaved changes — kept on this device',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              SizedBox(
                width: double.infinity,
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
                  onPressed:
                      isSaving ? null : () => _handleSave(inspection),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  /// Ask before throwing away unsaved edits. Returns true to leave.
  ///
  /// "Keep editing" is the safe default; discarding also clears the autosaved
  /// draft so it can't resurface later.
  Future<bool> _confirmDiscard() async {
    final inspection = ref.read(inspectionFormControllerProvider).inspection;

    final choice = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text(
          'This inspection has unsaved changes. They are kept as a draft on '
          'this device unless you discard them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Leave, keep draft'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Discard'),
          ),
        ],
      ),
    );

    // null == "Discard": drop the draft and leave.
    if (choice == null) {
      if (inspection != null) {
        await FormDraftService.instance.clearDraft(inspection.id);
      }
      return true;
    }
    return choice;
  }

  /// Bottom sheet listing the form's sections so a long form isn't one blind
  /// scroll. Marks sections that still need required fields.
  Future<void> _showSectionSheet(InspectionEntity inspection) async {
    final incomplete = _incompleteSections(inspection);

    final target = await showModalBottomSheet<_FormSection>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Sections',
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            for (final section in _FormSection.values)
              ListTile(
                leading: Icon(section.icon),
                title: Text(section.label),
                trailing: incomplete.contains(section)
                    ? Icon(
                        Icons.error_outline,
                        size: 18,
                        color: Theme.of(ctx).colorScheme.error,
                      )
                    : null,
                subtitle: incomplete.contains(section)
                    ? const Text('Needs required fields')
                    : null,
                onTap: () => Navigator.pop(ctx, section),
              ),
          ],
        ),
      ),
    );

    if (target != null) await _scrollToSection(target);
  }

  /// Sections with required fields still empty. Kept deliberately small — it
  /// mirrors the validators the form itself enforces.
  Set<_FormSection> _incompleteSections(InspectionEntity i) {
    return {
      if (i.siteCode.trim().isEmpty || i.address.trim().isEmpty)
        _FormSection.siteInfo,
    };
  }

  /// Validate, save, then navigate.
  ///
  /// Takes no BuildContext: using the State's own `context` is what lets the
  /// `mounted` checks after each await actually protect the later uses.
  Future<void> _handleSave(InspectionEntity current) async {
    if (!_formKey.currentState!.validate()) {
      // Say *what* is missing and take the user there, rather than a generic
      // "fill in all required fields" on a nine-section form.
      final incomplete = _incompleteSections(current);
      final where = incomplete.isEmpty
          ? null
          : incomplete.map((s) => s.label).join(', ');

      AppSnackBar.warning(
        context,
        where == null
            ? 'Some required fields still need attention.'
            : 'Required fields missing in: $where',
      );

      if (incomplete.isNotEmpty) {
        await _scrollToSection(incomplete.first);
      }
      return;
    }

    _formKey.currentState!.save();
    final controller = ref.read(inspectionFormControllerProvider.notifier);

    try {
      // Save and get the saved inspection ID
      await controller.save(current);

      if (!mounted) return;

      // The controller catches failures into state.error rather than throwing —
      // check it so a failed save doesn't show success and navigate away.
      final saveError = ref.read(inspectionFormControllerProvider).error;
      if (saveError != null) {
        AppSnackBar.error(context, 'Error saving inspection: $saveError');
        return;
      }

      // Saved for real: drop the autosaved draft and let the guard stand down.
      await FormDraftService.instance.clearDraft(current.id);
      if (!mounted) return;
      setState(() {
        _dirty = false;
        _saved = true;
      });

      AppSnackBar.success(context, 'Inspection saved');

      // FIXED: Navigate to detail page instead of just popping
      // This uses the inspection ID to show the generated PDF
      context.go('/inspections/detail/${current.id}');
    } catch (e) {
      if (!mounted) return;
      AppSnackBar.error(context, 'Error saving inspection: $e');
    }
  }
}
/// The form's sections, in the order they appear.
///
/// Having these as an enum (rather than a bare list of widgets) is what lets
/// the jump list, the scroll-to-section, and the validation summary all refer
/// to the same thing.
enum _FormSection {
  siteInfo('Site information', Icons.location_on_outlined),
  locationSafety('Location & safety', Icons.health_and_safety_outlined),
  fdnyDep('FDNY / DEP', Icons.verified_user_outlined),
  operationalUse('Operational use', Icons.speed_outlined),
  postInspection('Post-inspection', Icons.fact_check_outlined),
  materials('Materials', Icons.inventory_2_outlined),
  signatures('Signatures', Icons.draw_outlined),
  loadTest('Load test', Icons.bolt_outlined),
  photos('Photos', Icons.photo_camera_outlined);

  const _FormSection(this.label, this.icon);

  final String label;
  final IconData icon;
}
