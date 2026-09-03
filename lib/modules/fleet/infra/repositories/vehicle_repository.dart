import '../../domain/entities/vehicle_entity.dart';

abstract class VehicleRepository {
  /// Vehicles in the active tenant.
  ///
  /// [assignedToUserId] narrows to one technician's vehicle. The caller decides
  /// whether to pass it — see `fleetVisibleVehiclesProvider`, which passes it
  /// for a tech and omits it for a manager. RLS enforces the same rule
  /// server-side; this is the local mirror of it, not the authority.
  Future<List<VehicleEntity>> list({String? assignedToUserId});

  Future<VehicleEntity?> getById(String id);

  Future<VehicleEntity> save(VehicleEntity vehicle);

  /// Assign or unassign the technician stationed to a vehicle.
  Future<VehicleEntity> assign(String vehicleId, String? userId);
}
