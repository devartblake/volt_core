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
    this.note,
    this.onNotePressed,
  });

  final String label;
  final IconData icon;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final StatusTileAccent accent;
  final EdgeInsetsGeometry margin;

  /// Conclusion recorded against this item, if any.
  ///
  /// Only used to show whether a note exists — the text itself is edited
  /// through [onNotePressed].
  final String? note;

  /// Shows a note button that calls this. Omit it and no button is rendered,
  /// which is how the tiles that are pure yes/no answers stay uncluttered.
  final VoidCallback? onNotePressed;

  bool get _hasNote => (note ?? '').trim().isNotEmpty;

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
              if (onNotePressed != null) ...[
                _NoteButton(
                  hasNote: _hasNote,
                  label: label,
                  onPressed: onNotePressed!,
                  accentColor: accentColor,
                ),
                const SizedBox(width: 4),
              ],
              _YesNoBadge(value: value, accentColor: accentColor),
              const SizedBox(width: 8),
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

/// Spells out what the switch position means.
///
/// A bare switch only reads as an answer once you know which side is which,
/// and these tiles are filled in on a tablet in a generator room and then
/// audited later by somebody else. The word removes the guess.
class _YesNoBadge extends StatelessWidget {
  const _YesNoBadge({required this.value, required this.accentColor});

  final bool value;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final foreground = value ? accentColor : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: foreground.withValues(alpha: 0.4)),
      ),
      child: Text(
        value ? 'YES' : 'NO',
        style: theme.textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _NoteButton extends StatelessWidget {
  const _NoteButton({
    required this.hasNote,
    required this.label,
    required this.onPressed,
    required this.accentColor,
  });

  final bool hasNote;
  final String label;
  final VoidCallback onPressed;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return IconButton(
      // Distinguishable by touch target as well as colour: an empty note and a
      // written one are different icons, not just different shades.
      icon: Icon(
        hasNote ? Icons.sticky_note_2 : Icons.note_add_outlined,
        size: 20,
        color: hasNote ? accentColor : scheme.onSurfaceVariant,
      ),
      tooltip: hasNote ? 'Edit conclusion for "$label"' : 'Add conclusion for "$label"',
      visualDensity: VisualDensity.compact,
      onPressed: onPressed,
    );
  }
}
