import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../../core/services/sync/sync_context.dart';
import '../../domain/entities/template_entities.dart';
import '../datasources/template_definition_remote_datasource.dart';
import '../datasources/template_definitions_box.dart';
import '../mappers/template_supabase_mapper.dart';
import 'template_definition_repository.dart';

typedef TemplateDefinitionTenantReader = String? Function();

/// Remote-first template definitions with an immutable Hive fallback.
class TemplateDefinitionRepositoryImpl implements TemplateDefinitionRepository {
  TemplateDefinitionRepositoryImpl({
    Box<dynamic>? box,
    TemplateDefinitionRemoteDatasource? remote,
    TemplateDefinitionTenantReader? tenantIdReader,
  })  : _injectedBox = box,
        _remote = remote,
        _tenantIdReader = tenantIdReader ?? (() => SyncContext.tenantId);

  final Box<dynamic>? _injectedBox;
  final TemplateDefinitionRemoteDatasource? _remote;
  final TemplateDefinitionTenantReader _tenantIdReader;

  Box<dynamic> get _box => _injectedBox ?? TemplateDefinitionsBox.box;

  @override
  Future<List<FormTemplate>> listTemplates() async {
    final remote = _remote;
    if (remote != null) {
      try {
        return await remote.listTemplates();
      } catch (_) {
        // Cached definitions still allow a technician to open a response
        // offline. The definition lookup below has the full fallback logic.
      }
    }
    final tenantId = _tenantIdReader();
    final templatesById = <String, FormTemplate>{};
    for (final value in _box.values.whereType<Map>()) {
      final template = _definitionFromCache(value).template;
      if ((tenantId == null || template.tenantId == tenantId) &&
          !template.isArchived) {
        templatesById[template.id] = template;
      }
    }
    final templates = templatesById.values.toList()
      ..sort((first, second) => first.name.compareTo(second.name));
    return templates;
  }

  @override
  Future<FormTemplateDefinition?> getDefinition(
    String templateId, {
    String? revisionId,
  }) async {
    final remote = _remote;
    if (remote != null) {
      try {
        final remoteDefinition = await remote.getDefinition(
          templateId,
          revisionId: revisionId,
        );
        if (remoteDefinition != null && _isActiveTenant(remoteDefinition)) {
          final snapshot = _definitionToCache(remoteDefinition);
          await _box.put(_cacheKey(remoteDefinition), snapshot);
          if (revisionId == null &&
              remoteDefinition.revision.status ==
                  TemplateRevisionStatus.published) {
            await _box.put(_cacheKeyFor(templateId, null), snapshot);
          }
          return remoteDefinition;
        }
      } catch (_) {
        // Use the exact cached revision below; do not substitute another one.
      }
    }

    final cached = _box.get(_cacheKeyFor(templateId, revisionId));
    if (cached is! Map) return null;
    final definition = _definitionFromCache(cached);
    return _isActiveTenant(definition) ? definition : null;
  }

  bool _isActiveTenant(FormTemplateDefinition definition) {
    final tenantId = _tenantIdReader();
    return tenantId == null || definition.template.tenantId == tenantId;
  }

  String _cacheKey(FormTemplateDefinition definition) => _cacheKeyFor(
        definition.template.id,
        definition.revision.id,
      );

  String _cacheKeyFor(String templateId, String? revisionId) =>
      '${_tenantIdReader() ?? ''}/$templateId/${revisionId ?? 'published'}';
}

Map<String, dynamic> _definitionToCache(FormTemplateDefinition value) => {
      'template': formTemplateToSupabaseJson(value.template),
      'revision': formTemplateRevisionToSupabaseJson(value.revision),
      'sections': value.sections.map(formTemplateSectionToSupabaseJson).toList(),
      'fields': value.fields.map(formTemplateFieldToSupabaseJson).toList(),
      'options': value.options
          .map(formTemplateFieldOptionToSupabaseJson)
          .toList(),
    };

FormTemplateDefinition _definitionFromCache(Map<dynamic, dynamic> value) {
  Map<String, dynamic> map(Object? item) =>
      Map<String, dynamic>.from(item as Map);
  Iterable<Object?> list(Object? item) =>
      item is List ? item : const <Object?>[];
  return FormTemplateDefinition(
    template: formTemplateFromSupabaseJson(map(value['template'])),
    revision: formTemplateRevisionFromSupabaseJson(map(value['revision'])),
    sections: list(value['sections'])
        .map((item) => formTemplateSectionFromSupabaseJson(map(item))),
    fields: list(value['fields'])
        .map((item) => formTemplateFieldFromSupabaseJson(map(item))),
    options: list(value['options'])
        .map((item) => formTemplateFieldOptionFromSupabaseJson(map(item))),
  );
}

final templateDefinitionRepositoryProvider =
    Provider<TemplateDefinitionRepository>((ref) {
  return TemplateDefinitionRepositoryImpl(
    remote: ref.watch(templateDefinitionRemoteDatasourceProvider),
  );
});
