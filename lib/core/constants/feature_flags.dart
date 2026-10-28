import 'package:flutter/foundation.dart' show kReleaseMode;

/// Compile-time switches for features that are not ready for users.
///
/// A flag here means the implementation may exist in the codebase while its
/// user-facing entry point remains deliberately gated. Pilot flags default to
/// their safest production value and may be enabled for a specific build with
/// `--dart-define` without changing source code.
class FeatureFlags {
  const FeatureFlags._();

  /// Equipment Search (`/equipment/search`).
  ///
  /// Enabled: `equipmentListProvider` is backed by `EquipmentRepository`, which
  /// derives the registry from the local inspection history (one entry per
  /// physical generator, grouped by serial number).
  static const bool equipmentSearchEnabled = true;

  /// Phase 3 technician template-runtime pilot.
  ///
  /// Defaults OFF. Enable only for a certified pilot build with:
  /// `--dart-define=VOLTCORE_GENERATOR_TEMPLATE_PILOT=true`.
  ///
  /// Returning this define to false removes the execution route and pilot entry
  /// point while leaving the legacy inspection/maintenance workflows intact.
  static const bool generatorTemplatePilotEnabled = bool.fromEnvironment(
    'VOLTCORE_GENERATOR_TEMPLATE_PILOT',
    defaultValue: false,
  );

  /// TEMPORARY: lets the login page sign in as any role without credentials.
  ///
  /// On by default in debug/profile builds and OFF in release builds. For a
  /// release APK it must be requested explicitly:
  /// `--dart-define=VOLTCORE_DEV_LOGIN_BYPASS=true` (and `=false` turns it off
  /// in debug). The session is local only, with no Supabase identity, so cloud
  /// sync and anything behind row-level security will not work while bypassed.
  /// Remove this flag once real login is dependable.
  static const bool devLoginBypassEnabled = bool.fromEnvironment(
    'VOLTCORE_DEV_LOGIN_BYPASS',
    defaultValue: !kReleaseMode,
  );
}
