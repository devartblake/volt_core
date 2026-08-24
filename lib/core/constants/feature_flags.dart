/// Compile-time switches for features that are not ready for users.
///
/// A flag here means the implementation may exist in the codebase while its
/// user-facing entry point remains deliberately gated. Flip a pilot flag only
/// after its data, authorization, and rollback boundaries are certified.
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
  /// Kept off until the generator legacy/template parity and field pilot are
  /// certified. Turning this off removes the execution route without changing
  /// existing legacy inspection/maintenance routes, providing a one-switch
  /// rollback path during rollout.
  static const bool generatorTemplatePilotEnabled = false;
}
