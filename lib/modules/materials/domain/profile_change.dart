import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'material_item.dart';
import 'material_list.dart';

/// A technician's proposed change to a generator's parts profile, kept apart
/// from any screen so the rules are tested on their own.
///
/// A request holds per-item changes: parts to add, fields to change on a part,
/// parts to remove. A reviewer applies all or some of them; anything the
/// profile has moved on from since the proposal is "stale" and is not applied
/// unless the reviewer asks.

enum ProfileRequestStatus {
  pending('pending', 'Waiting for approval'),
  approved('approved', 'Approved'),
  rejected('rejected', 'Rejected'),
  withdrawn('withdrawn', 'Withdrawn');

  const ProfileRequestStatus(this.wire, this.label);
  final String wire;
  final String label;

  static ProfileRequestStatus fromWire(String? wire) {
    for (final s in values) {
      if (s.wire == wire) return s;
    }
    return pending;
  }
}

enum ProfileChangeKind {
  add('add'),
  update('update'),
  remove('remove');

  const ProfileChangeKind(this.wire);
  final String wire;

  static ProfileChangeKind? fromWire(String? wire) {
    for (final k in values) {
      if (k.wire == wire) return k;
    }
    return null;
  }
}

/// The item fields a profile change can touch.
const List<String> kProfileFields = [
  'role',
  'partNumber',
  'partName',
  'manufacturer',
  'quantity',
  'dateUsed',
  'notes',
];

String profileFieldLabel(String field) => switch (field) {
      'role' => 'Role',
      'partNumber' => 'Part number',
      'partName' => 'Part name',
      'manufacturer' => 'Manufacturer',
      'quantity' => 'Quantity',
      'dateUsed' => 'Date last fitted',
      'notes' => 'Notes',
      _ => field,
    };

/// A field of [item] as text ('' when empty), the form changes are compared
/// and stored in.
String profileFieldValue(MaterialItem item, String field) => switch (field) {
      'role' => item.role.wire,
      'partNumber' => item.partNumber.trim(),
      'partName' => item.partName.trim(),
      'manufacturer' => item.manufacturer.trim(),
      'quantity' => '${item.quantity}',
      'dateUsed' => item.dateUsed == null
          ? ''
          : item.dateUsed!.toIso8601String().split('T').first,
      'notes' => item.notes.trim(),
      _ => '',
    };

MaterialItem _withField(MaterialItem item, String field, String value) =>
    switch (field) {
      'role' => item.copyWith(role: MaterialRole.fromWire(value)),
      'partNumber' => item.copyWith(partNumber: value),
      'partName' => item.copyWith(partName: value),
      'manufacturer' => item.copyWith(manufacturer: value),
      'quantity' =>
        item.copyWith(quantity: int.tryParse(value) ?? item.quantity),
      'dateUsed' => item.copyWith(dateUsed: DateTime.tryParse(value)),
      'notes' => item.copyWith(notes: value),
      _ => item,
    };

@immutable
class FieldChange {
  const FieldChange(
      {required this.field, required this.from, required this.to});

  final String field;
  final String from;
  final String to;

  Map<String, dynamic> toJson() => {'field': field, 'from': from, 'to': to};

  static FieldChange? fromJson(Map<String, dynamic> j) {
    final f = j['field']?.toString() ?? '';
    if (!kProfileFields.contains(f)) return null;
    return FieldChange(
      field: f,
      from: j['from']?.toString() ?? '',
      to: j['to']?.toString() ?? '',
    );
  }
}

/// How a change sits against the profile as it is now.
enum ChangeState {
  /// Still applies cleanly.
  ok,

  /// The profile moved on since the proposal: the item was changed or removed
  /// by someone else, or the slot is now taken.
  stale,

  /// The profile already has the result; nothing to do.
  alreadyApplied,
}

/// One part's change. [item] is the part as the proposer saw it (for an add,
/// the part being added; for an update or remove, the part before the change).
@immutable
class ProfileItemChange {
  const ProfileItemChange({
    required this.kind,
    required this.item,
    this.fields = const [],
  });

