import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/pdf/pdf_prefs_service.dart';
import '../../../../core/services/pdf/pdf_service.dart';
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
    final m = MaintenanceRecord(id: id, inspectionId: inspectionId);
    _box.put(id, m);
    _queueUpsert(m);
    return m;
  }

  MaintenanceRecord? getById(String id) => _box.get(id);

  /// Cache a record retrieved from Supabase without changing timestamps or
  /// enqueueing another write. This is used for schedule-source recovery.
  Future<void> cacheRemote(MaintenanceRecord record) =>
      _box.put(record.id, record);

  Future<void> save(MaintenanceRecord rec) async {
    rec.updatedAt = DateTime.now();
    await rec.save();
    await _queueUpsert(rec);
  }

  Future<void> delete(String id) async {
    await _box.delete(id);
    await enqueueMaintenanceDelete(id);
  }

  /// Queue the cloud sync of the record (offline-first). Best-effort so a
  /// backup hiccup never breaks the local Hive write.
  Future<void> _queueUpsert(MaintenanceRecord rec) =>
      enqueueMaintenanceSync(rec);

  Future<void> exportMaintenancePdf(MaintenanceRecord record) async {
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
      record,
      prefs: exportPrefs,
    );
  }
}
