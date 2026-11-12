import 'package:flutter/foundation.dart';

import '../../inventory/domain/catalog_part.dart';
import 'material_item.dart';

/// One inspection's or maintenance's parts list, with the generator it was
/// for (its profile key; empty when unknown).
@immutable
class JobPartsList {
  const JobPartsList({
    required this.type,
    required this.id,
    required this.generatorKey,
    required this.items,
  });

  final MaterialOwnerType type;
  final String id;
  final String generatorKey;
  final List<MaterialItem> items;
}

/// For one generator: how many of its jobs (inspections and maintenance) list
/// each part number, keyed by [partKey]. A job counts once per part however
/// many times the part appears in it.
Map<String, int> jobsUsingParts(
  Iterable<JobPartsList> lists,
  String generatorKey,
) {
  if (generatorKey.isEmpty) return const {};
  final counts = <String, int>{};
  for (final l in lists) {
    if (l.generatorKey != generatorKey) continue;
    final seen = <String>{};
    for (final i in l.items) {
      final k = partKey(i.partNumber);
      if (k.isNotEmpty && seen.add(k)) counts[k] = (counts[k] ?? 0) + 1;
    }
  }
  return counts;
}

/// "Used on 3 jobs", or an empty string when it is on none.
String usedOnLabel(int jobs) =>
    jobs <= 0 ? '' : 'Used on $jobs ${jobs == 1 ? 'job' : 'jobs'}';
