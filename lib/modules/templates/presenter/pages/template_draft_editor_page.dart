import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_page.dart';
import '../../domain/entities/template_entities.dart';
import '../../infra/repositories/template_definition_repository.dart';
import '../../infra/repositories/template_definition_repository_impl.dart';
import '../../infra/repositories/template_management_repository.dart';
import '../../infra/repositories/template_management_repository_impl.dart';

class TemplateDraftEditorPage extends ConsumerStatefulWidget {
  const TemplateDraftEditorPage({
    super.key,
    required this.templateId,
    required this.revisionId,
  });

  final String templateId;
  final String revisionId;

  @override
  ConsumerState<TemplateDraftEditorPage> createState() =>
      _TemplateDraftEditorPageState();
}

class _TemplateDraftEditorPageState
    extends ConsumerState<TemplateDraftEditorPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _instructionsController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  FormTemplateDefinition? _definition;
  List<_SectionDraft> _sections = const [];

  TemplateDefinitionRepository get _definitions =>
      ref.read(templateDefinitionRepositoryProvider);
  TemplateManagementRepository get _management =>
      ref.read(templateManagementRepositoryProvider);

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final definition = await _definitions.getDefinition(
        widget.templateId,
        revisionId: widget.revisionId,
      );
      if (definition == null) {
        throw StateError('Template revision could not be loaded.');
      }
      if (definition.revision.status != TemplateRevisionStatus.draft) {
        throw StateError('Only draft revisions can be edited.');
      }
      final sections = definition.sections
          .map(
            (section) => _SectionDraft(
              section: section,
              fields: definition
                  .fieldsForSection(section.id)
                  .map(
                    (field) => _FieldDraft(
                      field: field,
                      options: definition.optionsForField(field.id),
                    ),
                  )
                  .toList(growable: true),
            ),
          )
          .toList(growable: true);
      if (!mounted) return;
      setState(() {
        _definition = definition;
        _sections = sections;
        _titleController.text = definition.revision.title;
        _instructionsController.text = definition.revision.instructions;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final original = _definition;
    if (original == null) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final now = DateTime.now().toUtc();
      final sections = <FormTemplateSection>[];
      final fields = <FormTemplateField>[];
      final options = <FormTemplateFieldOption>[];

      for (var sectionIndex = 0; sectionIndex < _sections.length; sectionIndex++) {
        final sectionDraft = _sections[sectionIndex];
        sections.add(
          FormTemplateSection(
            id: sectionDraft.section.id,
            tenantId: sectionDraft.section.tenantId,
            revisionId: original.revision.id,
            key: sectionDraft.section.key,
            title: sectionDraft.title.trim(),
            description: sectionDraft.description.trim(),
            position: sectionIndex,
            visibilityRule: sectionDraft.visibility,
          ),
        );

        for (var fieldIndex = 0;
            fieldIndex < sectionDraft.fields.length;
            fieldIndex++) {
          final fieldDraft = sectionDraft.fields[fieldIndex];
          fields.add(
            FormTemplateField(
              id: fieldDraft.field.id,
              tenantId: fieldDraft.field.tenantId,
              revisionId: original.revision.id,
              sectionId: sectionDraft.section.id,
              key: fieldDraft.field.key,
              label: fieldDraft.label.trim(),
              helpText: fieldDraft.helpText.trim(),
              type: fieldDraft.type,
              position: fieldIndex,
              isRequired: fieldDraft.required,
              validation: fieldDraft.validation,
              visibilityRule: fieldDraft.visibility,
              defaultValue: fieldDraft.field.defaultValue,
            ),
          );
          for (var optionIndex = 0;
              optionIndex < fieldDraft.options.length;
              optionIndex++) {
            final option = fieldDraft.options[optionIndex];
            options.add(
              FormTemplateFieldOption(
                id: option.id,
                tenantId: option.tenantId,
                fieldId: fieldDraft.field.id,
                value: option.value,
                label: option.label,
                position: optionIndex,
              ),
            );
          }
        }
      }

      final updated = FormTemplateDefinition(
        template: original.template,
        revision: FormTemplateRevision(
          id: original.revision.id,
          tenantId: original.revision.tenantId,
          templateId: original.revision.templateId,
          revisionNumber: original.revision.revisionNumber,
          status: TemplateRevisionStatus.draft,
          title: _titleController.text.trim(),
          instructions: _instructionsController.text.trim(),
          settings: Map<String, dynamic>.from(original.revision.settings),
          createdAt: original.revision.createdAt,
          updatedAt: now,
        ),
        sections: sections,
        fields: fields,
        options: options,
      );
      await _management.saveDraft(updated);
      if (!mounted) return;
      setState(() => _definition = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft template saved.')),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Edit Template Draft',
      actions: [
        IconButton(
          tooltip: 'Reload draft',
          onPressed: _loading || _saving ? null : _load,
          icon: const Icon(Icons.refresh),
        ),
      ],
      bottomBar: _loading
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving…' : 'Save draft'),
                ),
              ),
            ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_definition == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error ?? 'Unable to load this draft.'),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(_error!),
              ),
            ),
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Revision title'),
            validator: _required,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _instructionsController,
            decoration: const InputDecoration(labelText: 'Instructions'),
            maxLines: 3,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sections and fields',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              OutlinedButton.icon(
                onPressed: _addSection,
                icon: const Icon(Icons.add),
                label: const Text('Section'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < _sections.length; index++)
            _SectionEditorCard(
              key: ValueKey(_sections[index].section.id),
              draft: _sections[index],
              canMoveUp: index > 0,
              canMoveDown: index < _sections.length - 1,
              onMoveUp: () => _moveSection(index, -1),
              onMoveDown: () => _moveSection(index, 1),
              onRemove: () => _removeSection(index),
              onChanged: () => setState(() {}),
            ),
        ],
      ),
    );
  }

  void _addSection() {
    final definition = _definition!;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    setState(() {
      _sections.add(
        _SectionDraft(
          section: FormTemplateSection(
            id: 'section-$stamp',
            tenantId: definition.template.tenantId,
            revisionId: definition.revision.id,
            key: 'section_$stamp',
            title: 'New section',
            position: _sections.length,
          ),
          fields: [],
        ),
      );
    });
  }

  void _removeSection(int index) => setState(() => _sections.removeAt(index));

  void _moveSection(int index, int delta) {
    final target = index + delta;
    if (target < 0 || target >= _sections.length) return;
    setState(() {
      final item = _sections.removeAt(index);
      _sections.insert(target, item);
    });
  }
}

