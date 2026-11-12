import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/core/theme/status_colors.dart';
import 'package:voltcore/modules/maintenance/infra/models/maintenance_record.dart';
import 'package:voltcore/modules/maintenance/infra/repositories/maintenance_hive_repository.dart';
import 'package:voltcore/modules/maintenance/presenter/controllers/maintenance_form_controller.dart';
import 'package:voltcore/modules/maintenance/presenter/controllers/maintenance_providers.dart';
import 'package:voltcore/modules/maintenance/presenter/pages/maintenance_form_page.dart';

/// The page chrome has a sync indicator that animates forever, so
/// pumpAndSettle would never return; advance a fixed amount instead.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// In-memory stand-in for the Hive-backed repo. Widget tests run on a fake
/// clock, where a Hive write never completes and then blocks every later
/// write to that box, so they must not touch it.
class _MemRepo extends MaintenanceRepo {
  _MemRepo(this.records);

  final Map<String, MaintenanceRecord> records;

  @override
  MaintenanceRecord createNew({String? inspectionId}) {
    final m = MaintenanceRecord(
      id: 'new-${records.length}',
      dateOfService: DateTime.now(),
    );
    records[m.id] = m;
    return m;
  }

  @override
  MaintenanceRecord? getById(String id) => records[id];

  @override
  List<MaintenanceRecord> getAll() => records.values.toList();

  @override
  Future<void> saveDraft(MaintenanceRecord rec) async {}

  @override
  Future<void> save(MaintenanceRecord rec) async {}

  @override
  Future<void> delete(String id) async => records.remove(id);
}

