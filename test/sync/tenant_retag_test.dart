import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/services/sync/sync_operation.dart';
import 'package:voltcore/core/services/sync/tenant_retag.dart';
import 'package:voltcore/modules/equipment/infra/mappers/equipment_supabase_mapper.dart';

/// The uuids from the reported device run. The "old tenant" is the auth user's
/// id, which is what SUPABASE_TENANT_ID had been set to when these rows were
/// captured — hence the 42501s.
const String _oldTenant = '8dd6ac71-f7a2-4c5d-a425-f98b8eb3bf9d';
const String _newTenant = '94f5d3dc-bbdf-42a3-a70e-1d19029f3ee3';
const String _inspectionId = 'b98a2d7f-d6f2-4730-a742-f9173f835b5e';

SyncOperation _upsert(
  String table,
  Map<String, dynamic> row, {
  int attempts = 0,
  SyncOpStatus status = SyncOpStatus.pending,
}) {
  return SyncOperation(
    id: 'op-1',
    type: SyncOpType.upsert,
    entityId: '$table/${row['id']}',
    payload: {'table': table, 'row': row},
    attempts: attempts,
    status: status,
  );
}

void main() {
  group('retagQueuedRow', () {
    test('rewrites a stale tenant_id on a queued inspection', () {
      final op = _upsert('inspections', {
        'id': _inspectionId,
        'tenant_id': _oldTenant,
        'site_code': '',
      });

      expect(retagQueuedRow(op, _newTenant), isTrue);
      expect(op.payload['row']['tenant_id'], _newTenant);
    });

    test('leaves a row that already names the current tenant alone', () {
      final op = _upsert('inspections', {
        'id': _inspectionId,
        'tenant_id': _newTenant,
      }, attempts: 4);

      expect(retagQueuedRow(op, _newTenant), isFalse);
      // Untouched means untouched: an unrelated failure keeps its backoff.
      expect(op.attempts, 4);
    });

    test('revives an op that had already exhausted its retry budget', () {
      final op = _upsert(
        'inspections',
        {'id': _inspectionId, 'tenant_id': _oldTenant},
        attempts: 8,
        status: SyncOpStatus.failed,
      );
      op.lastError = 'PostgrestException(code: 42501)';

      expect(retagQueuedRow(op, _newTenant), isTrue);
      expect(op.status, SyncOpStatus.pending);
      expect(op.attempts, 0);
      expect(op.lastError, isNull);
    });

    test('re-derives the equipment id, which is a function of the tenant', () {
      const identityKey = 'id:$_inspectionId';
      final staleId =
          equipmentIdFor(tenantId: _oldTenant, identityKey: identityKey);
      final op = _upsert(kEquipmentTable, {
        'id': staleId,
        'tenant_id': _oldTenant,
        'identity_key': identityKey,
      });

      expect(retagQueuedRow(op, _newTenant), isTrue);

      final expected =
          equipmentIdFor(tenantId: _newTenant, identityKey: identityKey);
      expect(op.payload['row']['id'], expected);
      expect(op.payload['row']['id'], isNot(staleId));
      // (tenant_id, identity_key) is unique, so keeping the old id would let a
      // freshly derived row for the same unit collide with this one.
      expect(op.entityId, '$kEquipmentTable/$expected');
    });

    test('does not add tenant_id to a row that never had one', () {
      // Could be a table with no tenant column at all; inventing one turns a
      // working write into a 400.
      final op = _upsert('app_settings', {'id': 'x', 'value': '1'});

      expect(retagQueuedRow(op, _newTenant), isFalse);
      expect(op.payload['row'].containsKey('tenant_id'), isFalse);
    });

    test('ignores deletes and uploads', () {
      final del = SyncOperation(
        id: 'op-2',
        type: SyncOpType.delete,
        entityId: 'inspections/$_inspectionId',
        payload: {'table': 'inspections', 'id': _inspectionId},
      );
      final upload = SyncOperation(
        id: 'op-3',
        type: SyncOpType.fileUpload,
        entityId: 'pdfs/a.pdf',
        payload: {'localPath': '/tmp/a.pdf', 'remotePath': 'pdfs/a.pdf'},
      );

      expect(retagQueuedRow(del, _newTenant), isFalse);
      expect(retagQueuedRow(upload, _newTenant), isFalse);
    });

    test('does nothing when no tenant is configured', () {
      final op = _upsert('inspections', {
        'id': _inspectionId,
        'tenant_id': _oldTenant,
      });

      expect(retagQueuedRow(op, ''), isFalse);
      expect(op.payload['row']['tenant_id'], _oldTenant);
    });

    test('survives a round trip through the queue\'s JSON encoding', () {
      final op = _upsert('inspections', {
        'id': _inspectionId,
        'tenant_id': _oldTenant,
      });

      retagQueuedRow(op, _newTenant);
      final restored = SyncOperation.fromJson(op.toJson());

      expect(restored.payload['row']['tenant_id'], _newTenant);
      expect(restored.status, SyncOpStatus.pending);
      expect(restored.attempts, 0);
    });
  });
}
