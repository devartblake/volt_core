import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/pdf/pdf_prefs_service.dart';
import '../../../../core/services/pdf/pdf_service.dart';
import '../../../../core/services/photos/photo_attachment.dart';
import '../../../../core/services/photos/photo_service.dart';
import '../../../../core/services/storage/pdf_library_service.dart';
import '../datasources/hive_boxes_maintenance.dart';
import '../mappers/maintenance_supabase_mapper.dart';
import '../models/maintenance_record.dart';

class MaintenanceRepo {
  /// Only set when a box is injected (tests). Otherwise the box is resolved
  /// per use, so a HiveService reset cannot leave this repository holding a
  /// closed one for the rest of the session.
  final Box<MaintenanceRecord>? _injectedBox;
  final _uuid = const Uuid();
  final PdfService _pdfService;

  MaintenanceRepo({
    Box<MaintenanceRecord>? box,
    PdfService? pdfService,
  })  : _injectedBox = box,
        _pdfService = pdfService ?? PdfService.instance;

  Box<MaintenanceRecord> get _box => _injectedBox ?? MaintenanceBoxes.maintenance;

  List<MaintenanceRecord> getAll() {
    final list = _box.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  MaintenanceRecord createNew({String? inspectionId}) {
    final id = _uuid.v4();
    // The service date starts as today (the technician can change it), so a
    // record is never left without one.
    final m = MaintenanceRecord(
      id: id,
      inspectionId: inspectionId,
      dateOfService: DateTime.now(),
    );
    _box.put(id, m);
    _queueUpsert(m);
    return m;
  }

  MaintenanceRecord? getById(String id) => _box.get(id);

  /// Cache a record retrieved from Supabase without changing timestamps or
  /// enqueueing another write. This is used for schedule-source recovery.
  Future<void> cacheRemote(MaintenanceRecord record) =>
      _box.put(record.id, record);

  /// Adds records that exist in the cloud but not on this device (for example
  /// ones created on another tablet, or lost to a cache reset). Never touches
  /// a record already here, so local edits are safe. Returns how many were
  /// added.
  Future<int> restoreMissing(Iterable<MaintenanceRecord> remote) async {
    var added = 0;
    for (final record in remote) {
      if (_box.containsKey(record.id)) continue;
      await _box.put(record.id, record);
      added++;
    }
    return added;
  }

  Future<void> save(MaintenanceRecord rec) async {
    rec.updatedAt = DateTime.now();
    await rec.save();
    await _queueUpsert(rec);
  }

  /// Writes the in-progress record to this device only.
  ///
  /// Used by the form's autosave so a half-finished record survives the app
  /// being closed or killed. It deliberately skips the sync queue: the cloud
  /// copy is queued by [save] when the technician finishes.
  Future<void> saveDraft(MaintenanceRecord rec) async {
    rec.updatedAt = DateTime.now();
    await rec.save();
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
    await enqueueMaintenanceDelete(id);
  }

  /// Puts a record removed by [delete] back (undo). Re-queues the cloud
  /// upsert so the cloud copy follows the local one again.
  Future<void> restore(MaintenanceRecord rec) async {
    await _box.put(rec.id, rec);
    await _queueUpsert(rec);
  }

  /// Queue the cloud sync of the record (offline-first). Best-effort so a
  /// backup hiccup never breaks the local Hive write.
  Future<void> _queueUpsert(MaintenanceRecord rec) =>
      enqueueMaintenanceSync(rec);

  /// Generates the report PDF for [record] and stores it in the managed PDF
  /// library (so it also shows up under Documents).
  ///
  /// [share] opens the share sheet when the user has allowed emailing. Pass
  /// false for the automatic post-save report so saving never pops a sheet.
  /// Whether a saved report is still an accurate print of the record.
  ///
  /// It is not if the record was saved after the file was written, or a photo
  /// was added after that (photos are stored apart from the record). A
  /// deleted photo cannot be detected, which is the one known gap.
  static bool isSavedPdfCurrent({
    required DateTime pdfModified,
    required DateTime recordUpdated,
    DateTime? newestPhoto,
  }) {
    if (pdfModified.isBefore(recordUpdated)) return false;
    if (newestPhoto != null && pdfModified.isBefore(newestPhoto)) return false;
    return true;
  }

  /// The report already generated for [record], if one exists and is still
  /// current, so printing does not have to build a new PDF every time.
  Future<PdfExportResult?> findSavedMaintenancePdf(
    MaintenanceRecord record,
  ) async {
    final suffix = '_${PdfService.maintenanceShortId(record.id)}.pdf';

    PdfDocumentInfo? newest;
    for (final doc in await PdfLibraryService.instance.listDocuments()) {
      if (doc.category != PdfCategory.maintenance) continue;
      if (!doc.name.endsWith(suffix)) continue;
      if (newest == null || doc.modified.isAfter(newest.modified)) newest = doc;
    }
    if (newest == null) return null;

    DateTime? newestPhoto;
    try {
      final photos = await PhotoService.instance
          .listForOwner(PhotoAttachment.ownerMaintenance, record.id);
      for (final photo in photos) {
        if (newestPhoto == null || photo.createdAt.isAfter(newestPhoto)) {
          newestPhoto = photo.createdAt;
        }
      }
    } catch (_) {
      // Photos are an optional extra; judge by the record alone.
    }

    final current = isSavedPdfCurrent(
      pdfModified: newest.modified,
      recordUpdated: record.updatedAt,
      newestPhoto: newestPhoto,
    );
    return current ? PdfExportResult(filePath: newest.path) : null;
  }

  Future<PdfExportResult> exportMaintenancePdf(
    MaintenanceRecord record, {
    bool share = true,
  }) async {
    final prefsService = PdfPrefsService.instance;
    final emailAllowed = await prefsService.getEmailAllowed();
    final customDir = await prefsService.getCustomDirectoryPath();
    final defaultRecipient = await prefsService.getDefaultRecipient();

    final exportPrefs = PdfExportPrefs(
      emailAllowed: share && emailAllowed,
      customDirectoryPath: customDir,
      defaultRecipient: defaultRecipient,
      appSubfolder: 'AandSElectric/Maintenance',
    );

    return _pdfService.generateMaintenancePdf(
      record,
      prefs: exportPrefs,
    );
  }
}
