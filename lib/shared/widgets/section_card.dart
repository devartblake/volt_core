import 'package:flutter/material.dart';

/// Titled card used to group related fields on a form.
///
/// The inspection and maintenance forms each repeated the same
/// card + tinted-icon + title + subtitle block, with the radius, padding, and
/// icon treatment drifting slightly between sections. This is that block.
///
/// ```dart
/// SectionCard(
///   icon: Icons.verified_user_outlined,
///   title: 'FDNY / DEP',
///   subtitle: 'Permits and registrations',
///   children: [ ...fields ],
/// )
/// ```
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.subtitle,
    this.trailing,
    this.tone,
    this.padding = const EdgeInsets.all(20),
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> children;

  /// Optional widget at the far end of the header (status chip, action…).
  final Widget? trailing;

  /// Container colour for the icon badge. Defaults to the secondary container.
  final Color? tone;

  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              title: title,
              subtitle: subtitle,
              icon: icon,
              tone: tone,
              trailing: trailing,
            ),
            if (children.isNotEmpty) const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Header row for a section: optional tinted icon badge, title, subtitle, and
/// trailing widget. Usable on its own for non-card groupings.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.tone,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final badge = tone ?? scheme.secondaryContainer;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: badge,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 22,
              color: ThemeData.estimateBrightnessForColor(badge) ==
                      Brightness.dark
                  ? Colors.white
                  : scheme.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}
