import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/services/sync/sync_operation.dart';
import 'package:voltcore/core/services/sync/sync_summary.dart';

SyncOperation _op(String id, String table,
        {SyncOpType type = SyncOpType.upsert,
        SyncOpStatus status = SyncOpStatus.pending,
        int sec = 0}) =>
    SyncOperation(
      id: id,
      type: type,
      entityId: '$table/$id',
      payload: {'table': table, 'row': {}},
      status: status,
      createdAt: DateTime(2026, 1, 1).add(Duration(seconds: sec)),
    );

void main() {
  test('friendly names', () {
    expect(friendlyTableName('parts_catalog'), 'Parts');
    expect(friendlyTableName('inventory_movements'), 'Stock movements');
    expect(friendlyTableName('asset_parts'), 'Generator parts');
    expect(friendlyTableName('form_responses'), 'Inspections');
    expect(friendlyTableName('maintenance_records'), 'Maintenance records');
    expect(friendlyTableName('some_new_table'), 'Some new table');
  });

  test('groups pending by label, largest first, merging same-label tables', () {
    final s = summarizeQueue([
      for (var i = 0; i < 3; i++) _op('p$i', 'parts_catalog'),
      _op('m', 'inventory_movements'),
      _op('t1', 'form_templates'),
      _op('t2', 'form_template_fields'),
      _op('f', 'x',
          type: SyncOpType.fileUpload),
    ]);
    expect([for (final g in s.pending) g.toString()], [
      'Parts: 3',
      'Inspection templates: 2',
      'Photos and files: 1',
      'Stock movements: 1',
    ]);
    expect(s.pendingCount, 7);
    expect(s.failed, isEmpty);
  });

  test('failed ops are listed separately, oldest first', () {
    final s = summarizeQueue([
      _op('b', 'parts_catalog', status: SyncOpStatus.failed, sec: 5),
      _op('a', 'parts_catalog', status: SyncOpStatus.failed, sec: 1),
      _op('c', 'parts_catalog'),
    ]);
    expect(s.failed.map((o) => o.id), ['a', 'b']);
    expect(s.pendingCount, 1);
    expect(summarizeQueue([]).isEmpty, isTrue);
  });

  test('shortError and opTargets', () {
    expect(shortError(null), 'Unknown error');
    expect(shortError('boom\nstack'), 'boom');
    expect(opTargets(_op('1', 'parts_catalog'), 'parts_catalog', '1'), isTrue);
    expect(opTargets(_op('1', 'parts_catalog'), 'vendors', '1'), isFalse);
  });
}
