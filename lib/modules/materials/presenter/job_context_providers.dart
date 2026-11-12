import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../inspections/presenter/controllers/inspection_list_controller.dart';
import '../../maintenance/presenter/controllers/maintenance_providers.dart';
import '../domain/material_item.dart';
import '../domain/material_list.dart';
import '../domain/part_usage.dart';
import '../infra/materials_repository.dart';

/// What an inspection or maintenance is, for labelling and grouping its parts.
class JobContext {
  const JobContext({
    required this.type,
    required this.id,
    required this.title,
    required this.generatorKey,
    required this.generatorLabel,
  });

  final MaterialOwnerType type;
  final String id;
  final String title;
  final String generatorKey;
  final String generatorLabel;

  String get jobRef => '${type.wire}:$id';
}

String _gen(String make, String model, String serial) {
  final name = [make, model].where((s) => s.trim().isNotEmpty).join(' ');
  final sn = serial.trim().isEmpty ? '' : 'SN ${serial.trim()}';
  return [name, sn].where((s) => s.isNotEmpty).join(', ');
}

/// Every inspection and maintenance on this device, keyed by job ref
/// (`inspection:ID` / `maintenance:ID`).
final jobContextsProvider =
    Provider.autoDispose<Map<String, JobContext>>((ref) {
  final out = <String, JobContext>{};
  for (final i in ref.watch(inspectionListControllerProvider).items) {
    final place = i.address.trim().isEmpty ? i.siteCode : i.address;
    final c = JobContext(
      type: MaterialOwnerType.inspection,
      id: i.id,
      title: place.isEmpty ? 'Inspection' : place,
      generatorKey: generatorProfileKey(
        make: i.generatorMake,
        model: i.generatorModel,
        serial: i.generatorSerial,
      ),
      generatorLabel: _gen(i.generatorMake, i.generatorModel, i.generatorSerial),
    );
    out[c.jobRef] = c;
  }
  for (final m in ref.watch(maintenanceRepoProvider).getAll()) {
    final place = m.address.trim().isEmpty ? m.siteCode : m.address;
    final c = JobContext(
      type: MaterialOwnerType.maintenance,
      id: m.id,
      title: place.isEmpty ? 'Maintenance' : place,
      generatorKey: generatorProfileKey(
        make: m.generatorMake,
        model: m.generatorModel,
        serial: m.generatorSerial,
      ),
      generatorLabel: _gen(m.generatorMake, m.generatorModel, m.generatorSerial),
    );
    out[c.jobRef] = c;
  }
  return out;
});

/// Every saved job list on the device with the generator it was for.
final jobPartsListsProvider =
    FutureProvider.autoDispose<List<JobPartsList>>((ref) async {
  // A hint, not essential: if the device store cannot be read the profile
  // simply shows no usage counts.
  final List<({MaterialOwnerType type, String id, List<MaterialItem> items})>
      lists;
  try {
    lists = await ref.watch(materialsRepositoryProvider).allJobLists();
  } catch (_) {
    return const [];
  }
  final contexts = ref.watch(jobContextsProvider);
  return [
    for (final l in lists)
      JobPartsList(
        type: l.type,
        id: l.id,
        generatorKey: contexts['${l.type.wire}:${l.id}']?.generatorKey ?? '',
        items: l.items,
      ),
  ];
});

/// For one generator (by profile key): part number key -> how many jobs list
/// it. Cheap: one pass over the saved lists.
final generatorPartUsageProvider = FutureProvider.autoDispose
    .family<Map<String, int>, String>((ref, generatorKey) async {
  final lists = await ref.watch(jobPartsListsProvider.future);
  return jobsUsingParts(lists, generatorKey);
});
