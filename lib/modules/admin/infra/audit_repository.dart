import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/connectivity/connectivity_service.dart';
import '../domain/audit_log.dart';

/// Thrown when the log cannot be read because the device is offline. The page
/// shows "Connect to view the audit log".
class AuditOfflineException implements Exception {
  const AuditOfflineException();

  @override
  String toString() => 'Connect to view the audit log';
}

/// Reads the audit log. Online only: the log is never copied to the device.
abstract class AuditRepository {
  /// The newest [limit] entries, newest first.
  Future<List<AuditEntry>> latest(int limit);
}

class SupabaseAuditRepository implements AuditRepository {
  const SupabaseAuditRepository();

  @override
  Future<List<AuditEntry>> latest(int limit) async {
    if (!await ConnectivityService.instance.isOnline()) {
      throw const AuditOfflineException();
    }
    final rows = await Supabase.instance.client
        .from('audit_log')
        .select()
        .order('changed_at', ascending: false)
        .limit(limit);
    return [
      for (final r in rows)
        if (AuditEntry.fromJson(Map<String, dynamic>.from(r as Map)) case final e?)
          e,
    ];
  }
}

final auditRepositoryProvider =
    Provider<AuditRepository>((ref) => const SupabaseAuditRepository());

/// Entries per page, and how many more "Show more" asks for.
const int kAuditPageSize = 200;

/// The newest `limit` entries.
final auditEntriesProvider =
    FutureProvider.autoDispose.family<List<AuditEntry>, int>(
  (ref, limit) => ref.watch(auditRepositoryProvider).latest(limit),
  // Riverpod retries a failed provider by default; the page has its own Retry.
  retry: (_, __) => null,
);
