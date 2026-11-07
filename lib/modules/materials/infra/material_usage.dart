import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/sync/sync_context.dart';
import '../../inventory/domain/catalog_part.dart';
import '../../inventory/domain/inventory_location.dart';
import '../../inventory/domain/stock.dart';
import '../../inventory/infra/inventory_repository.dart';
import '../domain/material_item.dart';
import 'materials_repository.dart';

enum UsageOutcome {
  /// Stock was taken from [UsageResult.locationName].
  issued,

  /// Already marked: nothing changed.
  alreadyUsed,

  /// The part is not in the catalog (or has no quantity): only the date.
  dateOnly,

  /// Stock was put back.
  returned,

  /// Undo with nothing to undo on this device.
  nothingToReturn,
}

class UsageResult {
  const UsageResult(this.item, this.outcome, {this.locationName = ''});

  final MaterialItem item;
  final UsageOutcome outcome;
  final String locationName;

  String get message => switch (outcome) {
        UsageOutcome.issued => 'Marked used. Taken from $locationName.',
        UsageOutcome.alreadyUsed => 'Already marked as used.',
        UsageOutcome.dateOnly =>
          'Marked used. This part is not in the parts catalog, so only the '
              'date was recorded and no stock changed.',
        UsageOutcome.returned => 'Put back in stock at $locationName.',
        UsageOutcome.nothingToReturn =>
          'Cleared. The original stock entry is not on this device, so no '
              'stock was put back.',
      };
}

/// "Technician confirms what they used": turns a materials line into a ledger
/// issue (and back again), once.
///
/// Stock comes off the signed-in person's assigned truck when it holds enough
/// of the part, otherwise off the main warehouse.
class MaterialUsageService {
  MaterialUsageService(
    this._inventory, {
    String? Function()? userId,
    DateTime Function()? today,
  })  : _userId = userId ?? (() => SyncContext.userId),
        _today = today ?? DateTime.now;

  final InventoryRepository _inventory;
  final String? Function() _userId;
  final DateTime Function() _today;

  static String jobRefFor(MaterialOwner owner) =>
      '${owner.type.wire}:${owner.key}';

  Future<UsageResult> markUsed(MaterialOwner owner, MaterialItem item) async {
    if (item.usedMovementId != null) {
      return UsageResult(item, UsageOutcome.alreadyUsed);
    }
    final withDate = item.dateUsed == null
        ? item.copyWith(dateUsed: _dateOnly(_today()))
        : item;

    final part = item.hasPartNumber
        ? findPartByNumber(await _inventory.parts(), item.partNumber)
        : null;
    if (part == null || item.quantity <= 0) {
      return UsageResult(withDate, UsageOutcome.dateOnly);
    }

    final moves = await _inventory.movements(partId: part.id);
    final location = await _sourceFor(moves, part.id, item.quantity);
    final m = await _inventory.recordAt(
      locationId: location.id,
      partId: part.id,
      qty: -item.quantity,
      reason: MovementReason.issue,
      jobRef: jobRefFor(owner),
      note: 'Used on job',
    );
    if (m == null) return UsageResult(withDate, UsageOutcome.dateOnly);
    return UsageResult(
      withDate.copyWith(usedMovementId: m.id),
      UsageOutcome.issued,
      locationName: location.name,
    );
  }

  /// Puts the stock back (a return at the same location) and clears the mark.
  Future<UsageResult> undoUsed(MaterialOwner owner, MaterialItem item) async {
    final id = item.usedMovementId;
    if (id == null) return UsageResult(item, UsageOutcome.alreadyUsed);
    final cleared = item.copyWith(usedMovementId: null);
    final original = await _inventory.movementById(id);
    if (original == null) {
      return UsageResult(cleared, UsageOutcome.nothingToReturn);
    }
    await _inventory.recordAt(
      locationId: original.locationId,
      partId: original.partId,
      qty: -original.qtyDelta,
      reason: MovementReason.returned,
      jobRef: jobRefFor(owner),
      note: 'Usage undone',
    );
    final names = {
      for (final l in await _inventory.locations(includeInactive: true))
        l.id: l.name,
    };
    return UsageResult(cleared, UsageOutcome.returned,
        locationName: names[original.locationId] ?? 'the warehouse');
  }

  Future<InventoryLocation> _sourceFor(
    List<InventoryMovement> moves,
    String partId,
    int qty,
  ) async {
    final me = _userId();
    if (me != null && me.isNotEmpty) {
      for (final l in await _inventory.locations()) {
        if (l.isTruck &&
            l.assignedUserId == me &&
            onHandAt(moves, partId, l.id) >= qty) {
          return l;
        }
      }
    }
    return InventoryLocation.main();
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

final materialUsageServiceProvider = Provider<MaterialUsageService>(
  (ref) => MaterialUsageService(ref.watch(inventoryRepositoryProvider)),
);
