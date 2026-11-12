import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../inspections/presenter/controllers/inspection_list_controller.dart';
import '../../maintenance/presenter/controllers/maintenance_providers.dart';
import '../../materials/domain/material_item.dart';
import '../../materials/infra/materials_repository.dart';
import '../domain/job_needs.dart';
import '../domain/stock.dart';
import '../infra/inventory_repository.dart';

String _clip(String s, [int max = 60]) =>
    s.length <= max ? s : '${s.substring(0, max - 1)}…';

String _date(DateTime d) {
  final l = d.toLocal();
  return '${l.month}/${l.day}/${l.year}';
}

/// The parts each inspection (and maintenance) has flagged as needed, checked
/// against the catalog and the ledger. Titles come from the records on this
/// device; a list whose record is not here is left out.
final jobNeedsProvider = FutureProvider.autoDispose<List<JobNeeds>>((ref) async {
  final lists = await ref.watch(materialsRepositoryProvider).allJobLists();
  final repo = ref.watch(inventoryRepositoryProvider);
  final parts = await repo.parts();
  final movements = await repo.movements();

  final inspections = {
    for (final i in ref.read(inspectionListControllerProvider).items) i.id: i,
  };
  final maintenance = {
    for (final m in ref.read(maintenanceRepoProvider).getAll()) m.id: m,
  };

  final inputs = <JobNeedsInput>[];
  for (final l in lists) {
    if (l.type == MaterialOwnerType.inspection) {
      final i = inspections[l.id];
      if (i == null) continue;
      final place = i.address.trim().isEmpty ? i.siteCode : i.address;
      inputs.add(JobNeedsInput(
        type: l.type,
        id: l.id,
        title: _clip(place.isEmpty ? 'Inspection' : place),
        subtitle: 'Inspection · ${_date(i.serviceDate)}',
        date: i.serviceDate,
        items: l.items,
      ));
    } else {
      final m = maintenance[l.id];
      // A finished maintenance has used its parts; only open ones still need
      // them.
      if (m == null || m.completed) continue;
      final place = m.address.trim().isEmpty ? m.siteCode : m.address;
      inputs.add(JobNeedsInput(
        type: l.type,
        id: l.id,
        title: _clip(place.isEmpty ? 'Maintenance' : place),
        subtitle: 'Maintenance'
            '${m.dateOfService == null ? '' : ' · ${_date(m.dateOfService!)}'}',
        date: m.dateOfService,
        items: l.items,
        allItemsNeeded: true,
      ));
    }
  }
  return computeJobNeeds(inputs, parts, movements);
});

/// Everything jobs still need beyond the shelf.
final shortagesProvider = FutureProvider.autoDispose<List<Shortage>>((ref) async {
  final needs = await ref.watch(jobNeedsProvider.future);
  return computeShortages(needs);
});

/// Parts at or below their minimum.
final lowStockProvider = FutureProvider.autoDispose<List<StockLevel>>((ref) async {
  final levels = await ref.watch(stockLevelsProvider.future);
  return lowStockParts(levels);
});
