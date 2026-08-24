import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/sync/sync_context.dart';
import '../../domain/entities/tenant_retention_policy.dart';

class TenantRetentionPolicyService {
  TenantRetentionPolicyService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<TenantRetentionPolicy> load() async {
    final tenantId = _requireTenantId();
    final rows = await _client
        .from('tenant_retention_policies')
        .select('tenant_id,archived_maintenance_days,generated_report_days')
        .eq('tenant_id', tenantId)
        .limit(1);

    if (rows.isEmpty) {
      return TenantRetentionPolicy(tenantId: tenantId);
    }

    final row = rows.first;
    return TenantRetentionPolicy(
      tenantId: tenantId,
      archivedMaintenanceDays: row['archived_maintenance_days'] as int?,
      generatedReportDays: row['generated_report_days'] as int?,
    );
  }

  Future<TenantRetentionPolicy> save({
    required int? archivedMaintenanceDays,
    required int? generatedReportDays,
  }) async {
    final tenantId = _requireTenantId();
    final userId = _client.auth.currentUser?.id;
    await _client.from('tenant_retention_policies').upsert({
      'tenant_id': tenantId,
      'archived_maintenance_days': archivedMaintenanceDays,
      'generated_report_days': generatedReportDays,
      'updated_by_user_id': userId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    return TenantRetentionPolicy(
      tenantId: tenantId,
      archivedMaintenanceDays: archivedMaintenanceDays,
      generatedReportDays: generatedReportDays,
    );
  }

  String _requireTenantId() {
    final tenantId = SyncContext.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('No active tenant is configured.');
    }
    return tenantId;
  }
}
