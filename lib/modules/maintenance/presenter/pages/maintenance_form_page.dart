import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/nav_extensions.dart';
import '../../../auth/presenter/sign_off_access.dart';

import '../../../../core/services/pdf/pdf_service.dart' show PdfExportResult;
import '../../../../core/services/photos/photo_attachment.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../shared/presenter/widgets/photo_attachments_section.dart';
import '../../../../shared/presenter/widgets/site_check_in_tile.dart';
import '../../infra/mappers/maintenance_supabase_mapper.dart';
import '../../../materials/domain/material_list.dart';
import '../../../materials/infra/materials_repository.dart';
import '../../../materials/presenter/materials_editor.dart';
import '../../../materials/presenter/materials_section_card.dart';
import '../../domain/maintenance_progress.dart';
import '../../domain/maintenance_validation.dart';
import '../controllers/maintenance_form_controller.dart';
import '../controllers/maintenance_providers.dart';
import '../utils/maintenance_pdf_actions.dart';
import '../../infra/models/maintenance_record.dart';
import '../../infra/repositories/maintenance_hive_repository.dart' show MaintenanceRepo;
import '../widgets/section_maint_site_info.dart';
import '../widgets/section_maint_walkthrough.dart';
import '../widgets/section_maint_general.dart';
import '../widgets/section_maint_actions.dart';
import '../widgets/section_maint_post_service.dart';
import '../widgets/section_maint_parts.dart';
import '../widgets/section_maint_signatures.dart';
import '../../../../shared/widgets/widgets.dart';

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

