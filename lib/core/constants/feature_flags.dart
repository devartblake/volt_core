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
}
