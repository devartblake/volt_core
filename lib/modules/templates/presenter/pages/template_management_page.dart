import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/feature_flags.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/services/sync/sync_context.dart';
import '../../../../shared/widgets/app_page.dart';
import '../../domain/entities/template_entities.dart';
import '../../domain/services/generator_pilot_readiness.dart';
import '../../domain/services/template_revision_lifecycle.dart';
import '../../infra/repositories/template_definition_repository.dart';
import '../../infra/repositories/template_definition_repository_impl.dart';
import '../../infra/repositories/template_management_repository.dart';
import '../../infra/repositories/template_management_repository_impl.dart';
import '../../infra/services/generator_template_pack_installer.dart';
import 'template_draft_editor_page.dart';

class TemplateManagementPage extends ConsumerStatefulWidget {
  const TemplateManagementPage({super.key});

  @override
  ConsumerState<TemplateManagementPage> createState() =>
      _TemplateManagementPageState();
}

class _TemplateManagementPageState extends ConsumerState<TemplateManagementPage> {
  static const _lifecycle = TemplateRevisionLifecycle();
  static const _uuid = Uuid();

  bool _loading = true;
  bool _installingPack = false;
  String? _error;
  List<FormTemplate> _templates = const [];
  FormTemplate? _selectedTemplate;
  List<FormTemplateRevision> _revisions = const [];
  Map<String, List<FormTemplateRevision>> _pilotRevisionsByTemplateId = const {};

