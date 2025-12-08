// Simple environment helper.
// You can later hook this into separate flavors or .env files.

import 'package:flutter/foundation.dart';

enum AppEnvironment {
  dev,
  staging,
  prod,
}

class Env {
  /// Current environment – for now we derive it from build mode.
  static AppEnvironment get current {
    if (kReleaseMode) return AppEnvironment.prod;
    // You could use const String.fromEnvironment('ENV') here instead.
    return AppEnvironment.dev;
  }

  static bool get isDev => current == AppEnvironment.dev;
  static bool get isStaging => current == AppEnvironment.staging;
  static bool get isProd => current == AppEnvironment.prod;
}
