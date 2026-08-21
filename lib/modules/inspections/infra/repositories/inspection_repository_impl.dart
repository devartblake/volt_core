import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/email/email_service.dart';
import '../../../../core/services/pdf/pdf_prefs_service.dart';
import '../../../../core/services/pdf/pdf_service.dart';
import '../../../../core/services/storage/export_service.dart';
import '../../../../core/services/sync/sync_service.dart';
import '../../domain/entities/inspection_entity.dart';
import '../../domain/entities/nameplate_entity.dart';
import '../../external/drivers/inspection_pdf_driver.dart';
import '../datasources/inspection_local_datasource.dart';
import '../datasources/inspection_remote_datasource.dart';
import 'inspection_repository.dart';

/// Wire the clean repository
final inspectionRepositoryProvider = Provider<InspectionRepository>((ref) {
  final local = ref.watch(inspectionLocalDatasourceProvider);

  final pdfDriver = InspectionPdfDriver(
    pdfService: PdfService.instance,
    prefsService: PdfPrefsService.instance,
    emailService: EmailService(),
    exportService: ExportService(),
  );

  return InspectionRepositoryImpl(
    localDatasource: local,
    pdfDriver: pdfDriver,
  );
});

class InspectionRepositoryImpl implements InspectionRepository {
  final InspectionLocalDatasource localDatasource;
  final InspectionPdfDriver pdfDriver;

  /// No remote datasource: every write to Supabase goes through
  /// [SyncService]'s durable queue so it survives being offline. The field
  /// used to be here, unused, and its constructor reaches for
  /// `Supabase.instance` — which made the repository impossible to build
  /// without a live Supabase connection, including in tests.
  InspectionRepositoryImpl({
    required this.localDatasource,
    required this.pdfDriver,
  });

  static const String _table = InspectionRemoteDatasource.inspectionsTable;

  /// Queue a cloud upsert for [entity]. Offline-first: the local save has
  /// already happened, so this only records intent — [SyncService] pushes it to
  /// Supabase when connectivity allows and never blocks the caller.
  Future<void> _queueUpsert(InspectionEntity entity) {
    return SyncService.instance.enqueueUpsert(
      table: _table,
      id: entity.id,
      payload: InspectionRemoteDatasource.toSupabaseJson(entity),
    );
  }

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
    // Local save first (source of truth), then queue the cloud upsert.
    final savedLocal = await localDatasource.saveInspection(inspection);
    await _queueUpsert(savedLocal);
    return savedLocal;
  }

  @override
  Future<InspectionEntity> updateInspection(
      InspectionEntity inspection) async {
    final savedLocal = await localDatasource.saveInspection(inspection);
    await _queueUpsert(savedLocal);
    return savedLocal;
  }

  @override
  Future<void> deleteInspection(String id) async {
    await localDatasource.deleteInspection(id);
    await SyncService.instance.enqueueDelete(table: _table, id: id);
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
  Future<InspectionEntity> createAndExport(InspectionEntity inspection) =>
      _saveThenExport(inspection);

  @override
  Future<InspectionEntity> updateAndExport(InspectionEntity inspection) =>
      // Upsert semantics: an update is a create that already has an id.
      _saveThenExport(inspection);

  /// Persist the inspection, then render its PDF *without blocking the caller*.
  ///
  /// Rendering a nine-section PDF and writing it to disk takes long enough to
  /// be felt, and none of it is needed for the record to be safe: the local
  /// save and the queued cloud upsert have both already happened by the time
  /// this returns. Awaiting the render here would make "Save" sit behind work
  /// the technician does not need to wait for.
  ///
  /// The PDF lands as a second write to the same Hive record, which is what
  /// the detail page listens for.
  Future<InspectionEntity> _saveThenExport(InspectionEntity inspection) async {
    await localDatasource.saveInspection(inspection);
    await _queueUpsert(inspection);

    unawaited(generatePdf(inspection));

    return inspection;
  }

  @override
  Future<InspectionEntity?> generatePdf(InspectionEntity inspection) async {
    try {
      final withPdf = await pdfDriver.generateAndExport(inspection);
      await localDatasource.saveInspection(withPdf);
      await _queueUpsert(withPdf);
      return withPdf;
    } catch (e, stack) {
      // A failed render must not lose the inspection — it is already saved.
      // `pdfPath` stays empty, which is what the detail page keys its
      // "Generate PDF" action off, so the technician can retry.
      if (kDebugMode) {
        debugPrint('[Inspections] PDF generation failed for '
            '${inspection.id}: $e\n$stack');
      }
      return null;
    }
  }
}