class _SectionEditorCard extends StatelessWidget {
  const _SectionEditorCard({
    super.key,
    required this.draft,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
    required this.onChanged,
  });

  final _SectionDraft draft;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        initiallyExpanded: true,
        leading: const Icon(Icons.view_agenda_outlined),
        title: Text(draft.title.isEmpty ? draft.section.key : draft.title),
        trailing: Wrap(
          children: [
            IconButton(onPressed: canMoveUp ? onMoveUp : null, icon: const Icon(Icons.arrow_upward)),
            IconButton(onPressed: canMoveDown ? onMoveDown : null, icon: const Icon(Icons.arrow_downward)),
            IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline)),
          ],
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          TextFormField(
            initialValue: draft.title,
            decoration: const InputDecoration(labelText: 'Section title'),
            validator: _required,
            onChanged: (value) {
              draft.title = value;
              onChanged();
            },
          ),
          TextFormField(
            initialValue: draft.description,
            decoration: const InputDecoration(labelText: 'Description'),
            onChanged: (value) => draft.description = value,
          ),
          _JsonField(
            label: 'Section visibility JSON',
            value: draft.visibility,
            onChanged: (value) => draft.visibility = value,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: Text('Fields')),
              TextButton.icon(
                onPressed: () {
                  final stamp = DateTime.now().microsecondsSinceEpoch;
                  draft.fields.add(
                    _FieldDraft(
                      field: FormTemplateField(
                        id: 'field-$stamp',
                        tenantId: draft.section.tenantId,
                        revisionId: draft.section.revisionId,
                        sectionId: draft.section.id,
                        key: 'field_$stamp',
                        label: 'New field',
                        type: TemplateFieldType.text,
                        position: draft.fields.length,
                      ),
                      options: [],
                    ),
                  );
                  onChanged();
                },
                icon: const Icon(Icons.add),
                label: const Text('Field'),
              ),
            ],
          ),
          for (var index = 0; index < draft.fields.length; index++)
            _FieldEditorCard(
              key: ValueKey(draft.fields[index].field.id),
              draft: draft.fields[index],
              canMoveUp: index > 0,
              canMoveDown: index < draft.fields.length - 1,
              onMoveUp: () {
                final item = draft.fields.removeAt(index);
                draft.fields.insert(index - 1, item);
                onChanged();
              },
              onMoveDown: () {
                final item = draft.fields.removeAt(index);
                draft.fields.insert(index + 1, item);
                onChanged();
              },
              onRemove: () {
                draft.fields.removeAt(index);
                onChanged();
              },
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}

class _FieldEditorCard extends StatelessWidget {
  const _FieldEditorCard({
    super.key,
    required this.draft,
    required this.canMoveUp,
    required this.canMoveDown,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onRemove,
    required this.onChanged,
  });

