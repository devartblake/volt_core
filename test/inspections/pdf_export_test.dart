import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/core/services/email/email_service.dart';
import 'package:voltcore/core/services/hive/hive_boxes.dart';
import 'package:voltcore/core/services/pdf/pdf_prefs_service.dart';
import 'package:voltcore/core/services/pdf/pdf_service.dart';
import 'package:voltcore/core/services/storage/export_service.dart';
import 'package:voltcore/core/services/sync/sync_queue.dart';
import 'package:voltcore/modules/inspections/domain/entities/inspection_entity.dart';
import 'package:voltcore/modules/inspections/external/drivers/inspection_pdf_driver.dart';
import 'package:voltcore/modules/inspections/infra/datasources/inspection_local_datasource.dart';
import 'package:voltcore/modules/inspections/infra/models/inspection.dart';
import 'package:voltcore/modules/inspections/infra/models/nameplate_data.dart';
import 'package:voltcore/modules/inspections/infra/repositories/inspection_repository_impl.dart';

/// A PDF driver whose render only finishes when the test says so.
class _ControllablePdfDriver extends InspectionPdfDriver {
  _ControllablePdfDriver()
      : super(
          pdfService: PdfService.instance,
          prefsService: PdfPrefsService.instance,
          emailService: EmailService(),
          exportService: ExportService(),
        );

  final started = Completer<void>();
  final _finish = Completer<String>();
  int calls = 0;

  void finishWith(String path) => _finish.complete(path);
  void failWith(Object error) => _finish.completeError(error);

  @override
  Future<InspectionEntity> generateAndExport(InspectionEntity inspection) async {
    calls++;
    if (!started.isCompleted) started.complete();
    final path = await _finish.future;
    return inspection.copyWith(pdfPath: path);
  }
}

/// Waits for the background render's follow-up Hive write to land.
///
/// The write happens in an unawaited future, so there is no handle to await —
/// poll rather than guess a fixed number of microtasks.
Future<InspectionEntity?> _awaitSettled(
  Future<InspectionEntity?> Function() read, {
  required bool Function(InspectionEntity?) until,
}) async {
  for (var i = 0; i < 100; i++) {
    final value = await read();
    if (until(value)) return value;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  return read();
}

/// Lets the unawaited background work (the render's follow-up write and the
/// queued upsert) finish before the next test starts.
Future<void> _settleBackgroundWrites() async {
  var last = -1;
  for (var i = 0; i < 40; i++) {
    final n = (await SyncQueue.instance.all()).length;
    if (n == last) return;
    last = n;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  // One temp folder for the whole file. Deleting it between tests raced with
  // background writes still running from the previous test (a pending render
  // keeps going after its test ends), which then tried to open
  // `sync_queue.hive` in a folder that no longer existed and failed whichever
  // test was running at the time.
  late Directory tempDir;
  late _ControllablePdfDriver driver;
  late InspectionRepositoryImpl repo;

  setUpAll(() async {
    Hive.registerAdapter(InspectionAdapter());
    Hive.registerAdapter(NameplateDataAdapter());
    tempDir = Directory.systemTemp.createTempSync('voltcore_pdf_test');
    Hive.init(tempDir.path);
    HiveBoxes.inspections = await Hive.openBox<Inspection>('inspections');
  });

  setUp(() async {
    await HiveBoxes.inspections.clear();
    await SyncQueue.instance.clear();

    driver = _ControllablePdfDriver();
    repo = InspectionRepositoryImpl(
      localDatasource: InspectionLocalDatasource(),
      pdfDriver: driver,
    );
  });

  tearDown(_settleBackgroundWrites);

  tearDownAll(() async {
    await _settleBackgroundWrites();
    await Hive.close();
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  test('createAndExport returns before the PDF has rendered', () async {
    // The regression this guards: generating the PDF inline made "Save" sit
    // behind a full nine-section render. The record is already safe once the
    // local write and the queued upsert are done.
    final entity = InspectionEntity.newDraft().copyWith(
      siteCode: 'SITE-42',
      address: '120 Wall St',
    );

    final returned = await repo.createAndExport(entity);

    // Returned while the render is still in flight.
    await driver.started.future;
    expect(driver.calls, 1);
    expect(returned.id, entity.id);

    // And the inspection is already persisted, without a pdfPath yet.
    final savedNow = await repo.getInspection(entity.id);
    expect(savedNow, isNotNull);
    expect(savedNow!.siteCode, 'SITE-42');
    expect(savedNow.pdfPath, isEmpty);
  });

  test('the rendered path lands as a second write', () async {
    final entity = InspectionEntity.newDraft().copyWith(siteCode: 'SITE-42');

    await repo.createAndExport(entity);
    await driver.started.future;

    driver.finishWith('/tmp/inspection.pdf');

    final saved = await _awaitSettled(
      () => repo.getInspection(entity.id),
      until: (i) => i != null && i.pdfPath.isNotEmpty,
    );
    expect(saved!.pdfPath, '/tmp/inspection.pdf');
  });

  test('a failed render leaves the inspection saved and reports null',
      () async {
    // A PDF failure must never cost the technician the inspection itself.
    final entity = InspectionEntity.newDraft().copyWith(siteCode: 'SITE-42');
    await repo.createAndExport(entity);
    await driver.started.future;

    driver.failWith(StateError('disk full'));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final saved = await repo.getInspection(entity.id);
    expect(saved, isNotNull, reason: 'the inspection must survive');
    expect(saved!.siteCode, 'SITE-42');
    expect(saved.pdfPath, isEmpty);
  });

  test('generatePdf can render one for a record that has none', () async {
    // How every inspection saved before the export path was wired up — and
    // any whose background render failed — gets a document.
    final entity = InspectionEntity.newDraft().copyWith(siteCode: 'LEGACY-1');
    await repo.createInspection(entity);
    expect((await repo.getInspection(entity.id))!.pdfPath, isEmpty);

    final future = repo.generatePdf(entity);
    await driver.started.future;
    driver.finishWith('/tmp/legacy.pdf');

    final result = await future;
    expect(result, isNotNull);
    expect((await repo.getInspection(entity.id))!.pdfPath, '/tmp/legacy.pdf');
  });

  test('generatePdf returns null rather than throwing when rendering fails',
      () async {
    final entity = InspectionEntity.newDraft().copyWith(siteCode: 'LEGACY-2');
    await repo.createInspection(entity);

    final future = repo.generatePdf(entity);
    await driver.started.future;
    driver.failWith(StateError('no template'));

    expect(await future, isNull);
  });
}