class _MaintenanceFormPageState extends ConsumerState<MaintenanceFormPage>
    with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isSaving = false;

  /// Steps whose missing required fields show inline messages: ones the user
  /// has visited and left, plus all of them once Complete & Save is tapped.
  final Set<MaintenanceStep> _revealed = {};
  bool _isGeneratingPdf = false;
  PdfExportResult? _savedPdf;

  /// True once a section has edited the record since the last draft write.
  bool _dirty = false;

  /// Set after the final save so leaving does not touch the record again.
  bool _saved = false;

  Timer? _draftTimer;
  DateTime? _draftSavedAt;

  // Held so dispose can still write a draft after navigating away by the
  // menu (which tears the form down without a back press); `ref` is not
  // usable there.
  MaintenanceRecord? _record;
  MaintenanceRepo? _repo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draftTimer?.cancel();
    final record = _record;
    if (_dirty && !_saved && record != null) {
      _repo?.saveDraft(record);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Backgrounded: the OS may kill the app, so write what we have now.
    if (state != AppLifecycleState.resumed) _flushDraft();
  }

  /// Called by every section when it edits the record. Rebuilds the progress
  /// and schedules an autosave a moment after typing stops.
  void _update(void Function() fn) {
    setState(() {
      fn();
      _dirty = true;
    });
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 1500), _flushDraft);
  }

  /// Writes the record to this device (not the cloud) so a half-finished
  /// record survives the app closing.
  Future<void> _flushDraft() async {
    _draftTimer?.cancel();
    if (!_dirty || _saved || !mounted) return;
    try {
      await ref
          .read(maintenanceFormControllerProvider(widget.id).notifier)
          .saveDraft();
      _dirty = false;
      if (mounted) setState(() => _draftSavedAt = DateTime.now());
    } catch (_) {
      // The final save will report a real failure; an autosave hiccup should
      // not interrupt typing.
    }
  }

  /// Leaving by back button: keep the work as a draft, or drop a new record
  /// nobody typed into so "New record" then back leaves nothing behind.
  Future<void> _leaveEditor(MaintenanceProgress progress) async {
    _draftTimer?.cancel();
    if (_saved || !mounted) return;
    try {
      final controller =
          ref.read(maintenanceFormControllerProvider(widget.id).notifier);
      if (progress.isBlank) {
        await controller.discardIfNew();
        ref.invalidate(maintenanceListProvider);
      } else if (_dirty) {
        await controller.saveDraft();
        _dirty = false;
      }
    } catch (_) {
      // Leaving must always work; the record is already on this device.
    }
  }

  /// Complete save flow: save record -> generate PDF -> save PDF
  Future<void> _save({bool markCompleted = false}) async {
    if (!_formKey.currentState!.validate()) {
      AppSnackBar.error(context, 'Please fill in all required fields');
      return;
    }

    _formKey.currentState!.save();

    setState(() => _isSaving = true);

    final controller =
    ref.read(maintenanceFormControllerProvider(widget.id).notifier);

    try {
      // Step 1: Save the maintenance record
      // Finishing with every expected section filled in marks the record
      // completed (keeping any follow-up flag already set); saving with gaps
      // leaves it as a record still in progress.
      final existing =
          ref.read(maintenanceFormControllerProvider(widget.id))?.record;
      await controller.save(
        markCompleted: markCompleted,
        requiresFollowUp: existing?.requiresFollowUp ?? false,
      );

      // Get the saved record (now has a proper ID)
      final formState = ref.read(maintenanceFormControllerProvider(widget.id));
      if (formState == null) {
        throw Exception('Failed to retrieve saved record');
      }

      final savedRecord = formState.record;

      if (!mounted) return;

      // The record is on disk from here on. Mark it saved before the PDF so a
      // PDF failure can never make the technician re-enter or lose the record.
      ref.invalidate(maintenanceListProvider);
      setState(() {
        _isSaving = false;
        _dirty = false;
        _saved = true;
      });

      // Step 2: Generate the PDF into the managed library.
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context, rootNavigator: true);
      final repo = ref.read(maintenanceRepoProvider);

      setState(() => _isGeneratingPdf = true);
      try {
        _savedPdf = await repo.exportMaintenancePdf(savedRecord, share: false);
      } catch (e, st) {
        debugPrint('Error generating maintenance PDF: $e\n$st');
        if (mounted) setState(() => _isGeneratingPdf = false);
        AppSnackBar.errorOn(
          messenger,
          'Record saved, but the PDF could not be generated: $e',
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => exportMaintenancePdfWithFeedback(
              navigator.context,
              repo,
              savedRecord,
            ),
          ),
        );
        // Stay on the form so the technician sees the failure and can retry.
        return;
      }

      if (mounted) setState(() => _isGeneratingPdf = false);

      showMaintenancePdfSavedSnack(
        messenger,
        navigator,
        _savedPdf!,
        message: 'Maintenance record saved and PDF generated',
      );

      // popOrGo, not pop: the record is saved and the technician must not be
      // stranded on the form, so when there is nothing to pop we send them to
      // the list rather than throw.
      if (mounted) context.popOrGo('/maintenance');

    } catch (e) {
      setState(() {
        _isSaving = false;
        _isGeneratingPdf = false;
      });

      if (!mounted) return;

      AppSnackBar.error(
        context,
        'Failed to save record: $e',
        duration: const Duration(seconds: 6),
      );
    }
  }

  List<_FormSection> _buildSections(MaintenanceRecord m) => [
    _FormSection(
      step: MaintenanceStep.siteInfo,
      widget: Column(
        children: [
          // Same tile the inspection form uses, in the same place: it
          // evidences the address in the section below it.
          SiteCheckInTile(
            checkIn: maintenanceCheckIn(m),
            onChanged: (checkIn) => _update(
              () => applyMaintenanceCheckIn(m, checkIn),
            ),
          ),
          const SizedBox(height: 8),
          SectionMaintSiteInfo(
            model: m,
            onChanged: (_) => _update(() {}),
            issues: MaintenanceValidation.issues(m, revealed: _revealed),
          ),
        ],
      ),
    ),
    _FormSection(
      step: MaintenanceStep.walkthrough,
      widget: SectionMaintWalkthrough(
        model: m,
        onChanged: (_) => _update(() {}),
      ),
    ),
    _FormSection(
      step: MaintenanceStep.general,
      widget: SectionMaintGeneral(
        model: m,
        onChanged: (_) => _update(() {}),
      ),
    ),
    _FormSection(
      step: MaintenanceStep.actions,
      widget: SectionMaintActions(
        model: m,
        onChanged: (_) => _update(() {}),
      ),
    ),
    _FormSection(
      step: MaintenanceStep.postService,
      widget: SectionMaintPostService(
        model: m,
        onChanged: (_) => _update(() {}),
      ),
    ),
    _FormSection(
      step: MaintenanceStep.parts,
      widget: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MaterialsSectionCard(
            owner: MaterialOwner.maintenance(
              id: m.id,
              equipmentKey: generatorProfileKey(
                make: m.generatorMake,
                model: m.generatorModel,
                serial: m.generatorSerial,
              ),
            ),
            mode: MaterialsMode.maintenance,
            make: m.generatorMake,
            model: m.generatorModel,
            serial: m.generatorSerial,
            subtitle: 'What was used on this service.',
          ),
          // Records made before the parts list kept free text here; it stays
          // visible so nothing already written is hidden.
          if (_hasLegacyParts(m)) ...[
            const SizedBox(height: 16),
            SectionMaintParts(
              model: m,
              onChanged: (_) => _update(() {}),
            ),
          ],
        ],
      ),
    ),
    _FormSection(
      step: MaintenanceStep.photos,
      widget: PhotoAttachmentsSection(
        ownerType: PhotoAttachment.ownerMaintenance,
        ownerId: m.id,
      ),
    ),
    _FormSection(
      step: MaintenanceStep.signatures,
      widget: SectionMaintSignatures(
        model: m,
        onChanged: (_) => _update(() {}),
        canSignOff: ref.watch(canSignOffProvider),
        issues: MaintenanceValidation.issues(m, revealed: _revealed),
      ),
    ),
  ];

  static bool _hasLegacyParts(MaintenanceRecord m) => [
        m.partsOilTypeQty,
        m.partsCoolantTypeQty,
        m.partsFilterTypes,
        m.partsBatteryTypeDate,
        m.partsBeltsHosesReplaced,
        m.partsBlockHeaterWattage,
        m.partsCdvrSerial,
      ].any((s) => s.trim().isNotEmpty);

  /// Go to [index], saving the draft first and refreshing the photo count
  /// (photos are stored apart from the record).
  void _goTo(int index) {
    if (_isSaving || index == _currentStep) return;
    _flushDraft();
    final id = ref.read(maintenanceFormControllerProvider(widget.id))?.record.id;
    if (id != null) {
      ref.invalidate(maintenancePhotoCountProvider(id));
      ref.invalidate(maintenanceMaterialCountProvider(id));
    }
    setState(() {
      // Leaving a step reveals what it still needs.
      _revealed.add(MaintenanceStep.values[_currentStep]);
      _currentStep = index;
    });
  }

  /// Before the final save, say what is still empty. Saving is never blocked:
  /// a technician on a roof may genuinely have no customer signature yet.
  Future<void> _confirmAndSave(MaintenanceProgress progress) async {
    // Show the inline "Required to finish" messages on every step, whatever
    // the user chooses below. Saving is never blocked.
    setState(() => _revealed.addAll(MaintenanceStep.values));
    final missing = progress.missingExpected;
    // Apprentices save their work but cannot mark the job completed.
    final canComplete = ref.read(canSignOffProvider);
    if (missing.isEmpty) return _save(markCompleted: canComplete);

    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Not everything is filled in'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('These sections are still incomplete:'),
            const SizedBox(height: 8),
            for (final step in missing)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Icon(step.icon, size: 18),
                    const SizedBox(width: 8),
                    Text(step.title),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            const Text(
              'You can save and generate the report now and finish them '
              'later.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save anyway'),
          ),
        ],
      ),
    );
    if (go == true && mounted) await _save();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(maintenanceFormControllerProvider(widget.id));

    if (formState == null) {
      // Initial loading while controller decides existing/new record
      return const AppPage(title: 'Maintenance', body: LoadingIndicator());
    }

    final m = formState.record;
    _record = m;
    _repo ??= ref.read(maintenanceRepoProvider);
    final photoCount =
        ref.watch(maintenancePhotoCountProvider(m.id)).asData?.value ?? 0;
    final materialCount =
        ref.watch(maintenanceMaterialCountProvider(m.id)).asData?.value ?? 0;
    final progress = MaintenanceProgress.compute(
      m,
      photoCount: photoCount,
      materialCount: materialCount,
    );
    final sections = _buildSections(m);
    final busy = _isSaving || _isGeneratingPdf;

    return PopScope(
      // Edits are autosaved as a draft, so leaving never loses work; this
      // only makes sure the last change is written (and a record nobody typed
      // into is not left behind).
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _leaveEditor(progress);
        if (!context.mounted) return;
        context.popIfPossible();
      },
      child: AppPage(
        title: widget.id == null
            ? 'New Maintenance Record'
            : 'Edit Maintenance Record',
        showSearch: false,
        actions: [
          if (busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(child: LoadingIndicator.inline()),
            )
          else
            IconButton(
              icon: const Icon(Icons.save_outlined),
              tooltip: 'Save & Generate PDF',
              onPressed: () => _confirmAndSave(progress),
            ),
        ],
        body: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final content = Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _StepHeader(
                    section: sections[_currentStep],
                    index: _currentStep,
                    count: sections.length,
                    status: progress.of(sections[_currentStep].step),
                    progress: progress,
                    draftSavedAt: _draftSavedAt,
                  ),
                  if (!isWide)
                    _StepStrip(
                      sections: sections,
                      progress: progress,
                      currentStep: _currentStep,
                      onTap: _goTo,
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: sections[_currentStep].widget,
                    ),
                  ),
                ],
              );

              if (!isWide) return content;
              return Row(
                children: [
                  _SectionNavigation(
                    sections: sections,
                    progress: progress,
                    currentStep: _currentStep,
                    onStepTapped: _goTo,
                  ),
                  Expanded(child: content),
                ],
              );
            },
          ),
        ),
        // One sticky bar for moving between steps and finishing, in place of
        // a floating button plus a second set of buttons under the form.
        bottomBar: _ActionBar(
          index: _currentStep,
          count: sections.length,
          busy: busy,
          savingLabel: _isGeneratingPdf ? 'Generating PDF...' : 'Saving...',
          onPrevious: () => _goTo(_currentStep - 1),
          onNext: () => _goTo(_currentStep + 1),
          canComplete: ref.watch(canSignOffProvider),
          onFinish: () => _confirmAndSave(progress),
        ),
      ),
    );
  }
}

