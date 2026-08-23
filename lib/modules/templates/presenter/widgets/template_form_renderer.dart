import 'package:flutter/material.dart';

import '../../domain/entities/template_entities.dart';
import '../../domain/services/template_response_validation.dart';

typedef TemplateAttachmentFieldBuilder = Widget Function(
  BuildContext context,
  FormTemplateField field,
  Object? value,
  ValueChanged<Object?> onChanged,
  bool readOnly,
);

class TemplateFormRenderer extends StatelessWidget {
  const TemplateFormRenderer({
    super.key,
    required this.definition,
    required this.values,
    required this.onChanged,
    this.validationIssues = const [],
    this.readOnly = false,
    this.attachmentFieldBuilder,
    this.padding = const EdgeInsets.all(16),
  });

  final FormTemplateDefinition definition;
  final Map<String, dynamic> values;
  final void Function(String fieldKey, Object? value) onChanged;
  final List<FormResponseValidationIssue> validationIssues;
  final bool readOnly;
  final TemplateAttachmentFieldBuilder? attachmentFieldBuilder;
  final EdgeInsetsGeometry padding;

  static const _validator = TemplateResponseValidator();

  @override
  Widget build(BuildContext context) {
    final issuesByField = <String, String>{
      for (final issue in validationIssues) issue.fieldKey: issue.message,
    };

    final visibleSections = definition.sections
        .where(
          (section) => _validator.isRuleVisible(
            rule: section.visibilityRule,
            values: values,
          ),
        )
        .toList(growable: false);

    return ListView(
      padding: padding,
      children: [
        if (definition.revision.instructions.trim().isNotEmpty) ...[
          Text(
            definition.revision.instructions,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
        ],
        for (final section in visibleSections)
          _SectionCard(
            section: section,
            fields: definition
                .fieldsForSection(section.id)
                .where(
                  (field) => _validator.isVisible(field: field, values: values),
                )
                .toList(growable: false),
            definition: definition,
            values: values,
            issuesByField: issuesByField,
            readOnly: readOnly,
            attachmentFieldBuilder: attachmentFieldBuilder,
            onChanged: onChanged,
          ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.fields,
    required this.definition,
    required this.values,
    required this.issuesByField,
    required this.readOnly,
    required this.attachmentFieldBuilder,
    required this.onChanged,
  });

  final FormTemplateSection section;
  final List<FormTemplateField> fields;
  final FormTemplateDefinition definition;
  final Map<String, dynamic> values;
  final Map<String, String> issuesByField;
  final bool readOnly;
  final TemplateAttachmentFieldBuilder? attachmentFieldBuilder;
  final void Function(String fieldKey, Object? value) onChanged;

  @override
  Widget build(BuildContext context) {
    if (fields.isEmpty) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(section.title, style: Theme.of(context).textTheme.titleLarge),
            if (section.description.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                section.description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 16),
            for (var index = 0; index < fields.length; index++) ...[
              _TemplateFieldControl(
                field: fields[index],
                options: definition.optionsForField(fields[index].id),
                value: values[fields[index].key] ?? fields[index].defaultValue,
                errorText: issuesByField[fields[index].key],
                readOnly: readOnly,
                attachmentFieldBuilder: attachmentFieldBuilder,
                onChanged: (value) => onChanged(fields[index].key, value),
              ),
              if (index < fields.length - 1) const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _TemplateFieldControl extends StatelessWidget {
  const _TemplateFieldControl({
    required this.field,
    required this.options,
    required this.value,
    required this.errorText,
    required this.readOnly,
    required this.attachmentFieldBuilder,
    required this.onChanged,
  });

  final FormTemplateField field;
  final List<FormTemplateFieldOption> options;
  final Object? value;
  final String? errorText;
  final bool readOnly;
  final TemplateAttachmentFieldBuilder? attachmentFieldBuilder;
  final ValueChanged<Object?> onChanged;

  String get _label => field.isRequired ? '${field.label} *' : field.label;

  @override
  Widget build(BuildContext context) {
    final control = switch (field.type) {
      TemplateFieldType.text => _textField(),
      TemplateFieldType.number => _numberField(),
      TemplateFieldType.reading => _numberField(reading: true),
      TemplateFieldType.date => _dateField(context),
      TemplateFieldType.select => _selectField(),
      TemplateFieldType.boolean => _booleanField(),
      TemplateFieldType.checklist => _checklistField(),
      TemplateFieldType.photo || TemplateFieldType.signature =>
        _attachmentField(context),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        control,
        if (field.helpText.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            field.helpText,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (errorText != null &&
            field.type != TemplateFieldType.text &&
            field.type != TemplateFieldType.number &&
            field.type != TemplateFieldType.reading &&
            field.type != TemplateFieldType.date &&
            field.type != TemplateFieldType.select) ...[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _textField() => TextFormField(
        key: ValueKey('${field.id}:${value ?? ''}'),
        initialValue: value?.toString() ?? '',
        enabled: !readOnly,
        decoration: InputDecoration(labelText: _label, errorText: errorText),
        minLines: 1,
        maxLines: field.validation['multiline'] == true ? 4 : 1,
        onChanged: onChanged,
      );

  Widget _numberField({bool reading = false}) => TextFormField(
        key: ValueKey('${field.id}:${value ?? ''}'),
        initialValue: value?.toString() ?? '',
        enabled: !readOnly,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: _label,
          errorText: errorText,
          suffixText: reading ? field.validation['unit']?.toString() : null,
        ),
        onChanged: (text) => onChanged(text.trim().isEmpty ? null : text),
      );

  Widget _dateField(BuildContext context) {
    final parsed = value is String ? DateTime.tryParse(value) : null;
    return TextFormField(
      key: ValueKey('${field.id}:${value ?? ''}'),
      initialValue: parsed == null
          ? value?.toString() ?? ''
          : parsed.toLocal().toIso8601String().split('T').first,
      readOnly: true,
      enabled: !readOnly,
      decoration: InputDecoration(
        labelText: _label,
        errorText: errorText,
        suffixIcon: const Icon(Icons.calendar_today_outlined),
      ),
      onTap: readOnly
          ? null
          : () async {
              final now = DateTime.now();
              final selected = await showDatePicker(
                context: context,
                initialDate: parsed?.toLocal() ?? now,
                firstDate: DateTime(now.year - 20),
                lastDate: DateTime(now.year + 20),
              );
              if (selected != null) {
                onChanged(selected.toIso8601String().split('T').first);
              }
            },
    );
  }

  Widget _selectField() {
    final optionValues = options.map((option) => option.value).toSet();
    final selected = value is String && optionValues.contains(value) ? value : null;
    return DropdownButtonFormField<String>(
      key: ValueKey('${field.id}:${selected ?? ''}'),
      initialValue: selected,
      decoration: InputDecoration(labelText: _label, errorText: errorText),
      items: [
        for (final option in options)
          DropdownMenuItem(value: option.value, child: Text(option.label)),
      ],
      onChanged: readOnly ? null : onChanged,
    );
  }

  Widget _booleanField() {
    final selected = value is bool ? <bool>{value} : <bool>{};
    return InputDecorator(
      decoration: InputDecoration(labelText: _label),
      child: SegmentedButton<bool>(
        segments: const [
          ButtonSegment(value: true, label: Text('Yes')),
          ButtonSegment(value: false, label: Text('No')),
        ],
        selected: selected,
        emptySelectionAllowed: true,
        onSelectionChanged: readOnly
            ? null
            : (selection) =>
                onChanged(selection.isEmpty ? null : selection.first),
      ),
    );
  }

  Widget _checklistField() {
    final selected = value is List
        ? value.map((item) => item.toString()).toSet()
        : <String>{};
    return InputDecorator(
      decoration: InputDecoration(labelText: _label),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final option in options)
            FilterChip(
              label: Text(option.label),
              selected: selected.contains(option.value),
              onSelected: readOnly
                  ? null
                  : (checked) {
                      final next = Set<String>.from(selected);
                      checked
                          ? next.add(option.value)
                          : next.remove(option.value);
                      onChanged(next.toList(growable: false));
                    },
            ),
        ],
      ),
    );
  }

  Widget _attachmentField(BuildContext context) {
    final builder = attachmentFieldBuilder;
    if (builder != null) {
      return builder(context, field, value, onChanged, readOnly);
    }
    final attached = value != null;
    return InputDecorator(
      decoration: InputDecoration(labelText: _label),
      child: Row(
        children: [
          Icon(
            field.type == TemplateFieldType.photo
                ? Icons.photo_camera_outlined
                : Icons.draw_outlined,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              attached
                  ? 'Attachment captured'
                  : 'No attachment captured',
            ),
          ),
          if (!readOnly && attached)
            IconButton(
              tooltip: 'Remove attachment',
              onPressed: () => onChanged(null),
              icon: const Icon(Icons.close),
            ),
        ],
      ),
    );
  }
}
