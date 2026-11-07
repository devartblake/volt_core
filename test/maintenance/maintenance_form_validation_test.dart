import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/core/theme/status_colors.dart';
import 'package:voltcore/modules/maintenance/infra/models/maintenance_record.dart';
import 'package:voltcore/modules/maintenance/infra/repositories/maintenance_hive_repository.dart';
import 'package:voltcore/modules/maintenance/presenter/controllers/maintenance_providers.dart';
import 'package:voltcore/modules/maintenance/presenter/pages/maintenance_form_page.dart';

class _MemRepo extends MaintenanceRepo {
  final Map<String, MaintenanceRecord> records = {};

  @override
  MaintenanceRecord createNew({String? inspectionId}) {
    final m = MaintenanceRecord(id: 'new-1', dateOfService: DateTime.now());
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
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  const required = 'Required to finish';
  late Directory dir;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('voltcore_maint_validation');
    Hive.init(dir.path);
    Hive.registerAdapter(MaintenanceRecordAdapter());
    await Hive.openBox<MaintenanceRecord>('maintenance_validation_test');
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  void size(WidgetTester tester) {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed') ||
          text.contains('ListTile background color')) {
        return;
      }
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
  }

  Widget app() => ProviderScope(
        overrides: [
          maintenanceRepoProvider.overrideWithValue(_MemRepo()),
          maintenancePhotoCountProvider.overrideWith((ref, id) async => 0),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: const [StatusColors.light]),
          home: const MaintenanceFormPage(),
        ),
      );

  testWidgets('a fresh form shows no required messages', (tester) async {
    size(tester);
    await tester.pumpWidget(app());
    await _settle(tester);
    expect(find.text(required), findsNothing);
  });

  testWidgets('leaving Site Information reveals what it still needs',
      (tester) async {
    size(tester);
    await tester.pumpWidget(app());
    await _settle(tester);

    await tester.tap(find.text('Next'));
    await _settle(tester);
    await tester.tap(find.text('Previous'));
    await _settle(tester);

    // Address, technician, make, model, serial (the date starts as today).
    expect(find.text(required), findsNWidgets(5));
  });

  testWidgets('Complete & Save shows the messages and still offers '
      'Save anyway', (tester) async {
    size(tester);
    await tester.pumpWidget(app());
    await _settle(tester);

    for (var i = 0; i < 7; i++) {
      await tester.tap(find.text('Next'));
      await _settle(tester);
    }
    // The Signatures step has not been left yet: no messages on it.
    expect(find.text(required), findsNothing);

    await tester.tap(find.text('Complete & Save'));
    await _settle(tester);
    expect(find.text('Save anyway'), findsOneWidget);

    await tester.tap(find.text('Keep editing'));
    await _settle(tester);
    // Technician and customer signature names.
    expect(find.text(required), findsNWidgets(2));
  });
}
