import 'package:supabase_flutter/supabase_flutter.dart';

class TenantsRemoteDatasource {
  final SupabaseClient _client;

  TenantsRemoteDatasource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Fetch tenant names for a given user.
  ///
  /// Memberships live on `tenant_members` (the `tenants` table has no
  /// `user_id` column) — join through it to the tenant name.
  Future<List<String>> fetchTenantsForUser(String userId) async {
    final response = await _client
        .from('tenant_members')
        .select('tenants(name)')
        .eq('user_id', userId)
        .eq('is_active', true);

    final list = (response as List).cast<Map<String, dynamic>>();

    return list
        .map((row) =>
            ((row['tenants'] as Map?)?['name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toList();
  }
}
