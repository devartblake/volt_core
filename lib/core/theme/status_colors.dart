import 'package:flutter/material.dart';

/// Semantic status colours that Material 3's [ColorScheme] doesn't define.
///
/// The app expresses compliance state constantly — passed/failed checks, site
/// grades, sync health, overdue work — and did it with raw `Colors.green` /
/// `Colors.orange` / `Colors.red`. Those don't adapt to dark mode (mid-tone
/// green on a dark surface fails contrast) and can't be rebranded.
///
/// Access via the [StatusColorsX] extension:
///
/// ```dart
/// final status = Theme.of(context).status;
/// Icon(Icons.check_circle, color: status.success);
/// ```
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.success,
    required this.onSuccess,
    required this.successContainer,
    required this.warning,
    required this.onWarning,
    required this.warningContainer,
    required this.info,
    required this.infoContainer,
  });

  /// Completed, passing, compliant.
  final Color success;
  final Color onSuccess;
  final Color successContainer;

  /// Needs attention, overdue, deficiency noted — not yet a failure.
  final Color warning;
  final Color onWarning;
  final Color warningContainer;

  /// Neutral emphasis (counts, informational chips).
  final Color info;
  final Color infoContainer;

  /// Light-theme values. Deliberately darker than the raw Material swatches so
  /// they pass contrast against light surfaces.
  static const StatusColors light = StatusColors(
    success: Color(0xFF1B7A3E),
    onSuccess: Color(0xFFFFFFFF),
    successContainer: Color(0xFFD7F2E1),
    warning: Color(0xFF9A5B00),
    onWarning: Color(0xFFFFFFFF),
    warningContainer: Color(0xFFFFE7C7),
    info: Color(0xFF1B5E9A),
    infoContainer: Color(0xFFD6E9FA),
  );

  /// Dark-theme values: lighter foregrounds, deep low-chroma containers.
  static const StatusColors dark = StatusColors(
    success: Color(0xFF6FD79A),
    onSuccess: Color(0xFF00391B),
    successContainer: Color(0xFF14512D),
    warning: Color(0xFFFFB95C),
    onWarning: Color(0xFF3D2600),
    warningContainer: Color(0xFF6B3F00),
    info: Color(0xFF8DC4F0),
    infoContainer: Color(0xFF1B3D5C),
  );

  /// Colour for an inspection site grade ('Green' / 'Amber' / 'Red').
  ///
  /// Grades arrive as free-text strings from the form, so anything
  /// unrecognised falls back to [fallback].
  Color forSiteGrade(String grade, {required Color fallback, Color? red}) {
    switch (grade.trim().toLowerCase()) {
      case 'green':
        return success;
      case 'amber':
      case 'yellow':
        return warning;
      case 'red':
        return red ?? warning;
      default:
        return fallback;
    }
  }

  @override
  StatusColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? successContainer,
    Color? warning,
    Color? onWarning,
    Color? warningContainer,
    Color? info,
    Color? infoContainer,
  }) {
    return StatusColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      warningContainer: warningContainer ?? this.warningContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
    );
  }

  @override
  StatusColors lerp(ThemeExtension<StatusColors>? other, double t) {
    if (other is! StatusColors) return this;
    return StatusColors(
      success: Color.lerp(success, other.success, t)!,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t)!,
      successContainer:
          Color.lerp(successContainer, other.successContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      onWarning: Color.lerp(onWarning, other.onWarning, t)!,
      warningContainer:
          Color.lerp(warningContainer, other.warningContainer, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
    );
  }
}

/// `Theme.of(context).status.success`
extension StatusColorsX on ThemeData {
  StatusColors get status => extension<StatusColors>() ?? StatusColors.light;
}
