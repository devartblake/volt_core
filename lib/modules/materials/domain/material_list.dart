import 'package:uuid/uuid.dart';

import 'material_item.dart';

const _uuid = Uuid();

/// Stable key for one generator's parts profile: the same make, model and
/// serial always give the same key, whatever the capitalisation or spacing.
///
/// Empty when there is nothing to identify it by, in which case the generator
/// has no shareable profile yet.
String generatorProfileKey({
  required String make,
  required String model,
  required String serial,
}) {
  String norm(String s) => s
      .toLowerCase()
      .replaceAll('|', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final m = norm(make), mo = norm(model), sn = norm(serial);
  if (sn.isEmpty && (m.isEmpty || mo.isEmpty)) return '';
  return '$m|$mo|$sn';
}

/// The rules for a list of [MaterialItem]s, kept apart from any screen so they
/// are tested on their own.
///
/// * A slot that takes one item keeps one.
/// * A slot that takes several has at most one primary and one secondary; the
///   first item is primary when nobody chose.
/// * Items that are still blank are not worth saving.
class MaterialListOps {
  const MaterialListOps._();

  /// The items of [slot], primary first, then secondary, then the rest, each
  /// group in the order they were added.
  static List<MaterialItem> forSlot(
    List<MaterialItem> items,
    MaterialSlot slot,
  ) {
    final mine = items.where((i) => i.slot == slot).toList();
    int rank(MaterialItem i) => switch (i.role) {
          MaterialRole.primary => 0,
          MaterialRole.secondary => 1,
          MaterialRole.none => 2,
        };
    final indexed = [for (var i = 0; i < mine.length; i++) (i, mine[i])];
    indexed.sort((a, b) {
      final r = rank(a.$2).compareTo(rank(b.$2));
      return r != 0 ? r : a.$1.compareTo(b.$1);
    });
    return [for (final e in indexed) e.$2];
  }

  /// Adds an empty item to [slot]. The first item in a slot that uses roles is
  /// primary, the second secondary, later ones unlabelled. Does nothing if the
  /// slot takes one item and already has it.
  static List<MaterialItem> add(List<MaterialItem> items, MaterialSlot slot) {
    final existing = items.where((i) => i.slot == slot).toList();
    if (!slot.multiple && existing.isNotEmpty) return items;

    var role = MaterialRole.none;
    if (slot.multiple && slot.usesRoles) {
      final hasPrimary = existing.any((i) => i.role == MaterialRole.primary);
      final hasSecondary =
          existing.any((i) => i.role == MaterialRole.secondary);
      role = !hasPrimary
          ? MaterialRole.primary
          : (!hasSecondary ? MaterialRole.secondary : MaterialRole.none);
    }
    return [
      ...items,
      MaterialItem(id: _uuid.v4(), slot: slot, role: role),
    ];
  }

  static List<MaterialItem> update(
    List<MaterialItem> items,
    MaterialItem changed,
  ) =>
      [for (final i in items) i.id == changed.id ? changed : i];

  /// Removes an item, then promotes so a slot never has a secondary with no
  /// primary.
  static List<MaterialItem> remove(List<MaterialItem> items, String id) =>
      normalize([
        for (final i in items)
          if (i.id != id) i,
      ]);

  /// Makes [id] the primary or secondary of its slot, keeping exactly one of
  /// each. Making an item primary moves the old primary to secondary and
  /// unlabels the old secondary; making it secondary unlabels the old
  /// secondary.
  static List<MaterialItem> setRole(
    List<MaterialItem> items,
    String id,
    MaterialRole role,
  ) {
    final target = items.firstWhere((i) => i.id == id);
    if (!target.slot.usesRoles || role == MaterialRole.none) {
      return normalize(update(items, target.copyWith(role: role)));
    }
    final wasSecondary = target.role == MaterialRole.secondary;

    return normalize([
      for (final i in items)
        if (i.id == id)
          i.copyWith(role: role)
        else if (i.slot != target.slot)
          i
        else if (role == MaterialRole.primary && i.role == MaterialRole.primary)
          i.copyWith(role: MaterialRole.secondary)
        else if (role == MaterialRole.primary &&
            i.role == MaterialRole.secondary &&
            !wasSecondary)
          i.copyWith(role: MaterialRole.none)
        else if (role == MaterialRole.secondary &&
            i.role == MaterialRole.secondary)
          i.copyWith(role: MaterialRole.none)
        else
          i,
    ]);
  }

  /// Enforces the slot rules on a whole list. Safe to call repeatedly.
  static List<MaterialItem> normalize(List<MaterialItem> items) {
    final out = <MaterialItem>[];
    for (final slot in MaterialSlot.values) {
      final mine = items.where((i) => i.slot == slot).toList();
      if (mine.isEmpty) continue;

      if (!slot.multiple) {
        out.add(mine.first.copyWith(role: MaterialRole.none));
        continue;
      }
      if (!slot.usesRoles) {
        out.addAll([for (final i in mine) i.copyWith(role: MaterialRole.none)]);
        continue;
      }

      // At most one primary and one secondary: later duplicates lose the label.
      var seenPrimary = false;
      var seenSecondary = false;
      final fixed = <MaterialItem>[];
      for (final i in mine) {
        if (i.role == MaterialRole.primary && !seenPrimary) {
          seenPrimary = true;
          fixed.add(i);
        } else if (i.role == MaterialRole.secondary && !seenSecondary) {
          seenSecondary = true;
          fixed.add(i);
        } else {
          fixed.add(i.copyWith(role: MaterialRole.none));
        }
      }
      // Nobody primary: a lone secondary is promoted, else the first item.
      if (!fixed.any((i) => i.role == MaterialRole.primary)) {
        final sec = fixed.indexWhere((i) => i.role == MaterialRole.secondary);
        final idx = sec >= 0 ? sec : 0;
        fixed[idx] = fixed[idx].copyWith(role: MaterialRole.primary);
      }
      out.addAll(fixed);
    }
    return out;
  }

  /// What is worth saving: blank items are dropped, then the rules applied.
  static List<MaterialItem> forSaving(List<MaterialItem> items) => normalize([
        for (final i in items)
          if (!i.isBlank) i,
      ]);

  /// Copies [items] with new ids, for filling a job from a generator profile.
  static List<MaterialItem> cloneWithNewIds(List<MaterialItem> items) => [
        for (final i in items)
          MaterialItem(
            id: _uuid.v4(),
            slot: i.slot,
            role: i.role,
            partNumber: i.partNumber,
            partName: i.partName,
            manufacturer: i.manufacturer,
            quantity: i.quantity,
            // A profile says what the generator takes; whether and when a part
            // was fitted on this job is for the technician to say.
            dateUsed: null,
            needsReplacement: false,
            notes: i.notes,
          ),
      ];

  /// Items due for replacement - what the follow-up job needs.
  static List<MaterialItem> needed(List<MaterialItem> items) => [
        for (final i in items)
          if (i.needsReplacement) i,
      ];

  /// The four dates the older inspection format kept, taken from the first
  /// item of each slot that has one (the primary first).
  static ({String oil, String fuel, String air, String battery}) legacyDates(
    List<MaterialItem> items,
  ) {
    String dateOf(MaterialSlot slot) {
      for (final i in forSlot(items, slot)) {
        if (i.dateUsed != null) return _iso(i.dateUsed!);
      }
      return '';
    }

    return (
      oil: dateOf(MaterialSlot.oilFilter),
      fuel: dateOf(MaterialSlot.fuelFilter),
      air: dateOf(MaterialSlot.airFilter),
      battery: dateOf(MaterialSlot.battery),
    );
  }

  /// Items for an inspection that has only the older date fields, so those
  /// dates are not lost when the new Materials step opens.
  static List<MaterialItem> seedFromLegacyDates({
    String oil = '',
    String fuel = '',
    String air = '',
    String battery = '',
  }) {
    var out = <MaterialItem>[];
    void put(MaterialSlot slot, String iso) {
      final d = DateTime.tryParse(iso);
      if (d == null) return;
      out = add(out, slot);
      final idx = out.lastIndexWhere((i) => i.slot == slot);
      out[idx] = out[idx].copyWith(dateUsed: d);
    }

    put(MaterialSlot.oilFilter, oil);
    put(MaterialSlot.fuelFilter, fuel);
    put(MaterialSlot.airFilter, air);
    put(MaterialSlot.battery, battery);
    return out;
  }

  static String _iso(DateTime d) => d.toIso8601String().split('T').first;
}
