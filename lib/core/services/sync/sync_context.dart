import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Ambient context the sync serializers need to produce schema-compliant rows:
/// the active tenant and the current auth user.
///
/// The Supabase schema keys every row by `tenant_id` (multi-tenant RLS), so the
/// app must stamp each synced row with a tenant. There is no per-device tenant
/// picker wired to a real UUID yet, so the active tenant is read from the env
/// file (`SUPABASE_TENANT_ID`). Set it to the UUID created by the schema
/// bootstrap (`insert into public.tenants ... returning id`).
class SyncContext {
  const SyncContext._();

  /// Active tenant UUID, or null if not configured. When null, serializers omit
  /// `tenant_id` and the server's NOT NULL / RLS checks will reject the write —
  /// configure `SUPABASE_TENANT_ID` to enable cloud sync.
  static String? get tenantId {
    final v = (dotenv.env['SUPABASE_TENANT_ID'] ?? '').trim();
    return v.isEmpty ? null : v;
  }

  /// Current authenticated Supabase user id, if a session exists.
  static String? get userId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return null;
    }
  }

  /// True when a tenant is configured. Handy for debug logging.
  static bool get hasTenant {
    final ok = tenantId != null;
    if (!ok && kDebugMode) {
      debugPrint('[SyncContext] SUPABASE_TENANT_ID not set — cloud sync rows '
          'will be rejected until it is configured.');
    }
    return ok;
  }
}
