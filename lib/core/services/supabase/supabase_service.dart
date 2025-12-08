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

    await Supabase.initialize(
      url: cfg.supabaseUrl,
      anonKey: cfg.supabaseAnonKey,
    );

    _initialized = true;

    if (cfg.enableLogging && kDebugMode) {
      debugPrint(
        '[SupabaseService] Initialized → env=${cfg.environment} '
            'url=${cfg.supabaseUrl}',
      );
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
  // Auth helpers (simple wrappers; you can expand these later)
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
    // Supabase_flutter uses client.auth.onAuthStateChange; we can wrap it
    final channel = client.channel('public:auth'); // logical name only
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

/// Optional: expose auth session as a stream provider if you want reactive auth.
///
/// Example usage in a widget:
///   final authAsync = ref.watch(supabaseAuthStateProvider);
///   authAsync.when(
///     data: (session) => ...,
///     loading: () => ...,
///     error: (e, st) => ...,
///   );
final supabaseAuthStateProvider = StreamProvider<Session?>((ref) {
  // Supabase Flutter exposes auth state via:
  //   client.auth.onAuthStateChange
  // which yields AuthState objects with (event, session).
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
