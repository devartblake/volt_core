import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/status_chip.dart';
import '../domain/material_item.dart';
import '../domain/profile_change.dart';
import 'materials_editor.dart' show formatMaterialDate;

/// "May 3, 2026 14:05" style stamp for requests.
String formatRequestTime(DateTime t) {
  final l = t.toLocal();
  final hh = l.hour.toString().padLeft(2, '0');
  final mm = l.minute.toString().padLeft(2, '0');
  return '${formatMaterialDate(l)} $hh:$mm';
}

String _roleLabel(String wire) {
  final r = MaterialRole.fromWire(wire);
  return r == MaterialRole.none ? 'none' : r.label.toLowerCase();
}

String _valueText(String field, String v) {
  if (v.isEmpty) return 'empty';
  if (field == 'role') return _roleLabel(v);
  if (field == 'dateUsed') {
    final d = DateTime.tryParse(v);
    return d == null ? v : formatMaterialDate(d);
  }
  return v;
}

/// "Fleetguard LF3000 (x2)" - what a part is, for a line of a diff.
String describeItem(MaterialItem i) {
  final bits = [
    if (i.partNumber.trim().isNotEmpty) i.partNumber.trim(),
    if (i.partName.trim().isNotEmpty) i.partName.trim(),
    if (i.manufacturer.trim().isNotEmpty) i.manufacturer.trim(),
  ];
  final base = bits.isEmpty ? 'Unnamed part' : bits.join(' · ');
  return i.quantity == 1 ? base : '$base (x${i.quantity})';
}

/// One change in a request: what is added, changed (old to new) or removed,
/// with a note when the profile has moved on since. [selected] / [onSelected]
/// add a checkbox for reviewers choosing which changes to apply.
class ProfileChangeTile extends StatelessWidget {
  const ProfileChangeTile({
    super.key,
    required this.change,
    this.state = ChangeState.ok,
    this.selected,
    this.onSelected,
  });

  final ProfileItemChange change;
  final ChangeState state;
  final bool? selected;
  final ValueChanged<bool>? onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final (label, tone, icon) = switch (change.kind) {
      ProfileChangeKind.add => ('Add', StatusTone.success, Icons.add_circle_outline),
      ProfileChangeKind.update => ('Change', StatusTone.info, Icons.edit_outlined),
      ProfileChangeKind.remove =>
        ('Remove', StatusTone.danger, Icons.remove_circle_outline),
    };

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusChip(label: label, tone: tone, icon: icon),
            Text(change.slot.label,
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: scheme.onSurfaceVariant)),
            if (state == ChangeState.stale)
              const StatusChip(
                label: 'Changed since proposed',
                tone: StatusTone.warning,
                icon: Icons.warning_amber_outlined,
              ),
            if (state == ChangeState.alreadyApplied)
              const StatusChip(
                label: 'Already done',
                tone: StatusTone.neutral,
                icon: Icons.check,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (change.kind == ProfileChangeKind.update) ...[
          Text(describeItem(change.item),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          for (final f in change.fields)
            Text(
              '${profileFieldLabel(f.field)}: '
              '${_valueText(f.field, f.from)} → ${_valueText(f.field, f.to)}',
              style: theme.textTheme.bodyMedium,
            ),
        ] else ...[
          Text(describeItem(change.item),
              style: theme.textTheme.bodyMedium?.copyWith(
                decoration: change.kind == ProfileChangeKind.remove
                    ? TextDecoration.lineThrough
                    : null,
              )),
          if (change.item.role != MaterialRole.none)
            Text(change.item.role.label,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ],
    );

    if (selected == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: body,
      );
    }
    return CheckboxListTile(
      key: ValueKey('change_${change.itemId}'),
      value: selected,
      onChanged: onSelected == null ? null : (v) => onSelected!(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      title: body,
    );
  }
}