class _FormSection {
  final MaintenanceStep step;
  final Widget widget;

  _FormSection({required this.step, required this.widget});

  String get title => step.title;
  IconData get icon => step.icon;
}

String _time(DateTime d) {
  final h = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
  return '$h:${d.minute.toString().padLeft(2, '0')} ${d.hour >= 12 ? 'PM' : 'AM'}';
}

StatusTone _toneOf(StepStatus s) => switch (s) {
      StepStatus.done => StatusTone.success,
      StepStatus.started => StatusTone.warning,
      StepStatus.empty => StatusTone.neutral,
    };

IconData _iconOf(StepStatus s) => switch (s) {
      StepStatus.done => Icons.check_circle,
      StepStatus.started => Icons.timelapse,
      StepStatus.empty => Icons.radio_button_unchecked,
    };

/// Current step's title and status, the overall progress, and whether the
/// draft has been saved.
class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.section,
    required this.index,
    required this.count,
    required this.status,
    required this.progress,
    required this.draftSavedAt,
  });

  final _FormSection section;
  final int index;
  final int count;
  final StepStatus status;
  final MaintenanceProgress progress;
  final DateTime? draftSavedAt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Icon(section.icon, color: scheme.primary, size: 22),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    section.title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              StatusChip(
                label: status.label,
                tone: _toneOf(status),
                icon: _iconOf(status),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Semantics(
            label: 'Step ${index + 1} of $count, '
                '${progress.doneCount} of ${progress.total} sections done',
            child: LinearProgressIndicator(
              value: progress.fraction,
              minHeight: 6,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            children: [
              Text(
                'Step ${index + 1} of $count  ·  '
                '${progress.doneCount} of ${progress.total} done',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
              if (draftSavedAt != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_done_outlined,
                        size: 14, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      'Draft saved ${_time(draftSavedAt!)}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Phone: scrollable row of steps with their status, tap to jump.
class _StepStrip extends StatelessWidget {
  const _StepStrip({
    required this.sections,
    required this.progress,
    required this.currentStep,
    required this.onTap,
  });

  final List<_FormSection> sections;
  final MaintenanceProgress progress;
  final int currentStep;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final status = progress.of(sections[i].step);
          final selected = i == currentStep;
          final fg =
              selected ? scheme.onSecondaryContainer : scheme.onSurface;
          return ChoiceChip(
            avatar: Icon(
              _iconOf(status),
              size: 18,
              color: switch (status) {
                StepStatus.done => Theme.of(context).status.success,
                StepStatus.started => Theme.of(context).status.warning,
                StepStatus.empty => fg,
              },
            ),
            label: Text(sections[i].title, style: TextStyle(color: fg)),
            selectedColor: scheme.secondaryContainer,
            showCheckmark: false,
            selected: selected,
            onSelected: (_) => onTap(i),
          );
        },
      ),
    );
  }
}

/// Wide layouts: the steps down the left with a status for each.
class _SectionNavigation extends StatelessWidget {
  const _SectionNavigation({
    required this.sections,
    required this.progress,
    required this.currentStep,
    required this.onStepTapped,
  });

  final List<_FormSection> sections;
  final MaintenanceProgress progress;
  final int currentStep;
  final ValueChanged<int> onStepTapped;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(right: BorderSide(color: scheme.outlineVariant)),
      ),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'Sections',
              style: theme.textTheme.titleSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (var i = 0; i < sections.length; i++)
            _NavTile(
              section: sections[i],
              status: progress.of(sections[i].step),
              active: i == currentStep,
              onTap: () => onStepTapped(i),
            ),
        ],
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.section,
    required this.status,
    required this.active,
    required this.onTap,
  });

  final _FormSection section;
  final StepStatus status;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statusColor = switch (status) {
      StepStatus.done => theme.status.success,
      StepStatus.started => theme.status.warning,
      StepStatus.empty => scheme.onSurfaceVariant,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Semantics(
        button: true,
        selected: active,
        label: '${section.title}, ${status.label}',
        excludeSemantics: true,
        child: Material(
          color: active ? scheme.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    Icon(section.icon,
                        size: 22,
                        color: active
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            section.title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight:
                                  active ? FontWeight.w700 : FontWeight.w500,
                              color: active ? scheme.onPrimaryContainer : null,
                            ),
                          ),
                          Text(
                            status.label,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: statusColor),
                          ),
                        ],
                      ),
                    ),
                    Icon(_iconOf(status), size: 20, color: statusColor),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sticky bar: back, where you are, forward (or finish on the last step).
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.index,
    required this.count,
    required this.busy,
    required this.savingLabel,
    required this.onPrevious,
    required this.onNext,
    required this.onFinish,
    this.canComplete = true,
  });

  final int index;
  final int count;
  final bool busy;
  final String savingLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  /// False for apprentices: the last step offers Save, not Complete & Save.
  final bool canComplete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = index == count - 1;

    return Material(
      color: scheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Flexible: at large text sizes the labels shrink with an
              // ellipsis instead of pushing the bar past the screen edge.
              Flexible(
                child: OutlinedButton.icon(
                  onPressed: busy || index == 0 ? null : onPrevious,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Previous'),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: last
                    ? FilledButton.icon(
                        onPressed: busy ? null : onFinish,
                        icon: busy
                            ? const LoadingIndicator.button()
                            : const Icon(Icons.check),
                        label: Text(busy ? savingLabel : (canComplete ? 'Complete & Save' : 'Save')),
                      )
                    : FilledButton.icon(
                        onPressed: busy ? null : onNext,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Next'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
