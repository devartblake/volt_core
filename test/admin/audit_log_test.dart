import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/admin/domain/audit_log.dart';

AuditEntry _e(int id, String table, DateTime at,
        {AuditAction action = AuditAction.update,
        String summary = '',
        String? actor,
        Map<String, dynamic>? old,
        Map<String, dynamic>? now}) =>
    AuditEntry(
      id: id,
      tableName: table,
      action: action,
      changedAt: at,
      summary: summary,
      actorUserId: actor,
      oldData: old,
      newData: now,
    );

void main() {
  final now = DateTime(2026, 6, 15, 12);

  test('tables map to the filter groups', () {
    expect(auditGroupOf('inspections'), AuditGroup.inspections);
    expect(auditGroupOf('part_prices'), AuditGroup.pricesVendors);
    expect(auditGroupOf('tenant_members'), AuditGroup.people);
    expect(auditGroupOf('purchase_orders'), AuditGroup.orders);
    expect(auditGroupOf('inventory_movements'), AuditGroup.inventory);
    expect(auditGroupOf('nothing'), isNull);
  });

  test('filters by group, period and text', () {
    final all = [
      _e(1, 'inspections', now.subtract(const Duration(hours: 2)),
          summary: 'Deleted inspection ACME-1'),
      _e(2, 'vendors', now.subtract(const Duration(days: 3)),
          summary: 'Updated vendor Grainger'),
      _e(3, 'tenant_members', now.subtract(const Duration(days: 20)),
          summary: 'Changed team member Dana', actor: 'u1'),
    ];
    List<int> ids(List<AuditEntry> l) => [for (final e in l) e.id];

    expect(ids(filterAudit(all, now: now, period: AuditPeriod.day)), [1]);
    expect(ids(filterAudit(all, now: now, period: AuditPeriod.week)), [1, 2]);
    expect(
        ids(filterAudit(all, now: now, period: AuditPeriod.month)), [1, 2, 3]);
    expect(
        ids(filterAudit(all,
            now: now,
            period: AuditPeriod.month,
            groups: {AuditGroup.pricesVendors, AuditGroup.people})),
        [2, 3]);
    expect(
        ids(filterAudit(all,
            now: now, period: AuditPeriod.month, query: 'grainger')),
        [2]);
    expect(
        ids(filterAudit(all,
            now: now,
            period: AuditPeriod.month,
            query: 'dana lee',
            names: {'u1': 'Dana Lee'})),
        [3]);
  });

  test('groups by local day, newest first', () {
    final days = groupAuditByDay([
      _e(1, 'vendors', DateTime(2026, 6, 14, 9)),
      _e(2, 'vendors', DateTime(2026, 6, 15, 8)),
      _e(3, 'vendors', DateTime(2026, 6, 15, 11)),
    ]);
    expect(days.length, 2);
    expect(days.first.day, DateTime(2026, 6, 15));
    expect([for (final e in days.first.entries) e.id], [3, 2]);
    expect(days.last.entries.single.id, 1);
  });

  test('actor label: name, short id, or System', () {
    expect(auditActorLabel('abcdef123', {'abcdef123': 'Dana'}), 'Dana');
    expect(auditActorLabel('abcdef123', const {}), 'abcdef');
    expect(auditActorLabel(null, const {}), 'System');
  });

  test('field changes show old to new for an update', () {
    final e = _e(1, 'vendors', now,
        old: {'name': 'A', 'is_active': true, 'updated_at': 'x'},
        now: {'name': 'B', 'is_active': false, 'updated_at': 'y'});
    final c = auditFieldChanges(e);
    expect(c.map((f) => f.field), ['Is active', 'Name']);
    expect(c.last.before, 'A');
    expect(c.last.after, 'B');
    expect(c.first.before, 'yes');
    expect(c.first.after, 'no');
  });

  test('insert shows new values, delete shows old values', () {
    final ins = auditFieldChanges(
        _e(1, 'vendors', now, action: AuditAction.insert, now: {'name': 'B'}));
    expect(ins.single.before, isNull);
    expect(ins.single.after, 'B');
    final del = auditFieldChanges(
        _e(2, 'vendors', now, action: AuditAction.delete, old: {'name': 'A'}));
    expect(del.single.before, 'A');
    expect(del.single.after, isNull);
  });

  test('fromJson reads a Supabase row and rejects a broken one', () {
    final e = AuditEntry.fromJson({
      'id': 7,
      'table_name': 'vendors',
      'record_id': 'r',
      'action': 'delete',
      'actor_user_id': 'u',
      'changed_at': '2026-06-15T12:00:00Z',
      'old_data': {'name': 'A'},
      'new_data': null,
      'summary': 'Deleted vendor A',
    })!;
    expect(e.action, AuditAction.delete);
    expect(e.oldData!['name'], 'A');
    expect(AuditEntry.fromJson({'id': 'x'}), isNull);
  });
}
