import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/template_entities.dart';
import '../mappers/template_supabase_mapper.dart';

abstract class TemplateDefinitionRemoteDatasource {
  Future<List<FormTemplate>> listTemplates();

  Future<FormTemplateDefinition?> getDefinition(
    String templateId, {
    String? revisionId,
  });
}

class TemplateDefinitionRemoteDatasourceImpl
    implements TemplateDefinitionRemoteDatasource {
  TemplateDefinitionRemoteDatasourceImpl({SupabaseClient? client})
      : _client = client;

  final SupabaseClient? _client;

  SupabaseClient? get _supabase {
    if (_client != null) return _client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<FormTemplate>> listTemplates() async {
    final rows = await _requireClient()
        .from(kFormTemplatesTable)
        .select()
        .eq('is_archived', false)
        .order('name');
    return rows
        .map((row) => formTemplateFromSupabaseJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  @override
  Future<FormTemplateDefinition?> getDefinition(
    String templateId, {
    String? revisionId,
  }) async {
    if (templateId.trim().isEmpty) return null;
    final client = _requireClient();
    final templateRow = await client
        .from(kFormTemplatesTable)
        .select()
        .eq('id', templateId)
        .maybeSingle();
    if (templateRow == null) return null;

    final revisionRow = revisionId?.isNotEmpty == true
        ? await client
            .from(kFormTemplateRevisionsTable)
            .select()
            .eq('id', revisionId!)
            .eq('template_id', templateId)
            .maybeSingle()
        : await client
            .from(kFormTemplateRevisionsTable)
            .select()
            .eq('template_id', templateId)
            .eq('status', TemplateRevisionStatus.published.name)
            .order('revision_number', ascending: false)
            .maybeSingle();
    if (revisionRow == null) return null;

    final revision = formTemplateRevisionFromSupabaseJson(
      Map<String, dynamic>.from(revisionRow),
    );
    final sectionsRows = await client
        .from(kFormTemplateSectionsTable)
        .select()
        .eq('revision_id', revision.id)
        .order('position');
    final fieldsRows = await client
        .from(kFormTemplateFieldsTable)
        .select()
        .eq('revision_id', revision.id)
        .order('position');
    final fields = fieldsRows
        .map(
          (row) => formTemplateFieldFromSupabaseJson(
            Map<String, dynamic>.from(row),
          ),
        )
        .toList(growable: false);
    final fieldIds = fields.map((field) => field.id).toList(growable: false);
    final optionsRows = fieldIds.isEmpty
        ? const <Map<String, dynamic>>[]
        : await client
            .from(kFormTemplateFieldOptionsTable)
            .select()
            .inFilter('field_id', fieldIds)
            .order('position');

    return FormTemplateDefinition(
      template: formTemplateFromSupabaseJson(
        Map<String, dynamic>.from(templateRow),
      ),
      revision: revision,
      sections: sectionsRows.map(
        (row) => formTemplateSectionFromSupabaseJson(
          Map<String, dynamic>.from(row),
        ),
      ),
      fields: fields,
      options: optionsRows.map(
        (row) => formTemplateFieldOptionFromSupabaseJson(
          Map<String, dynamic>.from(row),
        ),
      ),
    );
  }

  SupabaseClient _requireClient() {
    final client = _supabase;
    if (client == null) throw StateError('Supabase has not been initialized.');
    return client;
  }
}

final templateDefinitionRemoteDatasourceProvider =
    Provider<TemplateDefinitionRemoteDatasource>(
  (ref) => TemplateDefinitionRemoteDatasourceImpl(),
);