  TemplateDefinitionRepository get _definitions =>
      ref.read(templateDefinitionRepositoryProvider);
  TemplateManagementRepository get _management =>
      ref.read(templateManagementRepositoryProvider);

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_loadTemplates);
  }

  Future<void> _loadTemplates() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final templates = await _definitions.listTemplates();
      final pilotRevisions = await _loadPilotRevisionMap(templates);
      final selected = templates.isEmpty ? null : templates.first;
      final selectedRevisions = selected == null
          ? const <FormTemplateRevision>[]
          : pilotRevisions[selected.id] ??
                await _management.listRevisions(selected.id);

      if (!mounted) return;
      setState(() {
        _templates = templates;
        _selectedTemplate = selected;
        _revisions = selectedRevisions;
        _pilotRevisionsByTemplateId = pilotRevisions;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Map<String, List<FormTemplateRevision>>> _loadPilotRevisionMap(
    Iterable<FormTemplate> templates,
  ) async {
    final result = <String, List<FormTemplateRevision>>{};
    for (final template in templates) {
      if (!_isGeneratorPilotTemplate(template)) continue;
      result[template.id] = await _management.listRevisions(template.id);
    }
    return result;
  }

  bool _isGeneratorPilotTemplate(FormTemplate template) =>
      template.slug == GeneratorPilotReadiness.inspectionSlug ||
      template.slug == GeneratorPilotReadiness.maintenanceSlug;

  Future<void> _installGeneratorPack() async {
    final tenantId = SyncContext.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      _showMessage('Select an active tenant before installing templates.');
      return;
    }

    setState(() => _installingPack = true);
    try {
      final installer = GeneratorTemplatePackInstaller(
        definitions: _definitions,
        management: _management,
      );
      final installed = await installer.installMissing(tenantId: tenantId);
      if (!mounted) return;
      _showMessage(
        installed.isEmpty
            ? 'Generator inspection and maintenance templates are already installed.'
            : 'Installed: ${installed.join(', ')}.',
      );
      await _loadTemplates();
    } catch (error) {
      if (mounted) _showMessage('Could not install generator templates: $error');
    } finally {
      if (mounted) setState(() => _installingPack = false);
    }
  }

  Future<void> _loadRevisions(FormTemplate template) async {
    setState(() {
      _selectedTemplate = template;
      _loading = true;
      _error = null;
    });
    try {
      final revisions = await _management.listRevisions(template.id);
      if (!mounted) return;
      setState(() {
        _revisions = revisions;
        if (_isGeneratorPilotTemplate(template)) {
          _pilotRevisionsByTemplateId = {
            ..._pilotRevisionsByTemplateId,
            template.id: revisions,
          };
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cloneRevision(FormTemplateRevision revision) async {
    final definition = await _definitions.getDefinition(
      revision.templateId,
      revisionId: revision.id,
    );
    if (definition == null) {
      _showMessage('The selected revision definition could not be loaded.');
      return;
    }

    final draft = _lifecycle.cloneAsDraft(
      source: definition,
      existing: _revisions,
      idFactory: _uuid.v4,
      now: DateTime.now().toUtc(),
    );
    await _management.saveDraft(draft);
    if (!mounted) return;
    _showMessage('Draft revision ${draft.revision.revisionNumber} created.');
    await _loadRevisions(definition.template);
    if (!mounted) return;
    await _openDraftEditor(draft.revision);
  }

  Future<void> _openDraftEditor(FormTemplateRevision revision) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => TemplateDraftEditorPage(
          templateId: revision.templateId,
          revisionId: revision.id,
        ),
      ),
    );
    if (!mounted || _selectedTemplate == null) return;
    await _loadRevisions(_selectedTemplate!);
  }

  Future<void> _publish(FormTemplateRevision revision) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Publish revision?'),
        content: Text(
          'Revision ${revision.revisionNumber} will become the active template. '
          'The current published revision, if any, will be archived atomically.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Publish'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _management.publish(revision.id);
    if (!mounted) return;
    _showMessage('Revision ${revision.revisionNumber} published.');
    await _loadRevisions(_selectedTemplate!);
  }

  Future<void> _archive(FormTemplateRevision revision) async {
    await _management.archive(revision.id);
    if (!mounted) return;
    _showMessage('Draft revision ${revision.revisionNumber} archived.');
    await _loadRevisions(_selectedTemplate!);
  }

  void _launchPilot(String slug) {
    if (!FeatureFlags.generatorTemplatePilotEnabled) {
      _showMessage(
        'Rebuild with --dart-define=VOLTCORE_GENERATOR_TEMPLATE_PILOT=true '
        'before starting the controlled pilot.',
      );
      return;
    }
    final path = RoutePaths.templateResponse.replaceFirst(':templateSlug', slug);
    context.push(path);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Template Management',
      actions: [
        FilledButton.tonalIcon(
          onPressed: _loading || _installingPack ? null : _installGeneratorPack,
          icon: _installingPack
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_for_offline_outlined),
          label: const Text('Install generator templates'),
        ),
        IconButton(
          tooltip: 'Refresh templates and pilot readiness',
          onPressed: _loading ? null : _loadTemplates,
          icon: const Icon(Icons.refresh),
        ),
      ],
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _templates.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _templates.isEmpty) {
      return _ErrorState(message: _error!, onRetry: _loadTemplates);
    }
    if (_templates.isEmpty) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.description_outlined, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'No templates are installed for this tenant. Install the built-in '
                  'generator inspection and maintenance pack to begin Phase 3 pilot '
                  'configuration.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _installingPack ? null : _installGeneratorPack,
                  icon: const Icon(Icons.download_for_offline_outlined),
                  label: const Text('Install generator templates'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final selected = _selectedTemplate ?? _templates.first;
    final readiness = GeneratorPilotReadiness.evaluate(
      tenantId: SyncContext.tenantId,
      pilotEnabled: FeatureFlags.generatorTemplatePilotEnabled,
      templates: _templates,
      revisionsByTemplateId: _pilotRevisionsByTemplateId,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final pilotCard = _GeneratorPilotReadinessCard(
          readiness: readiness,
          onLaunchInspection: () =>
              _launchPilot(GeneratorPilotReadiness.inspectionSlug),
          onLaunchMaintenance: () =>
              _launchPilot(GeneratorPilotReadiness.maintenanceSlug),
        );
        final templateList = _TemplateList(
          templates: _templates,
          selectedId: selected.id,
          onSelected: _loadRevisions,
        );
        final revisionList = _RevisionList(
          template: selected,
          revisions: _revisions,
          loading: _loading,
          error: _error,
          onClone: _cloneRevision,
          onEdit: _openDraftEditor,
          onPublish: _publish,
          onArchive: _archive,
        );

        if (wide) {
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: pilotCard,
              ),
              Expanded(
                child: Row(
                  children: [
                    SizedBox(width: 320, child: templateList),
                    const VerticalDivider(width: 1),
                    Expanded(child: revisionList),
                  ],
                ),
              ),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            pilotCard,
            const SizedBox(height: 16),
            templateList,
            const Divider(height: 32),
            revisionList,
          ],
        );
      },
    );
  }
}

class _GeneratorPilotReadinessCard extends StatelessWidget {
  const _GeneratorPilotReadinessCard({
    required this.readiness,
    required this.onLaunchInspection,
    required this.onLaunchMaintenance,
  });

  final GeneratorPilotReadiness readiness;
  final VoidCallback onLaunchInspection;
  final VoidCallback onLaunchMaintenance;

