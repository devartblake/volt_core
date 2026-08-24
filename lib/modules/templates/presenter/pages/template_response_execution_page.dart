import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/sync/sync_context.dart';
import '../../../../shared/widgets/app_page.dart';
import '../../domain/entities/template_entities.dart';
import '../../infra/repositories/form_response_repository.dart';
import '../../infra/repositories/form_response_repository_impl.dart';
import '../../infra/repositories/form_response_report_repository_impl.dart';
import '../../infra/repositories/template_definition_repository.dart';
import '../../infra/repositories/template_definition_repository_impl.dart';
import '../../infra/services/template_report_storage_service.dart';
import '../controllers/template_response_session_controller.dart';
import '../widgets/template_form_renderer.dart';
import '../../../auth/presenter/controllers/auth_controller.dart';

/// Technician-facing runtime for a published, revision-pinned template.
///
/// New work resolves the current published revision exactly once and persists a
/// local draft before the form is shown. Reopened work resolves the exact
/// revision already pinned to the saved response, so publishing a newer
/// revision cannot mutate or invalidate an in-progress/completed field record.
class TemplateResponseExecutionPage extends ConsumerStatefulWidget {
  const TemplateResponseExecutionPage({
    super.key,
    required this.templateSlug,
    this.responseId,
    this.subjectType = 'asset',
    this.subjectId,
    this.customerId,
    this.siteId,
    this.assetId,
    this.workOrderId,
    this.inspectionId,
    this.maintenanceRecordId,
  });

  final String templateSlug;
  final String? responseId;
  final String subjectType;
  final String? subjectId;
  final String? customerId;
  final String? siteId;
  final String? assetId;
  final String? workOrderId;
  final String? inspectionId;
  final String? maintenanceRecordId;

  @override
  ConsumerState<TemplateResponseExecutionPage> createState() =>
      _TemplateResponseExecutionPageState();
}

