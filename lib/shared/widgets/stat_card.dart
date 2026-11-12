import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

/// Metric tile: tinted icon, big value, label and optional caption.
///
/// Replaces the private `_StatCard`s. Set [onTap] to make it a link-through
/// (shows a chevron and ripple). [compact] gives the centred, narrow variant
/// used in summary rows.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
    this.color,
    this.onTap,
    this.compact = false,
    this.horizontal = false,
    this.footer,
    this.footerSemantics,
  }) : tile = false;

  /// Dense tile for fixed-height grid cells: label top-left, icon top-right,
  /// value (in the accent colour) along the bottom.
  const StatCard.tile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color,
    this.onTap,
  })  : subtitle = null,
        footer = null,
        footerSemantics = null,
        compact = false,
        horizontal = false,
        tile = true;

  final IconData icon;
  final String label;
  final String value;
  final String? subtitle;

  /// Accent for the icon badge. Defaults to the theme primary.
  final Color? color;
  final VoidCallback? onTap;
  final bool compact;

  /// Icon on the left, label and value stacked beside it. For wrap rows of
  /// fixed-width tiles rather than grids.
  final bool horizontal;

  /// Optional widget under the label in the compact variant (e.g. a trend
  /// sparkline). Part of the card's semantics via its own label.
  final Widget? footer;

  /// Read out with the card (the card's semantics replace its children's).
  final String? footerSemantics;

  /// Set by [StatCard.tile].
  final bool tile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = color ?? scheme.primary;

    final badge = Container(
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(compact ? 20 : 10),
      ),
      child: Icon(icon, color: accent, size: compact ? 20 : 22),
    );

    final valueText = Text(
      value,
      style: (compact
              ? theme.textTheme.titleLarge
              : theme.textTheme.headlineSmall)
          ?.copyWith(fontWeight: FontWeight.w700),
    );
    final labelText = Text(
      label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: compact && !horizontal ? TextAlign.center : TextAlign.start,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: scheme.onSurfaceVariant,
        fontWeight: FontWeight.w500,
      ),
    );

    if (tile) return _buildTile(context, accent);

    final body = horizontal
        ? Row(
            children: [
              badge,
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [labelText, valueText],
                ),
              ),
            ],
          )
        : compact
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              badge,
              const SizedBox(height: AppSpacing.sm),
              valueText,
              labelText,
              if (footer != null) ...[
                const SizedBox(height: AppSpacing.sm),
                footer!,
              ],
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  badge,
                  if (onTap != null)
                    ExcludeSemantics(
                      child: Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              valueText,
              labelText,
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
            ],
          );

    return Semantics(
      container: true,
      button: onTap != null,
      label: '$label: $value${subtitle == null ? '' : ', $subtitle'}'
          '${footerSemantics == null ? '' : '. $footerSemantics'}',
      excludeSemantics: true,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.cardAll,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(
              compact || horizontal ? AppSpacing.lg : AppSpacing.xl,
            ),
            child: body,
          ),
        ),
      ),
    );
  }

  Widget _buildTile(BuildContext context, Color accent) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      container: true,
      button: onTap != null,
      label: '$label: $value',
      excludeSemantics: true,
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.field),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    Icon(icon, color: accent, size: 20),
                  ],
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