  final _FieldDraft draft;
  final bool canMoveUp;
  final bool canMoveDown;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: Text(draft.label, style: Theme.of(context).textTheme.titleMedium)),
                IconButton(onPressed: canMoveUp ? onMoveUp : null, icon: const Icon(Icons.arrow_upward)),
                IconButton(onPressed: canMoveDown ? onMoveDown : null, icon: const Icon(Icons.arrow_downward)),
                IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline)),
              ],
            ),
            TextFormField(
              initialValue: draft.label,
              decoration: const InputDecoration(labelText: 'Field label'),
              validator: _required,
              onChanged: (value) {
                draft.label = value;
                onChanged();
              },
            ),
            TextFormField(
              initialValue: draft.helpText,
              decoration: const InputDecoration(labelText: 'Help text'),
              onChanged: (value) => draft.helpText = value,
            ),
            DropdownButtonFormField<TemplateFieldType>(
              initialValue: draft.type,
              decoration: const InputDecoration(labelText: 'Field type'),
              items: [
                for (final type in TemplateFieldType.values)
                  DropdownMenuItem(value: type, child: Text(type.name)),
              ],
              onChanged: (value) {
                if (value != null) draft.type = value;
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Required'),
              value: draft.required,
              onChanged: (value) {
                draft.required = value;
                onChanged();
              },
            ),
            _JsonField(
              label: 'Validation JSON',
              value: draft.validation,
              onChanged: (value) => draft.validation = value,
            ),
            _JsonField(
              label: 'Visibility JSON',
              value: draft.visibility,
              onChanged: (value) => draft.visibility = value,
            ),
            TextFormField(
              initialValue: draft.options.map((option) => '${option.value}|${option.label}').join(', '),
              decoration: const InputDecoration(
                labelText: 'Options',
                helperText: 'Comma-separated value|label pairs',
              ),
              onChanged: draft.setOptions,
            ),
          ],
        ),
      ),
    );
  }
}

class _JsonField extends StatelessWidget {
  const _JsonField({required this.label, required this.value, required this.onChanged});

  final String label;
  final Map<String, dynamic> value;
  final ValueChanged<Map<String, dynamic>> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: jsonEncode(value),
      decoration: InputDecoration(labelText: label),
      validator: (text) {
        if (text == null || text.trim().isEmpty) return null;
        try {
          final decoded = jsonDecode(text);
          if (decoded is! Map) return 'Enter a JSON object.';
        } catch (_) {
          return 'Enter valid JSON.';
        }
        return null;
      },
      onChanged: (text) {
        try {
          final decoded = jsonDecode(text);
          if (decoded is Map) onChanged(Map<String, dynamic>.from(decoded));
        } catch (_) {
          // Form validation reports malformed JSON before save.
        }
      },
    );
  }
}

class _SectionDraft {
  _SectionDraft({required this.section, required this.fields})
      : title = section.title,
        description = section.description,
        visibility = Map<String, dynamic>.from(section.visibilityRule);

  final FormTemplateSection section;
  final List<_FieldDraft> fields;
  String title;
  String description;
  Map<String, dynamic> visibility;
}

class _FieldDraft {
  _FieldDraft({required this.field, required List<FormTemplateFieldOption> options})
      : label = field.label,
        helpText = field.helpText,
        type = field.type,
        required = field.isRequired,
        validation = Map<String, dynamic>.from(field.validation),
        visibility = Map<String, dynamic>.from(field.visibilityRule),
        options = List<FormTemplateFieldOption>.from(options);

  final FormTemplateField field;
  String label;
  String helpText;
  TemplateFieldType type;
  bool required;
  Map<String, dynamic> validation;
  Map<String, dynamic> visibility;
  List<FormTemplateFieldOption> options;

  void setOptions(String text) {
    final parsed = <FormTemplateFieldOption>[];
    var index = 0;
    for (final raw in text.split(',')) {
      final item = raw.trim();
      if (item.isEmpty) continue;
      final separator = item.indexOf('|');
      final value = (separator < 0 ? item : item.substring(0, separator)).trim();
      final label = (separator < 0 ? item : item.substring(separator + 1)).trim();
      if (value.isEmpty || label.isEmpty) continue;
      parsed.add(
        FormTemplateFieldOption(
          id: index < options.length ? options[index].id : '${field.id}-option-$index',
          tenantId: field.tenantId,
          fieldId: field.id,
          value: value,
          label: label,
          position: index,
        ),
      );
      index++;
    }
    options = parsed;
  }
}

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Required.' : null;
