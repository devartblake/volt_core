import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/photos/photo_attachment.dart';
import '../../../../core/services/photos/photo_service.dart';
import '../../../materials/domain/material_item.dart';
import '../../../materials/infra/materials_repository.dart';
import '../../domain/maintenance_progress.dart';
import '../../infra/models/maintenance_record.dart';
import 'maintenance_list_controller.dart';

/// Photo and material counts for one maintenance record.
typedef MaintenanceCounts = ({int photos, int materials});

/// Looks up how many photos a record has. A provider so tests can replace the
/// Hive-backed photo store.
final maintenancePhotoLookupProvider =
    Provider<Future<int> Function(String id)>((ref) {
  return (id) async {
    final photos = await PhotoService.instance
        .listForOwner(PhotoAttachment.ownerMaintenance, id);
    return photos.length;
  };
});

/// Counts for every in-progress record in the list, read once per list change
/// (one materials-box pass plus one photo lookup per unfinished record), not
/// per row build. Completed records are skipped: their chip needs no count.
final maintenanceListCountsProvider = FutureProvider.autoDispose<
    Map<String, MaintenanceCounts>>((ref) async {
  // Only the ids and completion flags matter, so a refresh that changes
  // nothing visible does not re-read the stores.
  final keys = ref.watch(maintenanceListControllerProvider.select((s) => [
        for (final r in s.records)
          if (!r.completed) r.id,
      ].join('|')));
  final ids = keys.isEmpty ? const <String>[] : keys.split('|');
  if (ids.isEmpty) return const {};

  final materials = <String, int>{};
  try {
    final lists = await ref.read(materialsRepositoryProvider).allJobLists();
    for (final l in lists) {
      if (l.type == MaterialOwnerType.maintenance) {
        materials[l.id] = l.items.length;
      }
    }
  } catch (_) {}

  final lookup = ref.read(maintenancePhotoLookupProvider);
  final out = <String, MaintenanceCounts>{};
  for (final id in ids) {
    var photos = 0;
    try {
      photos = await lookup(id);
    } catch (_) {}
    out[id] = (photos: photos, materials: materials[id] ?? 0);
  }
  return out;
});

/// Chip text for an unfinished record: "In progress" alone until at least one
/// step is done, then "In progress - 3 of 8".
String maintenanceInProgressLabel(
  MaintenanceRecord m,
  MaintenanceCounts? counts,
) {
  if (counts == null) return 'In progress';
  final p = MaintenanceProgress.compute(
    m,
    photoCount: counts.photos,
    materialCount: counts.materials,
  );
  if (p.doneCount == 0) return 'In progress';
  return 'In progress - ${p.doneCount} of ${p.total}';
}
