import '../../materials/infra/materials_repository.dart';
import '../domain/import/parts_import.dart';
import '../domain/stock.dart';
import 'inventory_repository.dart';

class ImportResult {
  const ImportResult({
    this.added = 0,
    this.filled = 0,
    this.stocked = 0,
    this.failed = const [],
  });

  final int added;
  final int filled;

  /// Parts that got an opening-stock entry.
  final int stocked;

  /// Part numbers that could not be saved.
  final List<String> failed;
}

/// Saves the chosen rows of an import plan.
///
/// New parts are added. Existing parts only have blank fields filled in, never
/// overwritten, so importing the same file twice changes nothing the second
/// time. Opening stock is recorded only for parts added by this import, for the
/// same reason.
Future<ImportResult> applyImport(
  InventoryRepository repo,
  List<PlannedPart> plan, {
  required Set<String> selected,
  bool openingStock = false,
}) async {
  var added = 0, filled = 0, stocked = 0;
  final failed = <String>[];
  for (final item in plan) {
    final p = item.part;
    if (!selected.contains(p.key) || item.action == ImportAction.same) continue;
    try {
      if (item.action == ImportAction.add) {
        final saved = await repo.savePart(repo.newPart(
          partNumber: p.partNumber,
          name: p.name,
          manufacturer: p.manufacturer,
          slot: p.slot,
          minStock: p.minStock,
          altPartNumbers: p.alternates,
          notes: p.notes,
        ));
        added++;
        final qty = p.openingQty ?? 0;
        if (openingStock && qty > 0) {
          await repo.record(
            partId: saved.id,
            qty: qty,
            reason: MovementReason.receive,
            note: 'Opening stock (spreadsheet import)',
          );
          stocked++;
        }
      } else {
        final e = item.existing!;
        await repo.savePart(e.copyWith(
          manufacturer: e.manufacturer.isEmpty ? p.manufacturer : null,
          name: e.name.isEmpty ? p.name : null,
          slot: e.slot ?? p.slot,
          minStock: e.minStock == 0 ? p.minStock : null,
        ));
        filled++;
      }
    } catch (_) {
      failed.add(p.partNumber);
    }
  }
  return ImportResult(added: added, filled: filled, stocked: stocked, failed: failed);
}

MaterialOwner _owner(GeneratorImport g) => MaterialOwner.generator(
    key: g.key, make: g.make, model: g.model, serial: g.serial);

/// Keys of the generators that already have a parts profile on this device.
/// An import never replaces one.
Future<Set<String>> generatorsWithProfile(
  MaterialsRepository repo,
  List<GeneratorImport> gens,
) async {
  final have = <String>{};
  for (final g in gens) {
    if ((await repo.load(_owner(g))).isNotEmpty) have.add(g.key);
  }
  return have;
}

/// Saves the chosen generators' parts lists. Returns how many were saved and
/// the sites that could not be.
Future<({int saved, List<String> failed})> applyGeneratorProfiles(
  MaterialsRepository repo,
  List<GeneratorImport> gens, {
  required Set<String> selected,
}) async {
  var saved = 0;
  final failed = <String>[];
  for (final g in gens) {
    if (!selected.contains(g.key)) continue;
    try {
      await repo.save(_owner(g), g.items);
      saved++;
    } catch (_) {
      failed.add(g.site);
    }
  }
  return (saved: saved, failed: failed);
}