  @override
  Widget build(BuildContext context) {
    final headline = readiness.fullyReady
        ? 'Ready to launch'
        : readiness.templateDataReady
            ? 'Templates ready • pilot build flag required'
            : 'Pilot prerequisites need attention';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Phase 3 Generator Pilot Readiness',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Chip(label: Text(headline)),
              ],
            ),
            const SizedBox(height: 12),
            _ReadinessRow(
              label: 'Active tenant',
              ready: readiness.tenantConfigured,
              detail: readiness.tenantConfigured
                  ? readiness.tenantId!
                  : 'No active tenant configured',
            ),
            _ReadinessRow(
              label: 'Pilot build',
              ready: readiness.pilotEnabled,
              detail: readiness.pilotEnabled
                  ? 'VOLTCORE_GENERATOR_TEMPLATE_PILOT=true'
                  : 'Disabled — rebuild with '
                        '--dart-define=VOLTCORE_GENERATOR_TEMPLATE_PILOT=true',
            ),
            _ReadinessRow(
              label: readiness.inspection.label,
              ready: readiness.inspection.isReady,
              detail: readiness.inspection.statusLabel,
            ),
            _ReadinessRow(
              label: readiness.maintenance.label,
              ready: readiness.maintenance.isReady,
              detail: readiness.maintenance.statusLabel,
            ),
            if (readiness.blockers.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final blocker in readiness.blockers)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• $blocker'),
                ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: readiness.canLaunchInspection
                      ? onLaunchInspection
                      : null,
                  icon: const Icon(Icons.assignment_turned_in_outlined),
                  label: const Text('Start inspection pilot'),
                ),
                OutlinedButton.icon(
                  onPressed: readiness.canLaunchMaintenance
                      ? onLaunchMaintenance
                      : null,
                  icon: const Icon(Icons.build_circle_outlined),
                  label: const Text('Start maintenance pilot'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadinessRow extends StatelessWidget {
  const _ReadinessRow({
    required this.label,
    required this.ready,
    required this.detail,
  });

  final String label;
  final bool ready;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ready ? Icons.check_circle_outline : Icons.info_outline,
            size: 20,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 180,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(detail)),
        ],
      ),
    );
  }
}

class _TemplateList extends StatelessWidget {
  const _TemplateList({
    required this.templates,
    required this.selectedId,
    required this.onSelected,
  });

  final List<FormTemplate> templates;
  final String selectedId;
  final ValueChanged<FormTemplate> onSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.all(12),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        return Card(
          child: ListTile(
            selected: template.id == selectedId,
            leading: const Icon(Icons.description_outlined),
            title: Text(template.name),
            subtitle: Text('${template.assetType} • ${template.slug}'),
            onTap: () => onSelected(template),
          ),
        );
      },
    );
  }
}

class _RevisionList extends StatelessWidget {
  const _RevisionList({
    required this.template,
    required this.revisions,
    required this.loading,
    required this.error,
    required this.onClone,
    required this.onEdit,
    required this.onPublish,
    required this.onArchive,
  });

  final FormTemplate template;
  final List<FormTemplateRevision> revisions;
  final bool loading;
  final String? error;
  final Future<void> Function(FormTemplateRevision) onClone;
  final Future<void> Function(FormTemplateRevision) onEdit;
  final Future<void> Function(FormTemplateRevision) onPublish;
  final Future<void> Function(FormTemplateRevision) onArchive;

  @override
  Widget build(BuildContext context) {
    if (loading && revisions.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.all(16),
      children: [
        Text(template.name, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(template.description.isEmpty ? template.slug : template.description),
        const SizedBox(height: 16),
        if (error != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(error!),
            ),
          ),
        if (revisions.isEmpty && !loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Text('No revisions found for this template.'),
          ),
        for (final revision in revisions)
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${revision.revisionNumber}')),
              title: Text(revision.title),
              subtitle: Text(
                '${revision.status.name} • updated '
                '${revision.updatedAt.toLocal().toString().split('.').first}',
              ),
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Clone as new draft',
                    onPressed: () => onClone(revision),
                    icon: const Icon(Icons.copy_outlined),
                  ),
                  if (revision.status == TemplateRevisionStatus.draft)
                    IconButton(
                      tooltip: 'Edit draft',
                      onPressed: () => onEdit(revision),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                  if (revision.status == TemplateRevisionStatus.draft)
                    IconButton(
                      tooltip: 'Publish revision',
                      onPressed: () => onPublish(revision),
                      icon: const Icon(Icons.publish_outlined),
                    ),
                  if (revision.status == TemplateRevisionStatus.draft)
                    IconButton(
                      tooltip: 'Archive draft',
                      onPressed: () => onArchive(revision),
                      icon: const Icon(Icons.archive_outlined),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
