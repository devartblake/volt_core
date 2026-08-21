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

  /// Render (or re-render) the PDF for an already-saved inspection.
  ///
  /// Returns the inspection with `pdfPath` set, or null if rendering failed.
  /// Exposed so the detail page can produce a PDF for records that have none —
  /// every inspection saved before the export path was wired up, plus any
  /// whose background render failed.
  Future<InspectionEntity?> generatePdf(InspectionEntity inspection);

  Future<InspectionEntity> createInspection(InspectionEntity inspection);
  Future<InspectionEntity> updateInspection(InspectionEntity inspection);
  Future<void> deleteInspection(String id);

  Future<List<NameplateEntity>> listNameplatesForInspection(
      String inspectionId,
      );
  Future<NameplateEntity> saveNameplate(NameplateEntity entity);
}