  final ProfileChangeKind kind;
  final MaterialItem item;

  /// For an update: what changes on the part.
  final List<FieldChange> fields;

  /// One change per part, so the part's id identifies the change.
  String get itemId => item.id;
  MaterialSlot get slot => item.slot;

  Map<String, dynamic> toJson() => {
        'kind': kind.wire,
        'item': item.toJson(),
        if (fields.isNotEmpty) 'fields': [for (final f in fields) f.toJson()],
      };

  static ProfileItemChange? fromJson(Map<String, dynamic> j) {
    final kind = ProfileChangeKind.fromWire(j['kind']?.toString());
    final raw = j['item'];
    if (kind == null || raw is! Map) return null;
    final item = MaterialItem.fromJson(Map<String, dynamic>.from(raw));
    if (item == null) return null;
    final fields = <FieldChange>[];
    final rawFields = j['fields'];
    if (rawFields is List) {
      for (final f in rawFields) {
        if (f is Map) {
          final fc = FieldChange.fromJson(Map<String, dynamic>.from(f));
          if (fc != null) fields.add(fc);
        }
      }
    }
    return ProfileItemChange(kind: kind, item: item, fields: fields);
  }
}

@immutable
class ProfileChangeRequest {
  const ProfileChangeRequest({
    required this.id,
    required this.generatorKey,
    required this.proposedBy,
    required this.createdAt,
    required this.updatedAt,
    this.make = '',
    this.model = '',
    this.serial = '',
    this.proposedByName = '',
    this.status = ProfileRequestStatus.pending,
    this.note = '',
    this.changes = const [],
    this.reviewedBy,
    this.reviewedAt,
    this.reviewNote = '',
  });

  final String id;
  final String generatorKey;
  final String make;
  final String model;
  final String serial;
  final String proposedBy;
  final String proposedByName;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ProfileRequestStatus status;

  /// Why the technician asks for the change.
  final String note;
  final List<ProfileItemChange> changes;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String reviewNote;

  bool get isPending => status == ProfileRequestStatus.pending;

  /// "Generac RG  SN 123", for lists.
  String get generatorLabel {
    final name = [make, model].where((s) => s.trim().isNotEmpty).join(' ');
    return [
      if (name.isNotEmpty) name,
      if (serial.trim().isNotEmpty) 'SN ${serial.trim()}',
    ].join('  ·  ');
  }

  ProfileChangeRequest copyWith({
    ProfileRequestStatus? status,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? reviewNote,
    DateTime? updatedAt,
  }) =>
      ProfileChangeRequest(
        id: id,
        generatorKey: generatorKey,
        make: make,
        model: model,
        serial: serial,
        proposedBy: proposedBy,
        proposedByName: proposedByName,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        status: status ?? this.status,
        note: note,
        changes: changes,
        reviewedBy: reviewedBy ?? this.reviewedBy,
        reviewedAt: reviewedAt ?? this.reviewedAt,
        reviewNote: reviewNote ?? this.reviewNote,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'generatorKey': generatorKey,
        'make': make,
        'model': model,
        'serial': serial,
        'proposedBy': proposedBy,
        'proposedByName': proposedByName,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'status': status.wire,
        'note': note,
        'changes': [for (final c in changes) c.toJson()],
        'reviewedBy': reviewedBy,
        'reviewedAt': reviewedAt?.toIso8601String(),
        'reviewNote': reviewNote,
      };

