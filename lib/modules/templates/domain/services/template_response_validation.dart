import '../entities/template_entities.dart';

/// A field-level error reported by the generic form renderer before completion.
class FormResponseValidationIssue {
  const FormResponseValidationIssue({
    required this.fieldKey,
    required this.message,
  });

  final String fieldKey;
  final String message;
}

/// Applies template metadata consistently on web, mobile, and offline drafts.
///
/// Supported visibility contract:
/// `{ "field": "other_key", "equals": value }`, `{ "notEquals": value }`,
/// or `{ "in": [value1, value2] }`. Empty rules leave a field visible.
/// Supported validation keys: `min`, `max`, `minLength`, `maxLength`, and
/// `allowed`. Select options are always considered an allowed-value list.
class TemplateResponseValidator {
  const TemplateResponseValidator();

  List<FormResponseValidationIssue> validate({
    required FormTemplateDefinition definition,
    required Map<String, dynamic> values,
  }) {
    final issues = <FormResponseValidationIssue>[];
    for (final field in definition.fields) {
      if (!isVisible(field: field, values: values)) continue;

      final value = values[field.key];
      if (field.isRequired && _isEmpty(value)) {
        issues.add(_issue(field, 'This field is required.'));
        continue;
      }
      if (_isEmpty(value)) continue;

      final typeMessage = _typeMessage(field.type, value);
      if (typeMessage != null) {
        issues.add(_issue(field, typeMessage));
        continue;
      }

      final validation = field.validation;
      final rangeMessage = _rangeMessage(value, validation);
      if (rangeMessage != null) issues.add(_issue(field, rangeMessage));

      final allowed = <Object?>[
        ..._list(validation['allowed']),
        ...definition.optionsForField(field.id).map((option) => option.value),
      ].toSet();
      if (allowed.isNotEmpty && !allowed.contains(value)) {
        issues.add(_issue(field, 'Select one of the allowed values.'));
      }
    }
    return issues;
  }

  bool isVisible({
    required FormTemplateField field,
    required Map<String, dynamic> values,
  }) {
    final rule = field.visibilityRule;
    if (rule.isEmpty) return true;
    final sourceKey = rule['field'];
    if (sourceKey is! String || sourceKey.isEmpty) return true;
    final sourceValue = values[sourceKey];
    if (rule.containsKey('equals')) return sourceValue == rule['equals'];
    if (rule.containsKey('notEquals')) return sourceValue != rule['notEquals'];
    final allowed = _list(rule['in']);
    return allowed.isEmpty || allowed.contains(sourceValue);
  }

  FormResponseValidationIssue _issue(FormTemplateField field, String message) =>
      FormResponseValidationIssue(fieldKey: field.key, message: message);

  String? _typeMessage(TemplateFieldType type, Object? value) => switch (type) {
        TemplateFieldType.number || TemplateFieldType.reading =>
          _number(value) == null ? 'Enter a valid number.' : null,
        TemplateFieldType.date =>
          value is String && DateTime.tryParse(value) != null
              ? null
              : 'Enter a valid date.',
        TemplateFieldType.boolean => value is bool ? null : 'Choose yes or no.',
        TemplateFieldType.checklist =>
          value is List ? null : 'Select one or more checklist values.',
        TemplateFieldType.photo || TemplateFieldType.signature =>
          value is String || value is Map ? null : 'Attach a file.',
        _ => null,
      };

  String? _rangeMessage(Object? value, Map<String, dynamic> validation) {
    final numericValue = _number(value);
    final min = _number(validation['min']);
    final max = _number(validation['max']);
    if (numericValue != null) {
      if (min != null && numericValue < min) {
        return 'Enter a value of at least $min.';
      }
      if (max != null && numericValue > max) {
        return 'Enter a value no greater than $max.';
      }
    }

    final length = switch (value) {
      String value => value.length,
      List value => value.length,
      _ => null,
    };
    final minLength = _number(validation['minLength'])?.toInt();
    final maxLength = _number(validation['maxLength'])?.toInt();
    if (length != null) {
      if (minLength != null && length < minLength) {
        return 'Enter at least $minLength characters or selections.';
      }
      if (maxLength != null && length > maxLength) {
        return 'Enter no more than $maxLength characters or selections.';
      }
    }
    return null;
  }
}

bool _isEmpty(Object? value) =>
    value == null ||
    (value is String && value.trim().isEmpty) ||
    (value is List && value.isEmpty);

num? _number(Object? value) => switch (value) {
  num value => value,
  String value => num.tryParse(value),
  _ => null,
};

List<Object?> _list(Object? value) =>
    value is List ? List<Object?>.from(value) : const <Object?>[];
