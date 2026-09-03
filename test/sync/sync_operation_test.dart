import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/services/sync/sync_operation.dart';

void main() {
  group('SyncOperation', () {
    test('round-trips through JSON', () {
      final op = SyncOperation(
        id: '1',
        type: SyncOpType.upsert,
        entityId: 'inspections/abc',
        payload: {
          'table': 'inspections',
          'row': {'id': 'abc', 'site_code': 'S1'},
        },
        attempts: 2,
        lastError: 'boom',
        status: SyncOpStatus.failed,
      );

      final restored = SyncOperation.fromJson(op.toJson());

      expect(restored.id, '1');
      expect(restored.type, SyncOpType.upsert);
      expect(restored.entityId, 'inspections/abc');
      expect(restored.attempts, 2);
      expect(restored.lastError, 'boom');
      expect(restored.status, SyncOpStatus.failed);
      expect((restored.payload['row'] as Map)['site_code'], 'S1');
    });

    test('insert-only operation round-trips without becoming an upsert', () {
      final op = SyncOperation(
        id: 'artifact-op',
        type: SyncOpType.insert,
        entityId: 'form_response_report_artifacts/report-1',
        payload: const {
          'table': 'form_response_report_artifacts',
          'row': {
            'id': 'report-1',
            'response_id': 'response-1',
          },
        },
      );

      final restored = SyncOperation.fromJson(op.toJson());

      expect(restored.type, SyncOpType.insert);
      expect(restored.dedupKey,
          'insert:form_response_report_artifacts/report-1');
      expect((restored.payload['row'] as Map)['response_id'], 'response-1');
    });

    test('dedupKey combines type and entityId', () {
      final op = SyncOperation(
        id: 'x',
        type: SyncOpType.fileUpload,
        entityId: 'photos/i1/p.jpg',
        payload: const {},
      );
      expect(op.dedupKey, 'fileUpload:photos/i1/p.jpg');
    });

    test('unknown type falls back to upsert', () {
      final op = SyncOperation.fromMap({
        'id': 'z',
        'type': 'nonsense',
        'entityId': 'e',
        'payload': <String, dynamic>{},
      });
      expect(op.type, SyncOpType.upsert);
      expect(op.status, SyncOpStatus.pending);
    });
  });
}
