import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/template_entities.dart';
import '../mappers/template_supabase_mapper.dart';

abstract class TemplateManagementRemoteDatasource {
  Future<List<FormTemplateRevision>> listRevisions(String templateId);
  Future<void> saveDraft(FormTemplateDefinition definition);
  Future<void> publish(String revisionId);
  Future<void> archive(String revisionId);
}

class TemplateManagementRemoteDatasourceImpl
    implements TemplateManagementRemoteDatasource {
  TemplateManagementRemoteDatasourceImpl({SupabaseClient? client})
      : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _supabase {
    final injected = _client;
    if (injected != null) return injected;
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError('Supabase has not been initialized.');
    }
  }

  @override
  Future<List<FormTemplateRevision>> listRevisions(String templateId) async {
    final rows = await _supabase
        .from(kFormTemplateRevisionsTable)
        .select()
        .eq('template_id', templateId)
        .order('revision_number', ascending: false);
    return rows
        .map(
          (row) => formTemplateRevisionFromSupabaseJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> saveDraft(FormTemplateDefinition definition) async {
    if (definition.revision.status != TemplateRevisionStatus.draft) {
      throw StateError('Only draft definitions can be saved.');
    }
    await _supabase.rpc(
      'save_form_template_draft',
      params: {'p_definition': _definitionJson(definition)},
    );
  }

  @override
  Future<void> publish(String revisionId) async {
    await _supabase.rpc(
      'publish_form_template_revision',
      params: {'p_revision_id': revisionId},
    );
  }

  @override
  Future<void> archive(String revisionId) async {
    await _supabase
        .from(kFormTemplateRevisionsTable)
        .update({
          'status': TemplateRevisionStatus.archived.name,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', revisionId)
        .eq('status', TemplateRevisionStatus.draft.name);
  }
}

Map<String, dynamic> _definitionJson(FormTemplateDefinition definition) => {
      'template': formTemplateToSupabaseJson(definition.template),
      'revision': formTemplateRevisionToSupabaseJson(definition.revision),
      'sections':
          definition.sections.map(formTemplateSectionToSupabaseJson).toList(),
      'fields': definition.fields.map(formTemplateFieldToSupabaseJson).toList(),
      'options': definition.options
          .map(formTemplateFieldOptionToSupabaseJson)
          .toList(),
    };

final templateManagementRemoteDatasourceProvider =
    Provider<TemplateManagementRemoteDatasource>(
  (ref) => TemplateManagementRemoteDatasourceImpl(),
);
