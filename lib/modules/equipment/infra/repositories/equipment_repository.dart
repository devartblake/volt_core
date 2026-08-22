import '../../domain/entities/equipment_entity.dart';

/// Read model for the equipment registry.
abstract class EquipmentRepository {
  /// Every known asset, newest inspection first when one exists. One entry per
  /// physical unit, not per inspection.
  Future<List<EquipmentEntity>> listEquipment();

  /// The distinct makes / voltages / locations present, for filter chips.
  Future<EquipmentFacets> facets();

  /// Registers an asset that has not yet been inspected.
  ///
  /// The write uses the durable sync queue, so field teams can register an
  /// asset before they regain connectivity. A later inspection will merge into
  /// this row through its stable identity key.
  Future<EquipmentEntity> registerAsset({
    required String name,
    required AssetType assetType,
    required String make,
    required String model,
    required String serialNumber,
    required String voltage,
    required String location,
    required String siteCode,
    String notes = '',
  });
}

/// Filter values actually present in the data, so the UI never offers a filter
/// that would return nothing.
class EquipmentFacets {
  const EquipmentFacets({
    this.makes = const [],
    this.voltages = const [],
    this.locations = const [],
    this.assetTypes = const [],
  });

  final List<String> makes;
  final List<String> voltages;
  final List<String> locations;
  final List<AssetType> assetTypes;

  bool get isEmpty =>
      makes.isEmpty &&
      voltages.isEmpty &&
      locations.isEmpty &&
      assetTypes.isEmpty;
}