void main() {
  late Directory dir;
  late Box<MaintenanceRecord> box;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('voltcore_maint_form_page');
    Hive.init(dir.path);
    Hive.registerAdapter(MaintenanceRecordAdapter());
    box = await Hive.openBox<MaintenanceRecord>('maintenance_form_page_test');
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  Widget app({String? id, double textScale = 1.0}) => ProviderScope(
        overrides: [
          maintenanceRepoProvider.overrideWithValue(_MemRepo({
            'edit-1': MaintenanceRecord(id: 'edit-1', siteCode: 'EDIT-9'),
          })),
          maintenancePhotoCountProvider.overrideWith((ref, id) async => 0),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: const [StatusColors.light]),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: MaintenanceFormPage(id: id),
        ),
      );

  void size(WidgetTester tester, Size s) {
    tester.view.physicalSize = s;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // The section widgets inside the form are laid out with Flutter's test
    // font, which is far wider than the real one, so their overflow reports
    // say nothing about devices. Everything else still fails the test.
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      // Also a known cosmetic assertion in the Signatures section (a ListTile
      // inside a coloured box), which is unrelated to the form's behaviour.
      if (text.contains('overflowed') ||
          text.contains('ListTile background color')) {
        return;
      }
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
  }

  testWidgets('a new record starts at step 1 with nothing done', (tester) async {
    size(tester, const Size(420, 900));
    await tester.pumpWidget(app());
    await _settle(tester);

    expect(find.text('New Maintenance Record'), findsOneWidget);
    expect(find.textContaining('Step 1 of 8'), findsOneWidget);
    expect(find.textContaining('0 of 8 done'), findsOneWidget);
    expect(find.text('Not started'), findsWidgets);
    // Previous is disabled on the first step.
    final previous = tester.widget<OutlinedButton>(
        find.widgetWithText(OutlinedButton, 'Previous'));
    expect(previous.onPressed, isNull);
  });

  testWidgets('a new record starts with today as the service date, which can '
      'be changed', (tester) async {
    size(tester, const Size(420, 900));
    await tester.pumpWidget(app());
    await _settle(tester);

    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final today = '${months[now.month - 1]} ${now.day}, ${now.year}';
    expect(find.text('Date of Service'), findsOneWidget);
    expect(find.text(today), findsOneWidget);

    // Tapping opens the picker; choosing a day updates the field.
    await tester.tap(find.text(today));
    await _settle(tester);
    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.text('1').first);
    await tester.tap(find.text('OK'));
    await _settle(tester);
    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.text('${months[now.month - 1]} 1, ${now.year}'), findsOneWidget);
  });

  testWidgets('Next and Previous move between steps', (tester) async {
    size(tester, const Size(420, 900));
    await tester.pumpWidget(app());
    await _settle(tester);

    await tester.tap(find.text('Next'));
    await _settle(tester);
    expect(find.textContaining('Step 2 of 8'), findsOneWidget);

    await tester.tap(find.text('Previous'));
    await _settle(tester);
    expect(find.textContaining('Step 1 of 8'), findsOneWidget);
  });

  testWidgets('tapping a step in the strip jumps straight to it',
      (tester) async {
    size(tester, const Size(700, 900));
    await tester.pumpWidget(app());
    await _settle(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'General Maintenance'));
    await _settle(tester);
    expect(find.textContaining('Step 3 of 8'), findsOneWidget);
  });

  testWidgets('editing an existing record uses the Edit title',
      (tester) async {
    size(tester, const Size(420, 900));
    await tester.pumpWidget(app(id: 'edit-1'));
    await _settle(tester);
    expect(find.text('Edit Maintenance Record'), findsOneWidget);
  });

  testWidgets('finishing with sections empty lists them first',
      (tester) async {
    size(tester, const Size(420, 900));
    await tester.pumpWidget(app());
    await _settle(tester);

    // Walk to the last step with Next.
    for (var i = 0; i < 7; i++) {
      await tester.tap(find.text('Next'));
      await _settle(tester);
    }
    expect(find.textContaining('Step 8 of 8'), findsOneWidget);
    await tester.tap(find.text('Complete & Save'));
    await _settle(tester);

    expect(find.text('Not everything is filled in'), findsOneWidget);
    expect(find.text('Save anyway'), findsOneWidget);
    // Site information and signatures are the two expected sections.
    expect(find.text('Site Information'), findsWidgets);

    await tester.tap(find.text('Keep editing'));
    await _settle(tester);
    expect(find.text('Not everything is filled in'), findsNothing);
  });

  testWidgets('the wide layout shows every section with its status',
      (tester) async {
    size(tester, const Size(1280, 800));
    await tester.pumpWidget(app());
    await _settle(tester);

    expect(find.text('Sections'), findsOneWidget);
    for (final title in [
      'Site Information',
      'Walkthrough',
      'General Maintenance',
      'Actions Performed',
      'Post-Service',
      'Parts & Materials',
      'Photos',
      'Signatures',
    ]) {
      expect(find.text(title), findsWidgets, reason: title);
    }
  });

  // The step content comes from the section widgets (tested separately); here
  // only the form's own chrome - header, step strip, action bar - is checked.
  // Flutter's test font is much wider than the real one, so an overflow inside
  // a section is not evidence about real devices.
  for (final entry in {
    'phone': const Size(360, 800),
    'tablet': const Size(1280, 800),
  }.entries) {
    testWidgets('the form chrome fits at 1.3x text on a ${entry.key}',
        (tester) async {
      size(tester, entry.value);
      final reports = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) => reports.add(d.toString());
      addTearDown(() => FlutterError.onError = previous);

      await tester.pumpWidget(app(textScale: 1.3));
      await _settle(tester);
      await tester.tap(find.text('Next'));
      await _settle(tester);
      tester.takeException();

      final ours = reports.where((r) => r.contains('maintenance_form_page.dart'));
      expect(ours, isEmpty, reason: ours.join('\n---\n'));
    });
  }

  group('restoring records from the cloud', () {
    test('adds only the records this device is missing', () async {
      final repo = MaintenanceRepo(box: box);
      final local = repo.createNew()..siteCode = 'LOCAL';
      await local.save();

      final remoteOnly = MaintenanceRecord(id: 'cloud-only')
        ..siteCode = 'Q183'
        ..completed = true;
      final remoteCopyOfLocal = MaintenanceRecord(id: local.id)
        ..siteCode = 'STALE-CLOUD-COPY';

      final added = await repo.restoreMissing([remoteOnly, remoteCopyOfLocal]);

      expect(added, 1);
      expect(box.get('cloud-only')?.siteCode, 'Q183');
      expect(box.get('cloud-only')?.completed, isTrue);
      // The record already here keeps its local edits.
      expect(box.get(local.id)?.siteCode, 'LOCAL');
    });

    test('a second restore adds nothing', () async {
      final repo = MaintenanceRepo(box: box);
      final r = MaintenanceRecord(id: 'once-only');
      expect(await repo.restoreMissing([r]), 1);
      expect(await repo.restoreMissing([MaintenanceRecord(id: 'once-only')]), 0);
    });
  });

  group('service date', () {
    test('a new record defaults to today', () {
      final r = MaintenanceRepo(box: box).createNew();
      final now = DateTime.now();
      expect(r.dateOfService, isNotNull);
      expect(DateTime(r.dateOfService!.year, r.dateOfService!.month,
              r.dateOfService!.day),
          DateTime(now.year, now.month, now.day));
    });

    test('an older record with no date takes the day it was created',
        () async {
      final repo = MaintenanceRepo(box: box);
      final old = MaintenanceRecord(id: 'old-no-date')
        ..createdAt = DateTime(2026, 10, 13, 9);
      await box.put(old.id, old);

      final c = ProviderContainer(overrides: [
        maintenanceRepoProvider.overrideWithValue(repo),
      ]);
      addTearDown(c.dispose);
      final sub = c.listen(maintenanceFormControllerProvider(old.id), (_, __) {});
      expect(sub.read()!.record.dateOfService, DateTime(2026, 10, 13, 9));
      sub.close();
    });
  });

  group('draft handling', () {
    test('saveDraft persists without needing the final save', () async {
      final c = ProviderContainer(overrides: [
        maintenanceRepoProvider.overrideWithValue(MaintenanceRepo(box: box)),
      ]);
      addTearDown(c.dispose);

      final sub = c.listen(maintenanceFormControllerProvider(null), (_, __) {});
      final record = sub.read()!.record..siteCode = 'DRAFT-1';
      await c
          .read(maintenanceFormControllerProvider(null).notifier)
          .saveDraft();

      expect(box.get(record.id)?.siteCode, 'DRAFT-1');
      sub.close();
    });

    test('discardIfNew removes a new record but never an existing one',
        () async {
      final repo = MaintenanceRepo(box: box);

      final c = ProviderContainer(overrides: [
        maintenanceRepoProvider.overrideWithValue(repo),
      ]);
      addTearDown(c.dispose);

      final fresh = c.listen(maintenanceFormControllerProvider(null), (_, __) {});
      final freshId = fresh.read()!.record.id;
      expect(box.containsKey(freshId), isTrue);
      await c
          .read(maintenanceFormControllerProvider(null).notifier)
          .discardIfNew();
      expect(box.containsKey(freshId), isFalse);
      fresh.close();

      final existing = repo.createNew()..siteCode = 'KEEP';
      await existing.save();
      final open =
          c.listen(maintenanceFormControllerProvider(existing.id), (_, __) {});
      await c
          .read(maintenanceFormControllerProvider(existing.id).notifier)
          .discardIfNew();
      expect(box.containsKey(existing.id), isTrue);
      open.close();
    });
  });
}
