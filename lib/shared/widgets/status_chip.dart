import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';
import '../../core/theme/status_colors.dart';

/// Meaning of a status, resolved to theme-aware colours.
enum StatusTone { success, warning, danger, info, neutral }

/// The app's one status pill.
///
/// Foreground, tinted background and outline all derive from one colour, so the
/// label keeps enough contrast in light and dark themes.
///
/// ```dart
/// StatusChip(label: 'Active', tone: StatusTone.success)
/// StatusChip.colored(label: 'Overdue', icon: Icons.warning, foreground: red)
/// ```
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.tone = StatusTone.neutral,
    this.icon,
  })  : _color = null,
        _background = null;

  /// Pill from explicit colours (for legacy palettes). [foreground] is the
  /// text and icon colour; [background] defaults to a tint of it.
  const StatusChip.colored({
    super.key,
    required this.label,
    required Color foreground,
    Color? background,
    this.icon,
  })  : tone = StatusTone.neutral,
        _color = foreground,
        _background = background;

  final String label;
  final StatusTone tone;
  final IconData? icon;
  final Color? _color;
  final Color? _background;

  static Color resolve(BuildContext context, StatusTone tone) {
    final theme = Theme.of(context);
    return switch (tone) {
      StatusTone.success => theme.status.success,
      StatusTone.warning => theme.status.warning,
      StatusTone.danger => theme.colorScheme.error,
      StatusTone.info => theme.status.info,
      StatusTone.neutral => theme.colorScheme.onSurfaceVariant,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = _color ?? resolve(context, tone);
    final bg = _background ?? color.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.pillAll,
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            ExcludeSemantics(child: Icon(icon, size: 14, color: color)),
            const SizedBox(width: AppSpacing.xs),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              // Explicit colour: theme chip text has been near-invisible.
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small icon + text fact (date, location, count).
///
/// Plain by default; [filled] adds a rounded background and [emphasized]
/// strengthens it, for chips that sit in a wrap row.
class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.icon,
    required this.label,
    this.filled = false,
    this.emphasized = false,
    this.maxWidth = 260,
  });

  final IconData icon;
  final String label;
  final bool filled;
  final bool emphasized;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showFill = filled || emphasized;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Icon(icon, size: 14, color: scheme.onSurfaceVariant),
        ),
        SizedBox(width: showFill ? 6 : AppSpacing.xs),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: emphasized ? FontWeight.w600 : null,
              ),
            ),
          ),
        ),
      ],
    );

    if (!showFill) return content;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: emphasized
            ? scheme.primaryContainer.withValues(alpha: 0.5)
            : scheme.surfaceContainerHighest,
        borderRadius: AppRadius.chipAll,
      ),
      child: content,
    );
  }
}