  static ProfileChangeRequest? fromJson(Map<String, dynamic> j) {
    final id = j['id']?.toString() ?? '';
    final key = j['generatorKey']?.toString() ?? '';
    if (id.isEmpty || key.isEmpty) return null;
    final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    final created = DateTime.tryParse('${j['createdAt'] ?? ''}');
    final changes = <ProfileItemChange>[];
    var raw = j['changes'];
    if (raw is String) {
      try {
        raw = jsonDecode(raw);
      } catch (_) {
        raw = null;
      }
    }
    if (raw is List) {
      for (final c in raw) {
        if (c is Map) {
          final pc = ProfileItemChange.fromJson(Map<String, dynamic>.from(c));
          if (pc != null) changes.add(pc);
        }
      }
    }
    final reviewedBy = j['reviewedBy']?.toString() ?? '';
    return ProfileChangeRequest(
      id: id,
      generatorKey: key,
      make: j['make']?.toString() ?? '',
      model: j['model']?.toString() ?? '',
      serial: j['serial']?.toString() ?? '',
      proposedBy: j['proposedBy']?.toString() ?? '',
      proposedByName: j['proposedByName']?.toString() ?? '',
      createdAt: created ?? epoch,
      updatedAt:
          DateTime.tryParse('${j['updatedAt'] ?? ''}') ?? created ?? epoch,
      status: ProfileRequestStatus.fromWire(j['status']?.toString()),
      note: j['note']?.toString() ?? '',
      changes: changes,
      reviewedBy: reviewedBy.isEmpty ? null : reviewedBy,
      reviewedAt: DateTime.tryParse('${j['reviewedAt'] ?? ''}'),
      reviewNote: j['reviewNote']?.toString() ?? '',
    );
  }

  static String encode(ProfileChangeRequest r) => jsonEncode(r.toJson());

  static ProfileChangeRequest? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final d = jsonDecode(raw);
      return d is Map ? fromJson(Map<String, dynamic>.from(d)) : null;
    } catch (_) {
      return null;
    }
  }
}

/// What a reviewer's apply did.
class ApplyResult {
  const ApplyResult({
    required this.items,
    required this.applied,
    required this.skippedStale,
    required this.alreadyApplied,
  });

  /// The profile after applying, with the slot rules enforced.
  final List<MaterialItem> items;

  /// Item ids of the changes that were applied.
  final List<String> applied;

  /// Item ids of stale changes that were left out.
  final List<String> skippedStale;

  /// Item ids of changes the profile already had.
  final List<String> alreadyApplied;
}

class ProfileChanges {
  const ProfileChanges._();

  static bool _same(MaterialItem a, MaterialItem b) => kProfileFields
      .every((f) => profileFieldValue(a, f) == profileFieldValue(b, f));

  /// The changes that turn [current] into [proposed]. Parts are matched by id
  /// and the order of the lists is ignored; blank proposed parts are not
  /// changes.
  static List<ProfileItemChange> diffProfiles(
    List<MaterialItem> current,
    List<MaterialItem> proposed,
  ) {
    final cur = {for (final i in current) i.id: i};
    final prop = {
      for (final i in proposed)
        if (!i.isBlank) i.id: i,
    };
    final out = <ProfileItemChange>[];
    for (final entry in prop.entries) {
      final before = cur[entry.key];
      final after = entry.value;
      if (before == null) {
        out.add(ProfileItemChange(kind: ProfileChangeKind.add, item: after));
        continue;
      }
      final fields = [
        for (final f in kProfileFields)
          if (profileFieldValue(before, f) != profileFieldValue(after, f))
            FieldChange(
              field: f,
              from: profileFieldValue(before, f),
              to: profileFieldValue(after, f),
            ),
      ];
      if (fields.isNotEmpty) {
        out.add(ProfileItemChange(
          kind: ProfileChangeKind.update,
          item: before,
          fields: fields,
        ));
      }
    }
    for (final entry in cur.entries) {
      if (!prop.containsKey(entry.key) && !entry.value.isBlank) {
        out.add(ProfileItemChange(
            kind: ProfileChangeKind.remove, item: entry.value));
      }
    }
    return out;
  }

