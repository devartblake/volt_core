import 'package:uuid/uuid.dart';

/// A *type* of tool the company carries — "IDEAL ½ EMT BENDER", part 74-031.
///
/// Distinct from [VehicleAsset], which is one physical instance of this in one
/// van. The split is what stops the same bender being typed five slightly
/// different ways across five vans, which makes "where are all our benders?"
/// unanswerable.
class VehicleAssetCatalogItem {
  const VehicleAssetCatalogItem({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.partNumber,
    this.category = '',
    this.notes = '',
    this.isActive = true,
  });

  factory VehicleAssetCatalogItem.newDraft({required String tenantId}) {
    final now = DateTime.now().toUtc();
    return VehicleAssetCatalogItem(
      id: const Uuid().v4(),
      tenantId: tenantId,
      name: '',
      createdAt: now,
      updatedAt: now,
    );
  }

  final String id;
  final String tenantId;
  final String name;

  /// Manufacturer part number. Null rather than '' when unknown — several
  /// items on the paper form have none, and '' would collide them all with
  /// each other on the partial unique index.
  final String? partNumber;

  final String category;
  final String notes;

  /// Deactivated rather than deleted once vans carry it — the foreign key is
  /// `on delete restrict`, because removing a catalog entry would orphan real
  /// tools.
  final bool isActive;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// "IDEAL ½ EMT BENDER · 74-031", or just the name when there is no part
  /// number. Used wherever one line has to identify the tool.
  String get displayLabel => partNumber == null || partNumber!.trim().isEmpty
      ? name.trim()
      : '${name.trim()} · ${partNumber!.trim()}';

  VehicleAssetCatalogItem copyWith({
    String? name,
    String? partNumber,
    bool clearPartNumber = false,
    String? category,
    String? notes,
    bool? isActive,
    DateTime? updatedAt,
  }) {
    return VehicleAssetCatalogItem(
      id: id,
      tenantId: tenantId,
      name: name ?? this.name,
      partNumber: clearPartNumber ? null : (partNumber ?? this.partNumber),
      category: category ?? this.category,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

/// Normalise a part number for comparison: upper case, trimmed.
///
/// The unique index does the same, so doing it here means a duplicate is
/// caught at the keyboard rather than coming back as an opaque 23505.
String normalizePartNumber(String? raw) => (raw ?? '').trim().toUpperCase();
