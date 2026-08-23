import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/template_entities.dart';
import '../../domain/services/template_response_validation.dart';
import '../../infra/repositories/form_response_repository.dart';

class TemplateResponseCompletionResult {
  const TemplateResponseCompletionResult({
    required this.completed,
    this.issues = const [],
  });

  final bool completed;
  final List<FormResponseValidationIssue> issues;
}

/// Owns one revision-pinned response while it is being completed in the field.
///
/// Changes are debounced into the existing local-first response repository.
/// That repository persists to Hive before enqueueing remote synchronization,
/// so a draft can be reopened after loss of connectivity or an app restart.
class TemplateResponseSessionController extends ChangeNotifier {
  TemplateResponseSessionController({
    required this.definition,
    required this.repository,
    required FormResponse response,
    this.autosaveDelay = const Duration(milliseconds: 750),
    TemplateResponseValidator validator = const TemplateResponseValidator(),
  })  : _response = response,
        _values = Map<String, dynamic>.from(response.values),
        _validator = validator {
    if (response.templateId != definition.template.id ||
        response.templateRevisionId != definition.revision.id) {
      throw ArgumentError(
        'The response must be pinned to the supplied template revision.',
      );
    }
  }

  final FormTemplateDefinition definition;
  final FormResponseRepository repository;
  final Duration autosaveDelay;
  final TemplateResponseValidator _validator;

  FormResponse _response;
  Map<String, dynamic> _values;
  Timer? _autosaveTimer;
  Future<void> _saveTail = Future<void>.value();
  bool _dirty = false;
  bool _saving = false;
  bool _completing = false;
  Object? _lastSaveError;
  List<FormResponseValidationIssue> _issues = const [];

  FormResponse get response => _response;
  Map<String, dynamic> get values => Map.unmodifiable(_values);
  List<FormResponseValidationIssue> get issues => List.unmodifiable(_issues);
  bool get isSaving => _saving;
  bool get isLocked => _response.isComplete || _completing;
  Object? get lastSaveError => _lastSaveError;

  void setValue(String fieldKey, Object? value) {
    if (isLocked) {
      throw StateError('Completed form responses are immutable.');
    }

    if (value == null) {
      _values.remove(fieldKey);
    } else {
      _values[fieldKey] = value;
    }

    _issues = const [];
    _dirty = true;
    _lastSaveError = null;
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(autosaveDelay, () => unawaited(flush()));
    notifyListeners();
  }

  Future<void> flush() {
    _autosaveTimer?.cancel();
    _autosaveTimer = null;
    if (!_dirty || isLocked) return _saveTail;

    final next = _saveTail
        .catchError((Object _) {})
        .then((_) => _saveDraftNow());
    _saveTail = next;
    return next;
  }

  Future<void> _saveDraftNow() async {
    if (!_dirty || isLocked) return;

    _dirty = false;
    _saving = true;
    notifyListeners();
    try {
      final draft = _copyResponse(
        status: TemplateResponseStatus.draft,
        values: _values,
        completedAt: null,
        completedByUserId: null,
      );
      _response = await repository.save(draft);
      _lastSaveError = null;
    } catch (error) {
      _dirty = true;
      _lastSaveError = error;
      rethrow;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<TemplateResponseCompletionResult> complete({
    required String completedByUserId,
  }) async {
    if (_response.isComplete) {
      return const TemplateResponseCompletionResult(completed: true);
    }
    if (_completing) {
      return TemplateResponseCompletionResult(
        completed: false,
        issues: _issues,
      );
    }

    await flush();
    final issues = _validator.validate(definition: definition, values: _values);
    if (issues.isNotEmpty) {
      _issues = issues;
      notifyListeners();
      return TemplateResponseCompletionResult(
        completed: false,
        issues: issues,
      );
    }

    _completing = true;
    notifyListeners();
    try {
      final completed = _copyResponse(
        status: TemplateResponseStatus.completed,
        values: _values,
        completedAt: DateTime.now().toUtc(),
        completedByUserId: completedByUserId,
      );
      _response = await repository.save(completed);
      _issues = const [];
      return const TemplateResponseCompletionResult(completed: true);
    } finally {
      _completing = false;
      notifyListeners();
    }
  }

  FormResponse _copyResponse({
    required TemplateResponseStatus status,
    required Map<String, dynamic> values,
    required DateTime? completedAt,
    required String? completedByUserId,
  }) =>
      FormResponse(
        id: _response.id,
        tenantId: _response.tenantId,
        templateId: _response.templateId,
        templateRevisionId: _response.templateRevisionId,
        status: status,
        subjectType: _response.subjectType,
        subjectId: _response.subjectId,
        customerId: _response.customerId,
        siteId: _response.siteId,
        assetId: _response.assetId,
        workOrderId: _response.workOrderId,
        inspectionId: _response.inspectionId,
        maintenanceRecordId: _response.maintenanceRecordId,
        values: Map<String, dynamic>.from(values),
        completedAt: completedAt,
        completedByUserId: completedByUserId,
        createdAt: _response.createdAt,
        updatedAt: _response.updatedAt,
      );

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    super.dispose();
  }
}
