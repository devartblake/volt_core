import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/widgets/app_page.dart';
import '../../domain/entities/template_entities.dart';
import '../../domain/services/template_revision_lifecycle.dart';
import '../../infra/repositories/template_definition_repository.dart';
import '../../infra/repositories/template_definition_repository_impl.dart';
import '../../infra/repositories/template_management_repository.dart';
import '../../infra/repositories/template_management_repository_impl.dart';
import 'template_draft_editor_page.dart';

class TemplateManagementPage extends ConsumerStatefulWidget {
  const TemplateManagementPage({super.key});

  @override
  ConsumerState<TemplateManagementPage> createState() =>
      _TemplateManagementPageState();
}

class _TemplateManagementPageState
    extends ConsumerState<TemplateManagementPage> {
  static const _lifecycle = TemplateRevisionLifecycle();
  static const _uuid = Uuid();

  bool _loading = true;
  String? _error;
  List<FormTemplate> _templates = const [];
  FormTemplate? _selectedTemplate;
  List<FormTemplateRevision> _revisions = const [];

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
      if (!mounted) return;
      setState(() {
        _templates = templates;
        _selectedTemplate = templates.isEmpty ? null : templates.first;
      });
      if (_selectedTemplate != null) {
        await _loadRevisions(_selectedTemplate!);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
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
      setState(() => _revisions = revisions);
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

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Template Management',
      actions: [
        IconButton(
          tooltip: 'Refresh templates',
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
      return const Center(
        child: Text(
          'No templates are available yet. The generator template pack will be '
          'added in the next Phase 3 migration slice.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final selected = _selectedTemplate ?? _templates.first;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
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
          return Row(
            children: [
              SizedBox(width: 320, child: templateList),
              const VerticalDivider(width: 1),
              Expanded(child: revisionList),
            ],
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            templateList,
            const Divider(height: 32),
            revisionList,
          ],
        );
      },
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
