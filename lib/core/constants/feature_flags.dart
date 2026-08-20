/// Compile-time switches for features that are not ready for users.
///
/// A flag here means the screen exists in the codebase but is deliberately
/// unreachable: no route, no navigation entry. Flip one to `true` only once the
/// feature is backed by real data.
class FeatureFlags {
  const FeatureFlags._();

  /// Equipment Search (`/equipment/search`).
  ///
  /// Enabled: `equipmentListProvider` is backed by `EquipmentRepository`, which
  /// derives the registry from the local inspection history (one entry per
  /// physical generator, grouped by serial number). It was previously hidden
  /// because the screen ran on hardcoded sample records.
  static const bool equipmentSearchEnabled = true;
}
