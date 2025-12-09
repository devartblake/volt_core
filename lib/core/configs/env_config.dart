import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'env.dart';

class EnvConfig {
  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String restBaseUrl;

  final bool enableLogging;
  final bool enableDebugMenus;

  // Optional: observability & meta
  final String? sentryDsn;
  final String? crashlyticsApiKey;
  final String? appIconName;
  final String? bundleId;

  const EnvConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.restBaseUrl,
    required this.enableLogging,
    required this.enableDebugMenus,
    this.sentryDsn,
    this.crashlyticsApiKey,
    this.appIconName,
    this.bundleId,
  });

  /// Helper to pull a value from:
  /// 1) --dart-define
  /// 2) .env
  static String _get(String key, {String defaultValue = ''}) {
    const prefix = ''; // you can add "APP_" if you want to namespace
    final define = String.fromEnvironment('$prefix$key');
    if (define.isNotEmpty) return define;

    return dotenv.env[key] ?? defaultValue;
  }

  /// Environment-aware API base URL
  /// with automatic desktop/mobile/web switching if you want:
  static String _resolveRestBaseUrl() {
    // Prefer platform-specific keys if present
    if (kIsWeb) {
      final web = _get('API_BASE_URL_WEB', defaultValue: '');
      if (web.isNotEmpty) return web;
    } else {
      final mobile = _get('API_BASE_URL_MOBILE', defaultValue: '');
      if (mobile.isNotEmpty) return mobile;
    }

    // Fallback to generic
    return _get('API_BASE_URL', defaultValue: '');
  }

  /// Secure-mode helper:
  /// if USE_SECURE_ENV=true, prefer SECURE_* keys
  static String _secureOr(String plainKey, String secureKey) {
    final useSecure = _get('USE_SECURE_ENV', defaultValue: 'false') == 'true';
    if (useSecure) {
      final secureVal = _get(secureKey, defaultValue: '');
      if (secureVal.isNotEmpty) return secureVal;
    }
    return _get(plainKey, defaultValue: '');
  }

  /// Current config based on [Env.current] + .env + dart-defines.
  static EnvConfig get current {
    final env = Env.current;

    // Supabase URL / key (supports .env.secure pattern)
    final supabaseUrl = _secureOr(
      'SUPABASE_URL',
      'SECURE_SUPABASE_URL',
    );
    final supabaseAnonKey = _secureOr(
      'SUPABASE_ANON_KEY',
      'SECURE_SUPABASE_ANON_KEY',
    );

    final restBaseUrl = _resolveRestBaseUrl();

    // Optional observability & app meta
    final sentryDsn = _get('SENTRY_DSN', defaultValue: '');
    final crashlyticsApiKey = _get('CRASHLYTICS_API_KEY', defaultValue: '');
    final appIconName = _get('APP_ICON_NAME', defaultValue: '');
    final bundleId = _get('BUNDLE_ID', defaultValue: '');

    switch (env) {
      case AppEnvironment.dev:
        return EnvConfig(
          environment: env,
          supabaseUrl: supabaseUrl,
          supabaseAnonKey: supabaseAnonKey,
          restBaseUrl: restBaseUrl,
          enableLogging: true,
          enableDebugMenus: true,
          sentryDsn: sentryDsn.isEmpty ? null : sentryDsn,
          crashlyticsApiKey:
          crashlyticsApiKey.isEmpty ? null : crashlyticsApiKey,
          appIconName: appIconName.isEmpty ? null : appIconName,
          bundleId: bundleId.isEmpty ? null : bundleId,
        );

      case AppEnvironment.staging:
        return EnvConfig(
          environment: env,
          supabaseUrl: supabaseUrl,
          supabaseAnonKey: supabaseAnonKey,
          restBaseUrl: restBaseUrl,
          enableLogging: true,
          enableDebugMenus: false,
          sentryDsn: sentryDsn.isEmpty ? null : sentryDsn,
          crashlyticsApiKey:
          crashlyticsApiKey.isEmpty ? null : crashlyticsApiKey,
          appIconName: appIconName.isEmpty ? null : appIconName,
          bundleId: bundleId.isEmpty ? null : bundleId,
        );

      case AppEnvironment.prod:
        return EnvConfig(
          environment: env,
          supabaseUrl: supabaseUrl,
          supabaseAnonKey: supabaseAnonKey,
          restBaseUrl: restBaseUrl,
          enableLogging: false,
          enableDebugMenus: false,
          sentryDsn: sentryDsn.isEmpty ? null : sentryDsn,
          crashlyticsApiKey:
          crashlyticsApiKey.isEmpty ? null : crashlyticsApiKey,
          appIconName: appIconName.isEmpty ? null : appIconName,
          bundleId: bundleId.isEmpty ? null : bundleId,
        );
    }
  }

  bool get isDev => environment == AppEnvironment.dev;
  bool get isStaging => environment == AppEnvironment.staging;
  bool get isProd => environment == AppEnvironment.prod;
}