import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// Simple singleton wrapper around Supabase.
///
/// Later, each feature's data_source can depend on [VoltcoreSupabase]
/// instead of talking to Supabase directly.
class VoltcoreSupabase {
  VoltcoreSupabase._internal(this.client);

  final SupabaseClient client;

  static VoltcoreSupabase? _instance;

  static VoltcoreSupabase get I {
    final instance = _instance;
    if (instance == null) {
      throw StateError(
        'VoltcoreSupabase has not been initialized. '
            'Call VoltcoreSupabase.init(url, anonKey) first.',
      );
    }
    return instance;
  }

  /// Initialize Supabase once at app startup.
  static Future<void> init({
    required String url,
    required String anonKey,
  }) async {
    if (kDebugMode) {
      debugPrint('Initializing Supabase...');
    }

    await Supabase.initialize(url: url, anonKey: anonKey);
    _instance = VoltcoreSupabase._internal(Supabase.instance.client);
  }
}