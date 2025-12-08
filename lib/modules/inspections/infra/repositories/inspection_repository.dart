import '../../domain/entities/inspection_entity.dart';
import '../../domain/entities/nameplate_entity.dart';

abstract class InspectionRepository {
  Future<List<InspectionEntity>> listInspections();
  Future<InspectionEntity?> getInspection(String id);

  /// Create a new inspection, persist it, and (optionally) trigger
  /// PDF generation + export/email.
  Future<InspectionEntity> createAndExport(InspectionEntity inspection);

  /// Update an existing inspection, persist it, and (optionally) trigger
  /// PDF generation + export/email.
  Future<InspectionEntity> updateAndExport(InspectionEntity inspection);

  Future<InspectionEntity> createInspection(InspectionEntity inspection);
  Future<InspectionEntity> updateInspection(InspectionEntity inspection);
  Future<void> deleteInspection(String id);

  Future<List<NameplateEntity>> listNameplatesForInspection(
      String inspectionId,
      );
  Future<NameplateEntity> saveNameplate(NameplateEntity entity);
}