class _TemplateResponseExecutionPageState
    extends ConsumerState<TemplateResponseExecutionPage> {
  static const _uuid = Uuid();

  bool _loading = true;
  String? _error;
  FormTemplateDefinition? _definition;
  TemplateResponseSessionController? _session;

  TemplateDefinitionRepository get _definitions =>
      ref.read(templateDefinitionRepositoryProvider);
  FormResponseRepository get _responses =>
      ref.read(formResponseRepositoryProvider);

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_initialize);
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    try {
      final existingId = widget.responseId;
      late final FormResponse response;
      late final FormTemplateDefinition definition;

      if (existingId != null && existingId.isNotEmpty) {
        final existing = await _responses.getById(existingId);
        if (existing == null) {
          throw StateError(
            'The requested response is not available in the active tenant.',
          );
        }
        final loaded = await _definitions.getDefinition(
          existing.templateId,
          revisionId: existing.templateRevisionId,
        );
        if (loaded == null) {
          throw StateError(
            'Revision ${existing.templateRevisionId} is not available locally or remotely.',
          );
        }
        if (loaded.template.slug != widget.templateSlug) {
          throw StateError('The response belongs to another template.');
        }
        response = existing;
        definition = loaded;
      } else {
        final templates = await _definitions.listTemplates();
        final matches = templates
            .where((item) => item.slug == widget.templateSlug && !item.isArchived)
            .toList(growable: false);
        if (matches.isEmpty) {
          throw StateError(
            'No active template named "${widget.templateSlug}" is installed.',
          );
        }
        if (matches.length > 1) {
          throw StateError(
            'More than one active template uses "${widget.templateSlug}".',
          );
        }

        final loaded = await _definitions.getDefinition(matches.single.id);
        if (loaded == null ||
            loaded.revision.status != TemplateRevisionStatus.published) {
          throw StateError(
            'No published revision is available for "${widget.templateSlug}".',
          );
        }
        definition = loaded;

        final tenantId = SyncContext.tenantId;
        if (tenantId == null || tenantId.isEmpty) {
          throw StateError('An active tenant is required to start field work.');
        }
        if (tenantId != definition.template.tenantId) {
          throw StateError('The published template belongs to another tenant.');
        }

        final now = DateTime.now().toUtc();
        response = await _responses.save(
          FormResponse(
            id: _uuid.v4(),
            tenantId: tenantId,
            templateId: definition.template.id,
            templateRevisionId: definition.revision.id,
            status: TemplateResponseStatus.draft,
            subjectType: widget.subjectType,
            subjectId: widget.subjectId,
            customerId: widget.customerId,
            siteId: widget.siteId,
            assetId: widget.assetId,
            workOrderId: widget.workOrderId,
            inspectionId: widget.inspectionId,
            maintenanceRecordId: widget.maintenanceRecordId,
            values: const {},
            createdAt: now,
            updatedAt: now,
          ),
        );
      }

      final session = TemplateResponseSessionController(
        definition: definition,
        repository: _responses,
        response: response,
      );
      if (!mounted) {
        session.dispose();
        return;
      }
      setState(() {
        _definition = definition;
        _session = session;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _complete() async {
    final session = _session;
    final definition = _definition;
    final userId = ref.read(authStateProvider).userId;
    if (session == null || definition == null) return;
    if (userId == null || userId.isEmpty) {
      _showMessage('Your authenticated user ID is unavailable.');
      return;
    }

    try {
      final result = await session.complete(completedByUserId: userId);
      if (!mounted) return;
      if (!result.completed) {
        _showMessage(
          '${result.issues.length} required or invalid field(s) need attention.',
        );
        return;
      }

      String reportMessage = 'Response completed and locked.';
      try {
        final report = await TemplateReportStorageService(
          artifacts: ref.read(formResponseReportRepositoryProvider),
        ).generateAndSave(
          definition: definition,
          response: session.response,
        );
        reportMessage = 'Response completed. Report saved to ${report.path}.';
      } catch (error) {
        // Completion is authoritative and must not be rolled back because local
        // report generation/cloud artifact registration has a transient error.
        reportMessage =
            'Response completed and locked. Report generation needs retry: $error';
      }
      if (mounted) _showMessage(reportMessage);
    } catch (error) {
      if (mounted) _showMessage('Could not complete response: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final definition = _definition;
    final session = _session;

    return AppPage(
      title: definition?.template.name ?? 'Field Form',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _PilotErrorState(message: _error!, onRetry: _retry)
              : definition == null || session == null
                  ? const Center(child: Text('Form runtime is unavailable.'))
                  : AnimatedBuilder(
                      animation: session,
                      builder: (context, _) => Column(
                        children: [
                          Expanded(
                            child: TemplateFormRenderer(
                              definition: definition,
                              values: session.values,
                              validationIssues: session.issues,
                              readOnly: session.isLocked,
                              onChanged: session.setValue,
                            ),
                          ),
                          _RuntimeFooter(
                            response: session.response,
                            saving: session.isSaving,
                            saveError: session.lastSaveError,
                            locked: session.isLocked,
                            onRetrySave: session.flush,
                            onComplete: _complete,
                          ),
                        ],
                      ),
                    ),
    );
  }

  Future<void> _retry() async {
    _session?.dispose();
    setState(() {
      _session = null;
      _definition = null;
      _error = null;
      _loading = true;
    });
    await _initialize();
  }
}

class _RuntimeFooter extends StatelessWidget {
  const _RuntimeFooter({
    required this.response,
    required this.saving,
    required this.saveError,
    required this.locked,
    required this.onRetrySave,
    required this.onComplete,
  });

  final FormResponse response;
  final bool saving;
  final Object? saveError;
  final bool locked;
  final Future<void> Function() onRetrySave;
  final Future<void> Function() onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                response.isComplete
                    ? 'Completed • Revision locked'
                    : saving
                        ? 'Saving locally…'
                        : saveError == null
                            ? 'Draft autosave enabled'
                            : 'Draft save needs retry',
                style: theme.textTheme.bodySmall,
              ),
            ),
            if (saveError != null && !locked) ...[
              TextButton(
                onPressed: saving ? null : () => onRetrySave(),
                child: const Text('Retry save'),
              ),
              const SizedBox(width: 8),
            ],
            FilledButton.icon(
              onPressed: locked || saving ? null : () => onComplete(),
              icon: Icon(
                response.isComplete
                    ? Icons.lock_outline
                    : Icons.task_alt_outlined,
              ),
              label: Text(response.isComplete ? 'Completed' : 'Complete form'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PilotErrorState extends StatelessWidget {
  const _PilotErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => onRetry(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
}
