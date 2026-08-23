import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/template_entities.dart';
import '../datasources/template_management_remote_datasource.dart';
import 'template_management_repository.dart';

class TemplateManagementRepositoryImpl implements TemplateManagementRepository {
  TemplateManagementRepositoryImpl({
    required TemplateManagementRemoteDatasource remote,
  }) : _remote = remote;

  final TemplateManagementRemoteDatasource _remote;

  @override
  Future<List<FormTemplateRevision>> listRevisions(String templateId) =>
      _remote.listRevisions(templateId);

  @override
  Future<void> saveDraft(FormTemplateDefinition definition) =>
      _remote.saveDraft(definition);

  @override
  Future<void> publish(String revisionId) => _remote.publish(revisionId);

  @override
  Future<void> archive(String revisionId) => _remote.archive(revisionId);
}

final templateManagementRepositoryProvider = Provider<TemplateManagementRepository>(
  (ref) => TemplateManagementRepositoryImpl(
    remote: ref.watch(templateManagementRemoteDatasourceProvider),
  ),
);
