import '../../../modules/equipment/infra/mappers/equipment_supabase_mapper.dart';
import 'sync_operation.dart';

/// Re-stamps queued rows with the tenant that is configured *now*.
///
/// `tenant_id` is ambient configuration, not row data. It comes from
/// `SUPABASE_TENANT_ID`, and the serializers copy it into the row at the moment
/// an edit is queued. So a row queued while that env value was wrong carries
/// the wrong tenant for the rest of its life: fixing the env file changes what
/// *new* rows are stamped with and does nothing for the outbox. RLS then
/// rejects the queued row with 42501 on every retry, forever, while the app
/// truthfully reports that the configured tenant is correct.
///
/// The old advice for that state was "clear the sync queue", which throws away
/// completed offline work. Re-stamping heals it instead: the tenant identifies
/// which installation this device belongs to, it is not a property of an
/// individual inspection, and sending the row under the currently configured
/// tenant is what the technician meant in every case.
///
/// If an in-app tenant *switcher* is ever added, this stops being true — queued
/// work would then belong to whichever tenant was active when it was captured,
/// and the row's own value would be the authoritative one. Delete this pass at
/// that point rather than trying to make it clever.
bool retagQueuedRow(SyncOperation op, String tenantId) {
  if (tenantId.isEmpty) return false;
  if (op.type != SyncOpType.upsert) return false;

  final row = op.payload['row'];
  if (row is! Map) return false;

  // Only touch rows that already carry the column. A row without `tenant_id`
  // either targets a table that has no such column — where adding one turns a
  // working write into a 400 — or was queued with no tenant configured at all,
  // and from here those two cases are indistinguishable.
  final current = row['tenant_id'];
  if (current is! String || current.isEmpty || current == tenantId) return false;

  row['tenant_id'] = tenantId;

  if (op.payload['table'] == kEquipmentTable) {
    final identityKey = row['identity_key'];
    if (identityKey is String && identityKey.isNotEmpty) {
      // Equipment ids are derived from the tenant, and `(tenant_id,
      // identity_key)` is unique (migration 0004). Re-stamping the tenant but
      // keeping the old id would put a row in the table under an id no device
      // will ever derive again — and the next locally derived id for that same
      // unit would then collide with it on the unique constraint, swapping a
      // 42501 for a permanent 23505.
      final id = equipmentIdFor(tenantId: tenantId, identityKey: identityKey);
      row['id'] = id;
      // entityId is what the queue dedupes on, so it has to keep naming the
      // row it now describes; otherwise a re-derived unit enqueues a second op
      // for the same physical generator instead of collapsing into this one.
      op.entityId = '$kEquipmentTable/$id';
    }
  }

  // The row was rejected for naming the wrong tenant, not because the server
  // was unwell — so the retry budget it burned was spent on a question that has
  // since changed. Hand it back. Without this, a queue that already reached the
  // attempt ceiling stays `failed` and needs someone to find Retry Failed.
  op.attempts = 0;
  op.status = SyncOpStatus.pending;
  op.lastError = null;
  op.updatedAt = DateTime.now();
  return true;
}
