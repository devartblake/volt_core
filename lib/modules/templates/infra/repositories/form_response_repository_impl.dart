import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../../core/services/sync/sync_context.dart';
import '../../../../core/services/sync/sync_service.dart';
import '../../domain/entities/template_entities.dart';
import '../datasources/form_responses_box.dart';
import '../mappers/template_supabase_mapper.dart';
import '../models/form_response_record.dart';
import 'form_response_repository.dart';

typedef FormResponseQueueWriter = Future<void> Function(FormResponse response);
typedef FormResponseTenantIdReader = String? Function();

/// Generic responses are always persisted locally first and queued for sync.
class FormResponseRepositoryImpl implements FormResponseRepository {
  FormResponseRepositoryImpl({
    Box<FormResponseRecord>? box,
    FormResponseQueueWriter? queueWriter,
    FormResponseTenantIdReader? tenantIdReader,
  }) : _injectedBox = box,
       _queueWriter = queueWriter ?? _enqueueToSync,
       _tenantIdReader = tenantIdReader ?? _readActiveTenantId;

  final Box<FormResponseRecord>? _injectedBox;
  final FormResponseQueueWriter _queueWriter;
  final FormResponseTenantIdReader _tenantIdReader;

  Box<FormResponseRecord> get _box => _injectedBox ?? FormResponsesBox.box;

  static String? _readActiveTenantId() => SyncContext.tenantId;

  static Future<void> _enqueueToSync(FormResponse response) =>
      SyncService.instance.enqueueUpsert(
        table: kFormResponsesTable,
        id: response.id,
        payload: formResponseToSupabaseJson(response),
      );

  static FormResponse _toEntity(FormResponseRecord value) => FormResponse(
    id: value.id,
    tenantId: value.tenantId,
    templateId: value.templateId,
    templateRevisionId: value.templateRevisionId,
    status: _statusFromStorage(value.status),
    subjectType: value.subjectType,
    subjectId: value.subjectId,
    customerId: value.customerId,
    siteId: value.siteId,
    assetId: value.assetId,
    workOrderId: value.workOrderId,
    inspectionId: value.inspectionId,
    maintenanceRecordId: value.maintenanceRecordId,
    values: value.values,
    completedAt: value.completedAt,
    completedByUserId: value.completedByUserId,
    createdAt: value.createdAt,
    updatedAt: value.updatedAt,
  );

  static FormResponseRecord _toRecord(FormResponse value) => FormResponseRecord(
    id: value.id,
    tenantId: value.tenantId,
    templateId: value.templateId,
    templateRevisionId: value.templateRevisionId,
    status: value.status.name,
    subjectType: value.subjectType,
    subjectId: value.subjectId,
    customerId: value.customerId,
    siteId: value.siteId,
    assetId: value.assetId,
    workOrderId: value.workOrderId,
    inspectionId: value.inspectionId,
    maintenanceRecordId: value.maintenanceRecordId,
    values: value.values,
    completedAt: value.completedAt,
    completedByUserId: value.completedByUserId,
    createdAt: value.createdAt,
    updatedAt: value.updatedAt,
  );

  @override
  Future<List<FormResponse>> list() async {
    final tenantId = _tenantIdReader();
    final responses = _box.values
        .map(_toEntity)
        .where((item) => tenantId == null || item.tenantId == tenantId)
        .toList(growable: false)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return responses;
  }

  @override
  Future<FormResponse?> getById(String id) async {
    final value = _box.get(id);
    if (value == null || value.tenantId != _tenantIdReader()) return null;
    return _toEntity(value);
  }

  @override
  Future<FormResponse> save(FormResponse response) async {
    if (response.tenantId != _tenantIdReader()) {
      throw StateError('Form responses can only be saved in the active tenant.');
    }
    final existing = _box.get(response.id);
    if (existing != null) {
      final previous = _toEntity(existing);
      if (previous.status == TemplateResponseStatus.completed) {
        throw StateError('Completed form responses are immutable.');
      }
      if (previous.templateId != response.templateId ||
          previous.templateRevisionId != response.templateRevisionId) {
        throw StateError(
          'A response cannot be moved to another template revision.',
        );
      }
    }
    final updated = FormResponse(
      id: response.id,
      tenantId: response.tenantId,
      templateId: response.templateId,
      templateRevisionId: response.templateRevisionId,
      status: response.status,
      subjectType: response.subjectType,
      subjectId: response.subjectId,
      customerId: response.customerId,
      siteId: response.siteId,
      assetId: response.assetId,
      workOrderId: response.workOrderId,
      inspectionId: response.inspectionId,
      maintenanceRecordId: response.maintenanceRecordId,
      values: response.values,
      completedAt: response.completedAt,
      completedByUserId: response.completedByUserId,
      createdAt: response.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    await _box.put(updated.id, _toRecord(updated));
    await _queueWriter(updated);
    return updated;
  }
}

TemplateResponseStatus _statusFromStorage(String value) =>
    TemplateResponseStatus.values.byName(value);

final formResponseRepositoryProvider = Provider<FormResponseRepository>((ref) {
  return FormResponseRepositoryImpl();
});
