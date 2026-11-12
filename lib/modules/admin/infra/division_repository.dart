import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/connectivity/connectivity_service.dart';
import '../../../core/services/sync/sync_context.dart';
import '../domain/division.dart';

/// Shown when divisions are needed and the device has no connection.
const String kDivisionsOfflineMessage =
    'Connect to the internet to manage divisions.';

class DivisionsOfflineException implements Exception {
  const DivisionsOfflineException();

  @override
  String toString() => kDivisionsOfflineMessage;
}

/// A division with that name already exists (names are unique per company,
/// ignoring case).
class DivisionNameTakenException implements Exception {
  const DivisionNameTakenException();

  @override
  String toString() => 'A division with that name already exists.';
}

/// The company's divisions. Online only, like the audit log: the list is small,
/// edited by admins, and read from the cloud each time.
abstract class DivisionRepository {
  /// Every division, active or not, in display order.
  Future<List<Division>> list();

  Future<Division> add(String name);

  Future<void> rename(String id, String name);

  Future<void> setActive(String id, bool isActive);

  /// Writes `sort_order` as the position in [ordered].
  Future<void> reorder(List<Division> ordered);
}

class SupabaseDivisionRepository implements DivisionRepository {
  const SupabaseDivisionRepository();

  static const String table = 'divisions';
  static const String _columns = 'id,name,sort_order,is_active';

  SupabaseClient get _client => Supabase.instance.client;

  Future<String> _tenant() async {
    if (!await ConnectivityService.instance.isOnline()) {
      throw const DivisionsOfflineException();
    }
    final tenantId = SyncContext.tenantId;
    if (tenantId == null || tenantId.isEmpty) {
      throw StateError('No active tenant is configured.');
    }
    return tenantId;
  }

  @override
  Future<List<Division>> list() async {
    final tenantId = await _tenant();
    final rows = await _client
        .from(table)
        .select(_columns)
        .eq('tenant_id', tenantId)
        .order('sort_order')
        .order('name');
    return sortedDivisions([
      for (final r in rows)
        if (Division.fromJson(Map<String, dynamic>.from(r as Map))
            case final d?)
          d,
    ]);
  }

  Never _rethrow(Object error) {
    if (error is PostgrestException && error.code == '23505') {
      throw const DivisionNameTakenException();
    }
    throw error;
  }

  @override
  Future<Division> add(String name) async {
    final tenantId = await _tenant();
    try {
      final existing = await list();
      final next = existing.isEmpty
          ? 0
          : existing
                  .map((d) => d.sortOrder)
                  .reduce((a, b) => a > b ? a : b) +
              1;
      final row = await _client
          .from(table)
          .insert({
            'tenant_id': tenantId,
            'name': name.trim(),
            'sort_order': next,
          })
          .select(_columns)
          .single();
      return Division.fromJson(Map<String, dynamic>.from(row))!;
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> rename(String id, String name) async {
    await _tenant();
    try {
      await _client.from(table).update({'name': name.trim()}).eq('id', id);
    } catch (e) {
      _rethrow(e);
    }
  }

  @override
  Future<void> setActive(String id, bool isActive) async {
    await _tenant();
    await _client.from(table).update({'is_active': isActive}).eq('id', id);
  }

  @override
  Future<void> reorder(List<Division> ordered) async {
    await _tenant();
    for (var i = 0; i < ordered.length; i++) {
      if (ordered[i].sortOrder == i) continue;
      await _client
          .from(table)
          .update({'sort_order': i}).eq('id', ordered[i].id);
    }
  }
}

final divisionRepositoryProvider =
    Provider<DivisionRepository>((ref) => const SupabaseDivisionRepository());

/// All divisions (active and inactive). Errors surface to the page, which shows
/// "Connect to ..." when offline.
final divisionsProvider = FutureProvider.autoDispose<List<Division>>(
  (ref) => ref.watch(divisionRepositoryProvider).list(),
  // The page has its own Retry; do not retry silently.
  retry: (_, __) => null,
);

/// The signed-in user's own division names (admin-arranged order), empty when
/// none are set or they cannot be read (offline, signed out, migration not run
/// yet). Never throws: it only decorates the Settings account card.
final myDivisionNamesProvider =
    FutureProvider.autoDispose<List<String>>((ref) async {
  try {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    final tenantId = SyncContext.tenantId;
    if (userId == null || tenantId == null) return const [];
    final rows = await client
        .from('member_divisions')
        .select('division_id, divisions(name, sort_order)')
        .eq('tenant_id', tenantId)
        .eq('user_id', userId)
        .timeout(const Duration(seconds: 8));
    var found = _divisionNamesFromRows(rows);
    if (found.isEmpty) {
      // Deprecated single column: fallback for people with no rows yet.
      final row = await client
          .from('tenant_members')
          .select('division_id, divisions(name, sort_order)')
          .eq('tenant_id', tenantId)
          .eq('user_id', userId)
          .maybeSingle()
          .timeout(const Duration(seconds: 8));
      if (row != null) found = _divisionNamesFromRows([row]);
    }
    return found;
  } catch (_) {
    return const [];
  }
});

List<String> _divisionNamesFromRows(List<dynamic> rows) {
  final named = <(int, String)>[];
  for (final r in rows) {
    final d = r is Map ? r['divisions'] : null;
    if (d is! Map) continue;
    final name = d['name']?.toString().trim() ?? '';
    if (name.isEmpty) continue;
    final order = d['sort_order'];
    named.add((order is num ? order.toInt() : 0, name));
  }
  named.sort((a, b) {
    final c = a.$1.compareTo(b.$1);
    return c != 0 ? c : a.$2.toLowerCase().compareTo(b.$2.toLowerCase());
  });
  return [for (final n in named) n.$2];
}
