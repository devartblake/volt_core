import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/form_response_report_artifact.dart';
import 'form_response_report_repository.dart';

class FormResponseReportRepositoryImpl implements FormResponseReportRepository {
  FormResponseReportRepositoryImpl({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static const table = 'form_response_report_artifacts';
  final SupabaseClient _client;

  @override
  Future<FormResponseReportArtifact> create({
    required String responseId,
    required String storagePath,
    required String fileName,
    required int byteSize,
    String mediaType = 'application/pdf',
    String? checksumSha256,
  }) async {
    final row = await _client
        .from(table)
        .insert({
          'id': const Uuid().v4(),
          'response_id': responseId,
          'storage_path': storagePath,
          'file_name': fileName,
          'media_type': mediaType,
          'byte_size': byteSize,
          if (checksumSha256 != null) 'checksum_sha256': checksumSha256,
        })
        .select()
        .single();
    return _fromJson(row);
  }

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
    if (responseId?.isNotEmpty ?? false) query = query.eq('response_id', responseId!);
    if (customerId?.isNotEmpty ?? false) query = query.eq('customer_id', customerId!);
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

final formResponseReportRepositoryProvider = Provider<FormResponseReportRepository>(
  (ref) => FormResponseReportRepositoryImpl(),
);
