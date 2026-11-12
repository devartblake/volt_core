import 'sync_operation.dart';

/// Friendly name for a Supabase table (plural, as in "12 Parts").
String friendlyTableName(String table) {
  const names = <String, String>{
    'parts_catalog': 'Parts',
    'part_prices': 'Part prices',
    'vendors': 'Vendors',
    'purchase_orders': 'Purchase orders',
    'purchase_order_lines': 'Purchase order lines',
    'inventory_movements': 'Stock movements',
    'inventory_locations': 'Stock locations',
    'job_material_lines': 'Job materials',
    'asset_parts': 'Generator parts',
    'profile_change_requests': 'Parts profile requests',
    'equipment': 'Equipment',
    'vehicle_assets': 'Vehicle assets',
    'vehicle_asset_catalog': 'Vehicle asset catalog',
    'vehicle_maintenance_checks': 'Vehicle checks',
    'vehicle_inspections': 'Vehicle inspections',
    'fleet_vehicles': 'Vehicles',
    'form_responses': 'Inspections',
    'form_templates': 'Inspection templates',
    'form_template_sections': 'Inspection templates',
    'form_template_fields': 'Inspection templates',
    'form_template_field_options': 'Inspection templates',
    'form_template_revisions': 'Inspection templates',
    'maintenance_jobs': 'Maintenance jobs',
    'maintenance_records': 'Maintenance records',
    'schedule_tasks': 'Schedule',
    'work_orders': 'Work orders',
    'work_order_events': 'Work order history',
  };
  final known = names[table];
  if (known != null) return known;
  if (table.isEmpty) return 'Other';
  final words = table.split('_').where((w) => w.isNotEmpty).toList();
  final text = words.join(' ');
  return text[0].toUpperCase() + text.substring(1);
}

/// The table an operation targets, or null for file uploads.
String? tableOf(SyncOperation op) {
  final t = op.payload['table'];
  return t is String && t.isNotEmpty ? t : null;
}

/// Friendly group label for an operation.
String groupLabelFor(SyncOperation op) {
  switch (op.type) {
    case SyncOpType.fileUpload:
    case SyncOpType.bytesUpload:
      return 'Photos and files';
    case SyncOpType.insert:
    case SyncOpType.upsert:
    case SyncOpType.delete:
      final t = tableOf(op);
      return t == null ? 'Other' : friendlyTableName(t);
  }
}

/// One line in the sync centre: a friendly group and how many ops are in it.
class SyncGroup {
  const SyncGroup(this.label, this.count);
  final String label;
  final int count;

  @override
  String toString() => '$label: $count';
}

/// Everything the sync centre shows, derived from the queue.
class SyncSummary {
  const SyncSummary({required this.pending, required this.failed});

  /// Pending ops grouped by friendly name, largest first (ties by name).
  final List<SyncGroup> pending;

  /// Failed ops, oldest first.
  final List<SyncOperation> failed;

  int get pendingCount => pending.fold(0, (a, g) => a + g.count);
  bool get isEmpty => pending.isEmpty && failed.isEmpty;
}

/// Group the queued [ops] for display. Pure.
SyncSummary summarizeQueue(Iterable<SyncOperation> ops) {
  final counts = <String, int>{};
  final failed = <SyncOperation>[];
  for (final op in ops) {
    if (op.status == SyncOpStatus.failed) {
      failed.add(op);
    } else {
      final label = groupLabelFor(op);
      counts[label] = (counts[label] ?? 0) + 1;
    }
  }
  final groups = [for (final e in counts.entries) SyncGroup(e.key, e.value)]
    ..sort((a, b) {
      final c = b.count.compareTo(a.count);
      return c != 0 ? c : a.label.compareTo(b.label);
    });
  failed.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return SyncSummary(pending: groups, failed: failed);
}

/// Short human text for a raw error string (first line, trimmed).
String shortError(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 'Unknown error';
  final line = raw.trim().split('\n').first;
  return line.length > 160 ? '${line.substring(0, 157)}...' : line;
}

/// True if op targets [recordId] in [table] (for per-record pending markers).
bool opTargets(SyncOperation op, String table, String recordId) =>
    op.entityId == '$table/$recordId';
