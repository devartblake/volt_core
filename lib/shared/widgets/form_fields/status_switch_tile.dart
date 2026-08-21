import 'package:flutter/material.dart';

/// Which semantic accent a [StatusSwitchTile] uses when switched on.
enum StatusTileAccent {
  /// Switching this on is normal/good — records kept, area clear.
  primary,

  /// Switching this on flags something — emergency-only operation.
  error,
}

/// A switch row that tints itself when on, used across the inspection form.
///
/// Four sections each carried a byte-identical copy of this: a `Container`
/// with a `BoxDecoration` wrapping a [SwitchListTile]. That nesting is what
/// Flutter's "ListTile background color or ink splashes may be invisible"
/// assertion fires on — `ListTile` paints its ink on the nearest [Material]
/// ancestor, which sat *above* the `DecoratedBox`, so every tap's ripple was
/// painted underneath the tile's own background and never seen.
///
/// The fill and border live on a [Material] here instead of a `DecoratedBox`,
/// which is the framework's prescribed fix: the tile now has a Material
/// between it and the decoration, so ink lands on top of the fill.
class StatusSwitchTile extends StatelessWidget {
  const StatusSwitchTile({
    super.key,
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    this.accent = StatusTileAccent.primary,
    this.margin = EdgeInsets.zero,
  });

  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final StatusTileAccent accent;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final accentColor =
        accent == StatusTileAccent.error ? scheme.error : scheme.primary;
    final accentContainer = accent == StatusTileAccent.error
        ? scheme.errorContainer
        : scheme.primaryContainer;

    final radius = BorderRadius.circular(12);

    return Padding(
      padding: margin,
      child: Material(
        color: value
            ? accentContainer.withValues(alpha: 0.3)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: value
                ? accentColor.withValues(alpha: 0.5)
                : scheme.outlineVariant,
          ),
        ),
        // Keeps the ripple inside the rounded border rather than squaring off
        // the corners on tap.
        clipBehavior: Clip.antiAlias,
        child: SwitchListTile(
          title: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: value ? accentColor : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label)),
            ],
          ),
          value: value,
          onChanged: onChanged,
          // No side here: the border is drawn once, by the Material above.
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
    );
  }
}
