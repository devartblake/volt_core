import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shorthand alias for JSON maps.
typedef JsonMap = Map<String, dynamic>;

/// Thin, shared helper around [SupabaseClient] for simple CRUD / RPC.
///
/// This is intentionally generic so that feature modules
/// (inspections, maintenance, equipment, etc.) can:
///
///  - depend on this instead of `Supabase.instance.client`
///  - keep their own mapping logic (Model <→ JsonMap) in infra layer
///
/// Example usage in a feature datasource:
///
/// ```dart
/// final remote = SupabaseRemoteDataSource();
///
/// final rows = await remote.fetchList(
///   table: 'inspections',
///   filterColumn: 'site_id',
///   filterValue: siteId,
///   orderBy: 'created_at',
///   ascending: false,
/// );
/// ```
///
class SupabaseRemoteDataSource {
  final SupabaseClient client;

  SupabaseRemoteDataSource({SupabaseClient? client})
      : client = client ?? Supabase.instance.client;

  /// Fetch a list of rows from [table].
  ///
  /// Supports:
  ///  - optional equality filter (`filterColumn` + `filterValue`)
  ///  - limit / offset
  ///  - simple ordering
  Future<List<JsonMap>> fetchList({
    required String table,
    String? filterColumn,
    dynamic filterValue,
    int? limit,
    int? offset,
    String? orderBy,
    bool ascending = true,
  }) async {
    // Start as a PostgrestFilterBuilder (safe for eq)
    final filter = client.from(table).select();
    // NOTE: use PostgrestTransformBuilder so we can chain eq/order/range safely.
    PostgrestTransformBuilder<dynamic> query = filter;
    // which is a subtype of TransformBuilder

    if (filterColumn != null && filterValue != null) {
      filter.eq(filterColumn, filterValue);
    }

    if (orderBy != null && orderBy.isNotEmpty) {
      query = query.order(orderBy, ascending: ascending);
    }

    if (limit != null) {
      final from = offset ?? 0;
      final to = from + limit - 1;
      query = query.range(from, to);
    }

    try {
      final result = await query;

      if (result is List) {
        return result.cast<JsonMap>();
      }

      if (kDebugMode) {
        debugPrint(
          '[SupabaseRemoteDataSource] fetchList($table) returned non-list: $result',
        );
      }
      return [];
    } on PostgrestException catch (e, st) {
      _logError('fetchList', table, e, st);
      rethrow;
    } catch (e, st) {
      _logError('fetchList', table, e, st);
      rethrow;
    }
  }

  /// Fetch a single row by primary key (defaults to `id`).
  Future<JsonMap?> fetchById({
    required String table,
    required dynamic id,
    String idColumn = 'id',
  }) async {
    try {
      final result = await client
          .from(table)
          .select()
          .eq(idColumn, id)
          .maybeSingle(); // returns null if not found

      if (result == null) return null;
      return result as JsonMap;
    } on PostgrestException catch (e, st) {
      _logError('fetchById', table, e, st);
      rethrow;
    } catch (e, st) {
      _logError('fetchById', table, e, st);
      rethrow;
    }
  }

  /// Insert a **single** row and return the inserted row.
  Future<JsonMap> insertOne({
    required String table,
    required JsonMap data,
  }) async {
    try {
      final result = await client.from(table).insert(data).select().single();
      return result as JsonMap;
    } on PostgrestException catch (e, st) {
      _logError('insertOne', table, e, st);
      rethrow;
    } catch (e, st) {
      _logError('insertOne', table, e, st);
      rethrow;
    }
  }

  /// Update a **single** row by primary key and return the updated row.
  Future<JsonMap> updateById({
    required String table,
    required dynamic id,
    required JsonMap data,
    String idColumn = 'id',
  }) async {
    try {
      final result = await client
          .from(table)
          .update(data)
          .eq(idColumn, id)
          .select()
          .single();
      return result as JsonMap;
    } on PostgrestException catch (e, st) {
      _logError('updateById', table, e, st);
      rethrow;
    } catch (e, st) {
      _logError('updateById', table, e, st);
      rethrow;
    }
  }

  /// Delete a **single** row by primary key.
  Future<bool> deleteById({
    required String table,
    required dynamic id,
    String idColumn = 'id',
  }) async {
    try {
      final result = await client
          .from(table)
          .delete()
          .eq(idColumn, id)
          .select()
          .maybeSingle();

      return result != null;
    } on PostgrestException catch (e, st) {
      _logError('deleteById', table, e, st);
      rethrow;
    } catch (e, st) {
      _logError('deleteById', table, e, st);
      rethrow;
    }
  }

  /// Call a Supabase RPC function that returns a **list**.
  Future<List<JsonMap>> callRpcList(
      String functionName, {
        Map<String, dynamic>? params,
      }) async {
    try {
      final result = await client.rpc(functionName, params: params ?? {});
      if (result is List) {
        return result.cast<JsonMap>();
      }
      if (kDebugMode) {
        debugPrint(
          '[SupabaseRemoteDataSource] callRpcList($functionName) returned non-list: $result',
        );
      }
      return [];
    } on PostgrestException catch (e, st) {
      _logError('callRpcList', functionName, e, st);
      rethrow;
    } catch (e, st) {
      _logError('callRpcList', functionName, e, st);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Internal logging helper
  // ---------------------------------------------------------------------------

  void _logError(
      String operation,
      String target,
      Object error,
      StackTrace stackTrace,
      ) {
    if (!kDebugMode) return;
    debugPrint(
      '[SupabaseRemoteDataSource] $operation failed on "$target": $error\n$stackTrace',
    );
  }
}
