import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum AppEnvironment { dev, staging, prod }

class Env {
  /// Detect current environment
  static AppEnvironment get current {
    if (kReleaseMode) return AppEnvironment.prod;

    // You can also switch using --dart-define ENV=staging
    const override = const String.fromEnvironment('ENV');
    switch (override) {
      case 'staging':
        return AppEnvironment.staging;
      case 'prod':
        return AppEnvironment.prod;
      default:
        return AppEnvironment.dev;
    }
  }

  static bool get isDev => current == AppEnvironment.dev;
  static bool get isStaging => current == AppEnvironment.staging;
  static bool get isProd => current == AppEnvironment.prod;

  /// Map environment → .env filename
  ///
  /// Files should be in project root or assets/ folder.
  /// Make sure they're registered in pubspec.yaml under assets:
  static String get filename {
    switch (current) {
      case AppEnvironment.dev:
        return "assets/env/.env.dev";
      case AppEnvironment.staging:
        return "assets/env/.env.staging";
      case AppEnvironment.prod:
        return "assets/env/.env.prod";
    }
  }

  /// Call this during app startup
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: filename);
      if (kDebugMode) {
        debugPrint('[Env] Loaded $filename successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Env] Failed to load $filename: $e');
        debugPrint('[Env] Make sure the file exists and is listed in pubspec.yaml assets');
      }
      rethrow;
    }
  }
}