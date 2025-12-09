import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../configs/env_config.dart';

/// Centralized Supabase bootstrap + helpers.
///
/// Usage:
///   1) In main():
///        WidgetsFlutterBinding.ensureInitialized();
///        await SupabaseService.init();
///   2) Access anywhere:
///        final client = SupabaseService.client;
///      or via Riverpod:
///        final client = ref.watch(supabaseClientProvider);
class SupabaseService {
  static bool _initialized = false;

  SupabaseService._(); // private ctor to prevent instantiation

  /// Initialize Supabase using the current environment config.
  ///
  /// Call this once at startup *before* runApp():
  ///
  ///   Future<void> main() async {
  ///     WidgetsFlutterBinding.ensureInitialized();
  ///     await SupabaseService.init();
  ///     runApp(const ProviderScope(child: VoltcoreApp()));
  ///   }
  static Future<void> init() async {
    if (_initialized) return;

    final cfg = EnvConfig.current;

    if (cfg.supabaseUrl.isEmpty || cfg.supabaseAnonKey.isEmpty) {
      throw StateError(
        'Supabase configuration is missing.\n'
            'Check your .env / dart-define for SUPABASE_URL and SUPABASE_ANON_KEY.',
      );
    }

    try {
      await Supabase.initialize(
        url: cfg.supabaseUrl,
        anonKey: cfg.supabaseAnonKey,
      );

      _initialized = true;

      if (cfg.enableLogging && kDebugMode) {
        debugPrint(
          '[SupabaseService] ✅ Initialized\n'
              '  env      = ${cfg.environment}\n'
              '  url      = ${cfg.supabaseUrl}\n'
              '  restBase = ${cfg.restBaseUrl}\n'
              '  bundleId = ${cfg.bundleId ?? '(none)'}',
        );
      }
    } catch (e, st) {
      _initialized = false;
      if (cfg.enableLogging && kDebugMode) {
        debugPrint('[SupabaseService] ❌ Failed to initialize Supabase: $e');
        debugPrint('$st');
      }
      rethrow;
    }
  }

  /// Low-level client access.
  ///
  /// Throws if [init] has not been called.
  static SupabaseClient get client {
    if (!_initialized) {
      throw StateError(
        'SupabaseService.init() must be called before accessing the client.',
      );
    }
    return Supabase.instance.client;
  }

  // ---------------------------------------------------------------------------
  // Auth helpers
  // ---------------------------------------------------------------------------

  /// Email/password sign-in.
  static Future<AuthResponse> signInWithEmailPassword({
    required String email,
    required String password,
  }) {
    return client.auth.signInWithPassword(email: email, password: password);
  }

  /// Sign out the current user.
  static Future<void> signOut() {
    return client.auth.signOut();
  }

  /// Returns the current Supabase user (if any).
  static User? get currentUser => client.auth.currentUser;

  /// Subscribe to auth state changes.
  ///
  /// Example:
  ///   final sub = SupabaseService.onAuthStateChange((event, session) {
  ///     // handle login/logout token refresh, etc
  ///   });
  ///   ...
  ///   await sub.unsubscribe();
  static RealtimeChannel onAuthStateChange(
      void Function(AuthChangeEvent, Session?) handler,
      ) {
    // The RealtimeChannel return here is mostly a logical handle; the actual
    // auth stream is from client.auth.onAuthStateChange.
    final channel = client.channel('public:auth');
    client.auth.onAuthStateChange.listen((data) {
      handler(data.event, data.session);
    });
    return channel;
  }

  // ---------------------------------------------------------------------------
  // Query helpers
  // ---------------------------------------------------------------------------

  /// Convenience helper to get a typed table query builder:
  ///
  ///   final res = await SupabaseService.table('inspections')
  ///       .select()
  ///       .eq('site_id', siteId);
  static SupabaseQueryBuilder table(String name) => client.from(name);

  /// Simple RPC helper.
  ///
  ///   final result = await SupabaseService.rpc('my_fn', params: {...});
  static Future<dynamic> rpc(
      String fn, {
        Map<String, dynamic>? params,
      }) {
    return client.rpc(fn, params: params);
  }

  // ---------------------------------------------------------------------------
  // Realtime helpers
  // ---------------------------------------------------------------------------

  /// Get a realtime channel; the caller can attach handlers.
  ///
  /// Example:
  ///   final channel = SupabaseService.realtimeChannel('public:inspections')
  ///     ..onPostgresChanges(
  ///       event: PostgresChangeEvent.insert,
  ///       schema: 'public',
  ///       table: 'inspections',
  ///       callback: (payload) {
  ///         // handle new row
  ///       },
  ///     )
  ///     ..subscribe();
  static RealtimeChannel realtimeChannel(String topic) {
    return client.channel(topic);
  }
}

// ---------------------------------------------------------------------------
// Riverpod providers
// ---------------------------------------------------------------------------

/// Expose SupabaseClient via Riverpod.
///
/// IMPORTANT: Ensure SupabaseService.init() is called before using this.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return SupabaseService.client;
});

/// Reactive auth session provider (null = signed out).
final supabaseAuthStateProvider = StreamProvider<Session?>((ref) {
  final controller = StreamController<Session?>();

  final sub = SupabaseService.client.auth.onAuthStateChange.listen((data) {
    controller.add(data.session);
  });

  ref.onDispose(() async {
    await sub.cancel();
    await controller.close();
  });

  return controller.stream;
});
