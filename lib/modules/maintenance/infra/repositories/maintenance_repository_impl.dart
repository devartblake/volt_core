import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/pdf/pdf_prefs_service.dart';
import '../../../../core/services/pdf/pdf_service.dart';
import '../../domain/entities/maintenance_job_entity.dart';
import '../datasources/hive_boxes_maintenance.dart';
import '../models/maintenance_record.dart';
import '../../domain/repositories/maintenance_repository.dart';

/// Hive-backed implementation of [MaintenanceRepository].
///
/// This bridges your detailed [MaintenanceRecord] Hive model
/// and the lighter [MaintenanceJobEntity] used by the domain/UI.
class MaintenanceRepositoryImpl implements MaintenanceRepository {
  final Box<MaintenanceRecord> _box;
  final PdfService _pdfService;
  final _uuid = const Uuid();

  MaintenanceRepositoryImpl({
    Box<MaintenanceRecord>? box,
    PdfService? pdfService,
  })  : _box = box ?? MaintenanceBoxes.maintenance,
        _pdfService = pdfService ?? PdfService.instance;

  // ---------------------------------------------------------------------------
  // Mapping helpers
  // ---------------------------------------------------------------------------

  MaintenanceJobEntity _toEntity(MaintenanceRecord rec) {
    final title = rec.siteCode.isNotEmpty
        ? 'Site ${rec.siteCode}'
        : (rec.address.isNotEmpty ? rec.address : 'Maintenance Job');

    return MaintenanceJobEntity(
      id: rec.id,
      inspectionId: rec.inspectionId,
      createdAt: rec.createdAt,
      updatedAt: rec.updatedAt,
      isCompleted: rec.completed,
      // We don’t have a dedicated completedAt; use updatedAt when completed.
      completedAt: rec.completed ? rec.updatedAt : null,
      requiresFollowUp: rec.requiresFollowUp,
      followUpNotes: rec.followUpNotes,
      siteCode: rec.siteCode,
      address: rec.address,
      technicianName: rec.technicianName,
      generalNotes: rec.generalNotes,
      title: title,
    );
  }

  void _applyEntityToRecord(
      MaintenanceJobEntity job,
      MaintenanceRecord rec,
      ) {
    rec
      ..inspectionId = job.inspectionId
      ..siteCode = job.siteCode
      ..address = job.address
      ..technicianName = job.technicianName
      ..generalNotes = job.generalNotes ?? rec.generalNotes
      ..completed = job.isCompleted
      ..requiresFollowUp = job.requiresFollowUp
      ..followUpNotes = job.followUpNotes ?? rec.followUpNotes
      ..updatedAt = job.updatedAt ?? DateTime.now();
    // completedAt is not persisted separately – we treat updatedAt as completion time.
    // title is computed from siteCode/address; no dedicated field in Hive.
  }

  // ---------------------------------------------------------------------------
  // Repository methods
  // ---------------------------------------------------------------------------

  @override
  Future<List<MaintenanceJobEntity>> listAll() async {
    final records = _box.values.toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return records.map(_toEntity).toList();
  }

  @override
  Future<MaintenanceJobEntity?> getById(String id) async {
    final rec = _box.get(id);
    if (rec == null) return null;
    return _toEntity(rec);
  }

  @override
  Future<MaintenanceJobEntity> createDraft({String? inspectionId}) async {
    final id = _uuid.v4();
    final now = DateTime.now();

    final rec = MaintenanceRecord(
      id: id,
      inspectionId: inspectionId,
    )
      ..createdAt = now
      ..updatedAt = now;

    await _box.put(id, rec);
    return _toEntity(rec);
  }

  @override
  Future<void> save(MaintenanceJobEntity job) async {
    final existing = _box.get(job.id);
    if (existing == null) {
      final rec = MaintenanceRecord(
        id: job.id,
        inspectionId: job.inspectionId,
        siteCode: job.siteCode,
        address: job.address,
        technicianName: job.technicianName,
        generalNotes: job.generalNotes ?? '',
        completed: job.isCompleted,
        requiresFollowUp: job.requiresFollowUp,
        followUpNotes: job.followUpNotes ?? '',
        createdAt: job.createdAt,
        updatedAt: job.updatedAt ?? DateTime.now(),
      );

      await _box.put(job.id, rec);
    } else {
      _applyEntityToRecord(job, existing);
      await existing.save();
    }
  }

  @override
  Future<void> delete(String id) async {
    await _box.delete(id);
  }

  @override
  Future<void> exportPdf(String id) async {
    final rec = _box.get(id);
    if (rec == null) return;

    final prefsService = PdfPrefsService.instance;
    final emailAllowed = await prefsService.getEmailAllowed();
    final customDir = await prefsService.getCustomDirectoryPath();
    final defaultRecipient = await prefsService.getDefaultRecipient();

    final exportPrefs = PdfExportPrefs(
      emailAllowed: emailAllowed,
      customDirectoryPath: customDir,
      defaultRecipient: defaultRecipient,
      appSubfolder: 'AandSElectric/Maintenance',
    );

    await _pdfService.generateMaintenancePdf(
      rec,
      prefs: exportPrefs,
    );
  }

  @override
  Future<void> completeJob(String id, {DateTime? completedAt}) async {
    final rec = _box.get(id);
    if (rec == null) return;

    rec.completed = true;
    rec.updatedAt = completedAt ?? DateTime.now();
    await rec.save();
  }
}
