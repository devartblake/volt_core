import '../../domain/entities/equipment_entity.dart';

/// Read model for the equipment registry.
abstract class EquipmentRepository {
  /// Every generator known from the inspection history, newest inspection
  /// first. One entry per physical unit, not per inspection.
  Future<List<EquipmentEntity>> listEquipment();

  /// The distinct makes / voltages / locations present, for filter chips.
  Future<EquipmentFacets> facets();
}

/// Filter values actually present in the data, so the UI never offers a filter
/// that would return nothing.
class EquipmentFacets {
  const EquipmentFacets({
    this.makes = const [],
    this.voltages = const [],
    this.locations = const [],
  });

  final List<String> makes;
  final List<String> voltages;
  final List<String> locations;

  bool get isEmpty =>
      makes.isEmpty && voltages.isEmpty && locations.isEmpty;
}