  /// What a job's parts list would make the profile if it were adopted, in a
  /// form [diffProfiles] can compare: a job part that is the same part as a
  /// profile part (same slot and part number, or the one part of a single
  /// slot) takes that part's id and its "date last fitted", so only real
  /// differences show. Other job parts become new profile parts with new ids.
  static List<MaterialItem> proposalFromJob(
    List<MaterialItem> profile,
    List<MaterialItem> job,
  ) {
    String pn(MaterialItem i) => i.partNumber.trim().toLowerCase();
    final taken = <String>{};
    final out = <MaterialItem>[];
    for (final j in MaterialListOps.cloneWithNewIds(
        [for (final i in job) if (!i.isBlank) i])) {
      MaterialItem? match;
      for (final p in profile) {
        if (taken.contains(p.id) || p.slot != j.slot) continue;
        final same = !j.slot.multiple || (pn(j).isNotEmpty && pn(p) == pn(j));
        if (same) {
          match = p;
          break;
        }
      }
      if (match == null) {
        out.add(j);
      } else {
        taken.add(match.id);
        out.add(MaterialItem(
          id: match.id,
          slot: j.slot,
          role: j.role,
          partNumber: j.partNumber,
          partName: j.partName,
          manufacturer: j.manufacturer,
          quantity: j.quantity,
          dateUsed: match.dateUsed,
          notes: j.notes,
        ));
      }
    }
    return MaterialListOps.normalize(out);
  }

  /// How [change] sits against the profile as it is now.
  static ChangeState stateOf(
    List<MaterialItem> current,
    ProfileItemChange change,
  ) {
    MaterialItem? now;
    for (final i in current) {
      if (i.id == change.itemId) now = i;
    }
    switch (change.kind) {
      case ProfileChangeKind.add:
        if (now != null) return ChangeState.alreadyApplied;
        final slot = change.slot;
        if (!slot.multiple && current.any((i) => i.slot == slot)) {
          return ChangeState.stale;
        }
        return ChangeState.ok;
      case ProfileChangeKind.update:
        if (now == null) return ChangeState.stale;
        final here = now;
        if (change.fields
            .every((f) => profileFieldValue(here, f.field) == f.to)) {
          return ChangeState.alreadyApplied;
        }
        if (change.fields
            .any((f) => profileFieldValue(here, f.field) != f.from)) {
          return ChangeState.stale;
        }
        return ChangeState.ok;
      case ProfileChangeKind.remove:
        if (now == null) return ChangeState.alreadyApplied;
        return _same(now, change.item) ? ChangeState.ok : ChangeState.stale;
    }
  }

  /// Applies [changes] to [current]. Only the changes whose item ids are in
  /// [only] are considered when given. Stale changes are skipped unless
  /// [includeStale]; one that cannot be applied at all (an update to a part
  /// that is gone) is skipped regardless. The result goes through
  /// [MaterialListOps.forSaving] so primary / secondary rules hold.
  static ApplyResult applyChanges(
    List<MaterialItem> current,
    List<ProfileItemChange> changes, {
    Set<String>? only,
    bool includeStale = false,
  }) {
    var items = [...current];
    final applied = <String>[];
    final skipped = <String>[];
    final already = <String>[];

    for (final c in changes) {
      if (only != null && !only.contains(c.itemId)) continue;
      // Judged against the list as it stands, so earlier changes in the same
      // request are taken into account.
      final state = stateOf(items, c);
      if (state == ChangeState.alreadyApplied) {
        already.add(c.itemId);
        continue;
      }
      final canForce = switch (c.kind) {
        ProfileChangeKind.add => true,
        ProfileChangeKind.update => items.any((i) => i.id == c.itemId),
        ProfileChangeKind.remove => true,
      };
      if (state == ChangeState.stale && !(includeStale && canForce)) {
        skipped.add(c.itemId);
        continue;
      }
      switch (c.kind) {
        case ProfileChangeKind.add:
          // A forced add to a taken single slot replaces what is there.
          if (!c.slot.multiple) {
            items = [
              for (final i in items)
                if (i.slot != c.slot) i,
            ];
          }
          items.add(c.item);
        case ProfileChangeKind.update:
          items = [
            for (final i in items)
              if (i.id == c.itemId)
                c.fields.fold<MaterialItem>(
                    i, (acc, f) => _withField(acc, f.field, f.to))
              else
                i,
          ];
        case ProfileChangeKind.remove:
          items = [
            for (final i in items)
              if (i.id != c.itemId) i,
          ];
      }
      applied.add(c.itemId);
    }
    return ApplyResult(
      items: MaterialListOps.forSaving(items),
      applied: applied,
      skippedStale: skipped,
      alreadyApplied: already,
    );
  }
}
