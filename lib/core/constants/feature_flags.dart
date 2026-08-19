/// Compile-time switches for features that are not ready for users.
///
/// A flag here means the screen exists in the codebase but is deliberately
/// unreachable: no route, no navigation entry. Flip one to `true` only once the
/// feature is backed by real data.
class FeatureFlags {
  const FeatureFlags._();

  /// Equipment Search (`/equipment/search`).
  ///
  /// The UI is complete, but `equipmentListProvider` still returns hardcoded
  /// sample records ("Generator Unit A1", …) and its rows link to nameplate ids
  /// that don't exist. Showing invented equipment in a compliance tool is worse
  /// than showing nothing, so the screen stays hidden until it reads real data.
  ///
  /// To enable: back `equipmentListProvider` with the nameplate/inspection data
  /// (or a Supabase `equipment` table), then set this to `true`.
  static const bool equipmentSearchEnabled = false;
}
