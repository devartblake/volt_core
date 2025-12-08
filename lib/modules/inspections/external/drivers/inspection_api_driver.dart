
import '../../domain/entities/inspection_entity.dart';
import '../../infra/datasources/inspection_remote_datasource.dart';

/// High-level API driver for inspection sync / server communication.
///
/// For now it just passes through to [InspectionRemoteDatasource].
class InspectionApiDriver {
  final InspectionRemoteDatasource _remote;

  InspectionApiDriver({InspectionRemoteDatasource? remote})
      : _remote = remote ?? InspectionRemoteDatasource();

  Future<List<InspectionEntity>> fetchAllInspections() async {
    return _remote.fetchInspections();
  }

  Future<InspectionEntity> upsertInspection(InspectionEntity entity) {
    return _remote.upsertInspection(entity);
  }
}
