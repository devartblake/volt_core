import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/sync/sync_context.dart';
import '../../../../core/services/sync/sync_service.dart';
import '../../domain/entities/form_response_report_artifact.dart';
import '../../domain/entities/template_entities.dart';
import 'form_response_repository.dart';
import 'form_response_repository_impl.dart';
import 'form_response_report_repository.dart';

typedef ReportArtifactQueueWriter = Future<void> Function(
  String id,
  Map<String, dynamic> row,
);
typedef ReportArtifactIdFactory = String Function(
  String responseId,
  String storagePath,
);
typedef ReportArtifactClock = DateTime Function();

class FormResponseReportRepositoryImpl implements FormResponseReportRepository {
  FormResponseReportRepositoryImpl({
    SupabaseClient? client,
    FormResponseRepository? responses,
    ReportArtifactQueueWriter? queueWriter,
    ReportArtifactIdFactory? idFactory,
    ReportArtifactClock? clock,
  })  : _client = client ?? Supabase.instance.client,
        _responses = responses ?? FormResponseRepositoryImpl(),
        _queueWriter = queueWriter ?? _enqueueInsert,
        _idFactory = idFactory ?? _stableArtifactId,
        _clock = clock ?? (() => DateTime.now().toUtc());

  static const table = 'form_response_report_artifacts';
  static const _artifactNamespace = 'b2c191c1-173f-4df8-8427-1c5315ca8f9b';

  final SupabaseClient _client;
  final FormResponseRepository _responses;
  final ReportArtifactQueueWriter _queueWriter;
  final ReportArtifactIdFactory _idFactory;
  final ReportArtifactClock _clock;

  static Future<void> _enqueueInsert(
    String id,
    Map<String, dynamic> row,
  ) =>
      SyncService.instance.enqueueInsert(
        table: table,
        id: id,
        payload: row,
      );

  static String _stableArtifactId(String responseId, String storagePath) =>
      const Uuid().v5(_artifactNamespace, '$responseId|$storagePath');

  @override
  Future<FormResponseReportArtifact> create({
    required String responseId,
    required String storagePath,
    required String fileName,
    required int byteSize,
    String mediaType = 'application/pdf',
    String? checksumSha256,
  }) async {
    final response = await _responses.getById(responseId);
    if (response == null) {
      throw StateError(
        'The completed form response is not available in the active tenant.',
      );
    }
    if (!response.isComplete) {
      throw StateError('Reports may only be linked to completed responses.');
    }

    final id = _idFactory(responseId, storagePath);
    final createdAt = _clock();
    final row = <String, dynamic>{
      'id': id,
      'response_id': responseId,
      'storage_path': storagePath,
      'file_name': fileName,
      'media_type': mediaType,
      'byte_size': byteSize,
      if (checksumSha256 != null) 'checksum_sha256': checksumSha256,
    };

    // Queue after the completed response and report upload have already been
    // enqueued. SyncQueue drains oldest-first, so the response normally reaches
    // the trigger before this immutable link. If an earlier dependency fails,
    // this insert remains retryable instead of losing the report relationship.
    await _queueWriter(id, row);

    return _localArtifact(
      id: id,
      response: response,
      storagePath: storagePath,
      fileName: fileName,
      mediaType: mediaType,
      byteSize: byteSize,
      checksumSha256: checksumSha256,
      createdAt: createdAt,
    );
  }

  static FormResponseReportArtifact _localArtifact({
    required String id,
    required FormResponse response,
    required String storagePath,
    required String fileName,
    required String mediaType,
    required int byteSize,
    required DateTime createdAt,
    String? checksumSha256,
  }) =>
      FormResponseReportArtifact(
        id: id,
        tenantId: response.tenantId,
        responseId: response.id,
        templateRevisionId: response.templateRevisionId,
        customerId: response.customerId,
        siteId: response.siteId,
        assetId: response.assetId,
        workOrderId: response.workOrderId,
        inspectionId: response.inspectionId,
        maintenanceRecordId: response.maintenanceRecordId,
        storagePath: storagePath,
        fileName: fileName,
        mediaType: mediaType,
        byteSize: byteSize,
        checksumSha256: checksumSha256,
        createdByUserId: SyncContext.userId,
        createdAt: createdAt,
      );

  @override
  Future<List<FormResponseReportArtifact>> listLinked({
    String? responseId,
    String? customerId,
    String? siteId,
    String? assetId,
    String? workOrderId,
    String? inspectionId,
    String? maintenanceRecordId,
  }) async {
    if ([
      responseId,
      customerId,
      siteId,
      assetId,
      workOrderId,
      inspectionId,
      maintenanceRecordId,
    ].every((value) => value == null || value.isEmpty)) {
      throw ArgumentError('At least one report-link filter is required.');
    }

    var query = _client.from(table).select();
    if (responseId?.isNotEmpty ?? false) {
      query = query.eq('response_id', responseId!);
    }
    if (customerId?.isNotEmpty ?? false) {
      query = query.eq('customer_id', customerId!);
    }
    if (siteId?.isNotEmpty ?? false) query = query.eq('site_id', siteId!);
    if (assetId?.isNotEmpty ?? false) query = query.eq('asset_id', assetId!);
    if (workOrderId?.isNotEmpty ?? false) {
      query = query.eq('work_order_id', workOrderId!);
    }
    if (inspectionId?.isNotEmpty ?? false) {
      query = query.eq('inspection_id', inspectionId!);
    }
    if (maintenanceRecordId?.isNotEmpty ?? false) {
      query = query.eq('maintenance_record_id', maintenanceRecordId!);
    }

    final rows = await query.order('created_at', ascending: false);
    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(_fromJson)
        .toList(growable: false);
  }

  static FormResponseReportArtifact _fromJson(Map<String, dynamic> json) =>
      FormResponseReportArtifact(
        id: json['id'] as String,
        tenantId: json['tenant_id'] as String,
        responseId: json['response_id'] as String,
        templateRevisionId: json['template_revision_id'] as String,
        customerId: json['customer_id'] as String?,
        siteId: json['site_id'] as String?,
        assetId: json['asset_id'] as String?,
        workOrderId: json['work_order_id'] as String?,
        inspectionId: json['inspection_id'] as String?,
        maintenanceRecordId: json['maintenance_record_id'] as String?,
        storagePath: json['storage_path'] as String,
        fileName: json['file_name'] as String,
        mediaType: json['media_type'] as String,
        byteSize: (json['byte_size'] as num).toInt(),
        checksumSha256: json['checksum_sha256'] as String?,
        createdByUserId: json['created_by_user_id'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

final formResponseReportRepositoryProvider =
    Provider<FormResponseReportRepository>((ref) {
  return FormResponseReportRepositoryImpl(
    responses: ref.watch(formResponseRepositoryProvider),
  );
});
