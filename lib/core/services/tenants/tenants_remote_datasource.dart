import 'package:supabase_flutter/supabase_flutter.dart';

class TenantsRemoteDatasource {
  final SupabaseClient _client;

  TenantsRemoteDatasource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Fetch tenant names for a given user.
  ///
  /// Adjust table/column names to match your schema.
  Future<List<String>> fetchTenantsForUser(String userId) async {
    final response = await _client
        .from('tenants')
        .select('name')
        .eq('user_id', userId);

    final list = (response as List).cast<Map<String, dynamic>>();

    return list
        .map((row) => (row['name'] ?? '').toString())
        .where((name) => name.isNotEmpty)
        .toList();
  }
}
