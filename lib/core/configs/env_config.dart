// Environment-aware configuration that merges Env + ApiConstants
// into a single object you can read from anywhere.

import 'env.dart';
import '../constants/api_constants.dart';

class EnvConfig {
  final AppEnvironment environment;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final String restBaseUrl;
  final bool enableLogging;
  final bool enableDebugMenus;

  const EnvConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.restBaseUrl,
    required this.enableLogging,
    required this.enableDebugMenus,
  });

  /// Current config based on [Env.current].
  static EnvConfig get current {
    switch (Env.current) {
      case AppEnvironment.dev:
        return EnvConfig(
          environment: AppEnvironment.dev,
          supabaseUrl: ApiConstants.supabaseUrl,
          supabaseAnonKey: ApiConstants.supabaseAnonKey,
          restBaseUrl: ApiConstants.restBaseUrl,
          enableLogging: true,
          enableDebugMenus: true,
        );
      case AppEnvironment.staging:
        return EnvConfig(
          environment: AppEnvironment.staging,
          supabaseUrl: ApiConstants.supabaseUrl,
          supabaseAnonKey: ApiConstants.supabaseAnonKey,
          restBaseUrl: ApiConstants.restBaseUrl,
          enableLogging: true,
          enableDebugMenus: false,
        );
      case AppEnvironment.prod:
        return EnvConfig(
          environment: AppEnvironment.prod,
          supabaseUrl: ApiConstants.supabaseUrl,
          supabaseAnonKey: ApiConstants.supabaseAnonKey,
          restBaseUrl: ApiConstants.restBaseUrl,
          enableLogging: false,
          enableDebugMenus: false,
        );
    }
  }

  bool get isDev => environment == AppEnvironment.dev;
  bool get isStaging => environment == AppEnvironment.staging;
  bool get isProd => environment == AppEnvironment.prod;
}