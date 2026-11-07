import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/sync/pending_records.dart';

/// Tiny cloud-upload marker shown while a record still waits in the sync
/// queue ("saved on this device, not uploaded yet"). Renders nothing otherwise.
///
/// [table] is the Supabase table the record is synced to; [recordId] its id.
class PendingUploadBadge extends ConsumerWidget {
  const PendingUploadBadge({
    super.key,
    required this.table,
    required this.recordId,
  });

  final String table;
  final String recordId;

  static const String message = 'Not uploaded yet';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = pendingKey(table, recordId);
    final pending = ref.watch(
      pendingRecordKeysProvider.select((v) => v.value?.contains(key) ?? false),
    );
    if (!pending) return const SizedBox.shrink();

    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Tooltip(
      message: message,
      child: Semantics(
        label: message,
        image: true,
        excludeSemantics: true,
        child: Icon(Icons.cloud_upload_outlined, size: 16, color: color),
      ),
    );
  }
}
