import 'package:flutter/foundation.dart';

/// What happened to the record.
enum AuditAction {
  insert('insert', 'Added'),
  update('update', 'Changed'),
  delete('delete', 'Deleted');

  const AuditAction(this.wire, this.label);

  final String wire;
  final String label;

  static AuditAction fromWire(String? s) => AuditAction.values
      .firstWhere((a) => a.wire == s, orElse: () => AuditAction.update);
}

/// One row of `audit_log`, as the admin page sees it.
@immutable
class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.tableName,
    required this.action,
    required this.changedAt,
    this.recordId,
    this.actorUserId,
    this.oldData,
    this.newData,
    this.summary = '',
  });

  final int id;
  final String tableName;
  final String? recordId;
  final AuditAction action;
  final String? actorUserId;
  final DateTime changedAt;
  final Map<String, dynamic>? oldData;
  final Map<String, dynamic>? newData;
  final String summary;

  static AuditEntry? fromJson(Map<String, dynamic> j) {
    final id = j['id'];
    final table = j['table_name'];
    final at = DateTime.tryParse('${j['changed_at']}');
    if (id is! num || table is! String || at == null) return null;
    Map<String, dynamic>? map(Object? o) =>
        o is Map ? Map<String, dynamic>.from(o) : null;
    return AuditEntry(
      id: id.toInt(),
      tableName: table,
      recordId: j['record_id'] as String?,
      action: AuditAction.fromWire(j['action'] as String?),
      actorUserId: j['actor_user_id'] as String?,
      changedAt: at.toLocal(),
      oldData: map(j['old_data']),
      newData: map(j['new_data']),
      summary: (j['summary'] ?? '') as String,
    );
  }
}

/// The filter chips: which kind of record.
enum AuditGroup {
  inspections('Inspections', {
    'inspections',
    'maintenance_jobs',
    'vehicle_inspections',
  }),
  inventory('Inventory', {'inventory_movements', 'inventory_locations'}),
  pricesVendors('Prices & vendors', {'part_prices', 'vendors'}),
  orders('Orders', {'purchase_orders'}),
  people('People & roles', {
    'tenant_members',
    'user_profiles',
    'profile_change_requests',
    'member_permission_overrides',
    'member_divisions',
  });

  const AuditGroup(this.label, this.tables);

  final String label;
  final Set<String> tables;
}

/// The group a table belongs to, or null for a table the page does not know.
AuditGroup? auditGroupOf(String table) {
  for (final g in AuditGroup.values) {
    if (g.tables.contains(table)) return g;
  }
  return null;
}

/// A readable name for a table.
String auditTableLabel(String table) => switch (table) {
      'inspections' => 'Inspection',
      'maintenance_jobs' => 'Maintenance',
      'vehicle_inspections' => 'Vehicle inspection',
      'inventory_movements' => 'Stock',
      'inventory_locations' => 'Location',
      'part_prices' => 'Price',
      'vendors' => 'Vendor',
      'purchase_orders' => 'Order',
      'tenant_members' => 'Team',
      'user_profiles' => 'Account',
      'profile_change_requests' => 'Parts profile',
      'member_permission_overrides' => 'Permission',
      'member_divisions' => 'Division',
      _ => table.replaceAll('_', ' '),
    };

/// How far back to look.
enum AuditPeriod {
  day('24 hours', Duration(hours: 24)),
  week('7 days', Duration(days: 7)),
  month('30 days', Duration(days: 30));

  const AuditPeriod(this.label, this.span);

  final String label;
  final Duration span;
}

/// Applies the chips, the period and the text search. [groups] empty means
/// every table. Search matches the summary, the table label and the person.
List<AuditEntry> filterAudit(
  List<AuditEntry> all, {
  Set<AuditGroup> groups = const {},
  AuditPeriod? period,
  String query = '',
  Map<String, String> names = const {},
  required DateTime now,
}) {
  final q = query.trim().toLowerCase();
  final from = period == null ? null : now.subtract(period.span);
  return [
    for (final e in all)
      if ((groups.isEmpty ||
              (auditGroupOf(e.tableName) != null &&
                  groups.contains(auditGroupOf(e.tableName)))) &&
          (from == null || !e.changedAt.isBefore(from)) &&
          (q.isEmpty ||
              e.summary.toLowerCase().contains(q) ||
              auditTableLabel(e.tableName).toLowerCase().contains(q) ||
              auditActorLabel(e.actorUserId, names).toLowerCase().contains(q)))
        e,
  ];
}

/// The entries of one calendar day.
@immutable
class AuditDay {
  const AuditDay(this.day, this.entries);

  final DateTime day;
  final List<AuditEntry> entries;
}

/// Groups [entries] by local day, newest day first and newest entry first
/// within a day.
List<AuditDay> groupAuditByDay(List<AuditEntry> entries) {
  final sorted = [...entries]
    ..sort((a, b) {
      final c = b.changedAt.compareTo(a.changedAt);
      return c != 0 ? c : b.id.compareTo(a.id);
    });
  final out = <AuditDay>[];
  for (final e in sorted) {
    final d = DateTime(e.changedAt.year, e.changedAt.month, e.changedAt.day);
    if (out.isNotEmpty && out.last.day == d) {
      out.last.entries.add(e);
    } else {
      out.add(AuditDay(d, [e]));
    }
  }
  return out;
}

/// The person's name, or the first 6 characters of their id, or "System".
String auditActorLabel(String? userId, Map<String, String> names) {
  if (userId == null || userId.isEmpty) return 'System';
  final n = names[userId];
  if (n != null && n.trim().isNotEmpty) return n.trim();
  return userId.length <= 6 ? userId : userId.substring(0, 6);
}

/// One field that changed.
@immutable
class AuditFieldChange {
  const AuditFieldChange(this.field, this.before, this.after);

  final String field;

  /// Null when the field had no value (or the row did not exist).
  final String? before;
  final String? after;
}

/// A value as short text. Null stays null.
String? formatAuditValue(Object? v) {
  if (v == null) return null;
  if (v is String) return v.isEmpty ? '(empty)' : v;
  if (v is bool) return v ? 'yes' : 'no';
  if (v is num) return '$v';
  final s = '$v';
  return s.length > 200 ? '${s.substring(0, 199)}…' : s;
}

String _fieldLabel(String key) {
  final s = key.replaceAll('_', ' ');
  return s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

/// The fields to show for an entry: for an update each changed key, old to
/// new; for an insert the new values; for a delete the old values. Keys that
/// are only bookkeeping are left out.
List<AuditFieldChange> auditFieldChanges(AuditEntry e) {
  const hidden = {'updated_at', 'created_at', 'updated_by'};
  final old = e.oldData ?? const <String, dynamic>{};
  final now = e.newData ?? const <String, dynamic>{};
  final keys = <String>{...old.keys, ...now.keys}.where((k) => !hidden.contains(k)).toList()
    ..sort();
  return [
    for (final k in keys)
      AuditFieldChange(
        _fieldLabel(k),
        e.action == AuditAction.insert ? null : formatAuditValue(old[k]),
        e.action == AuditAction.delete ? null : formatAuditValue(now[k]),
      ),
  ];
}
