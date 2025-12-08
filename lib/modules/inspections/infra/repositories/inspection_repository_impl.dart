import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/email/email_service.dart';
import '../../../../core/services/pdf/pdf_prefs_service.dart';
import '../../../../core/services/pdf/pdf_service.dart';
import '../../../../core/services/storage/export_service.dart';
import '../../domain/entities/inspection_entity.dart';
import '../../domain/entities/nameplate_entity.dart';
import '../../external/drivers/inspection_pdf_driver.dart';
import '../datasources/inspection_local_datasource.dart';
import '../datasources/inspection_remote_datasource.dart';
import 'inspection_repository.dart';

/// Wire the clean repository
final inspectionRepositoryProvider = Provider<InspectionRepository>((ref) {
  final local = ref.watch(inspectionLocalDatasourceProvider);
  final remote = ref.watch(inspectionRemoteDatasourceProvider);

  final pdfDriver = InspectionPdfDriver(
    pdfService: PdfService.instance,
    prefsService: PdfPrefsService.instance,
    emailService: EmailService(),
    exportService: ExportService(),
  );

  return InspectionRepositoryImpl(
    localDatasource: local,
    remoteDatasource: remote,
    pdfDriver: pdfDriver,
  );
});

class InspectionRepositoryImpl implements InspectionRepository {
  final InspectionLocalDatasource localDatasource;
  final InspectionRemoteDatasource remoteDatasource;
  final InspectionPdfDriver pdfDriver;

  InspectionRepositoryImpl({
    required this.localDatasource,
    required this.remoteDatasource,
    required this.pdfDriver,
  });

  @override
  Future<List<InspectionEntity>> listInspections() async {
    // Offline-first: local
    final local = await localDatasource.getAllInspections();

    // Later you can merge with remote or trigger sync here.
    return local;
  }

  @override
  Future<InspectionEntity?> getInspection(String id) {
    return localDatasource.getInspectionById(id);
  }

  @override
  Future<InspectionEntity> createInspection(
      InspectionEntity inspection) async {
    // Local save
    final savedLocal = await localDatasource.saveInspection(inspection);

    // Remote upsert (fire & forget if you like)
    await remoteDatasource.upsertInspection(savedLocal);

    return savedLocal;
  }

  @override
  Future<InspectionEntity> updateInspection(
      InspectionEntity inspection) async {
    final savedLocal = await localDatasource.saveInspection(inspection);
    await remoteDatasource.upsertInspection(savedLocal);
    return savedLocal;
  }

  @override
  Future<void> deleteInspection(String id) async {
    await localDatasource.deleteInspection(id);
    // TODO: also delete remotely if desired.
  }

  @override
  Future<List<NameplateEntity>> listNameplatesForInspection(
      String inspectionId) {
    return localDatasource.getNameplatesForInspection(inspectionId);
  }

  @override
  Future<NameplateEntity> saveNameplate(NameplateEntity entity) {
    return localDatasource.saveNameplate(entity);
  }

  @override
  Future<InspectionEntity> createAndExport(
      InspectionEntity inspection,
      ) async {
    // 1) Save locally + remote WITHOUT pdfPath
    await localDatasource.saveInspection(inspection);
    await remoteDatasource.saveInspection(inspection);

    // 2) Generate PDF + email/export
    final withPdf = await pdfDriver.generateAndExport(inspection);

    // 3) Save updated (with pdfPath)
    await localDatasource.saveInspection(withPdf);
    await remoteDatasource.saveInspection(withPdf);

    return withPdf;
  }

  @override
  Future<InspectionEntity> updateAndExport(
      InspectionEntity inspection,
      ) async {
    // Treat update the same as create for now (upsert semantics)
    await localDatasource.saveInspection(inspection);
    await remoteDatasource.saveInspection(inspection);

    final withPdf = await pdfDriver.generateAndExport(inspection);

    await localDatasource.saveInspection(withPdf);
    await remoteDatasource.saveInspection(withPdf);

    return withPdf;
  }
}
