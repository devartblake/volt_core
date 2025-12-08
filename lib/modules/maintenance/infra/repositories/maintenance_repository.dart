import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/pdf/pdf_prefs_service.dart';
import '../../../../core/services/pdf/pdf_service.dart';
import '../datasources/hive_boxes_maintenance.dart';
import '../models/maintenance_record.dart';

class MaintenanceRepo {
  final Box<MaintenanceRecord> _box;
  final _uuid = const Uuid();
  final PdfService _pdfService;

  MaintenanceRepo({
    Box<MaintenanceRecord>? box,
    PdfService? pdfService,
  })  : _box = box ?? MaintenanceBoxes.maintenance,
  // FIXED: use singleton instead of nonexistent constructor
        _pdfService = pdfService ?? PdfService.instance;

  List<MaintenanceRecord> getAll() {
    final list = _box.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  MaintenanceRecord createNew({String? inspectionId}) {
    final id = _uuid.v4();
    final m = MaintenanceRecord(id: id, inspectionId: inspectionId);
    _box.put(id, m);
    return m;
  }

  MaintenanceRecord? getById(String id) => _box.get(id);

  Future<void> save(MaintenanceRecord rec) async {
    rec.updatedAt = DateTime.now();
    await rec.save();
  }

  Future<void> delete(String id) => _box.delete(id);

  /// Properly wired PDF export with Hive-backed prefs.
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
