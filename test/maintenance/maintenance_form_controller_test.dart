import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/modules/maintenance/infra/models/maintenance_record.dart';
import 'package:voltcore/modules/maintenance/infra/repositories/maintenance_hive_repository.dart';
import 'package:voltcore/modules/maintenance/presenter/controllers/maintenance_form_controller.dart';
import 'package:voltcore/modules/maintenance/presenter/controllers/maintenance_providers.dart';

void main() {
  late Directory dir;
  late Box<MaintenanceRecord> box;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync('voltcore_maint_form');
    Hive.init(dir.path);
    Hive.registerAdapter(MaintenanceRecordAdapter());
    box = await Hive.openBox<MaintenanceRecord>('maintenance_form_test');
  });

  tearDownAll(() async {
    await Hive.close();
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  ProviderContainer container() => ProviderContainer(overrides: [
        maintenanceRepoProvider
            .overrideWithValue(MaintenanceRepo(box: box)),
      ]);

  test('each visit to the new-record form starts a fresh record', () async {
    final c = container();
    addTearDown(c.dispose);

    // First visit: the form is open (watched), then closed.
    final first = c.listen(maintenanceFormControllerProvider(null), (_, __) {});
    final firstId = first.read()!.record.id;
    first.close();
    await Future<void>.delayed(Duration.zero);

    // Second visit must not reuse the first record.
    final second =
        c.listen(maintenanceFormControllerProvider(null), (_, __) {});
    final secondId = second.read()!.record.id;
    second.close();

    expect(secondId, isNot(firstId));
  });

  test('editing an existing record loads that record', () async {
    final c = container();
    addTearDown(c.dispose);

    final repo = MaintenanceRepo(box: box);
    final existing = repo.createNew()..siteCode = 'EDIT-1';
    await repo.save(existing);

    final sub = c.listen(
        maintenanceFormControllerProvider(existing.id), (_, __) {});
    expect(sub.read()!.record.siteCode, 'EDIT-1');
    expect(sub.read()!.isNew, isFalse);
    sub.close();
  });
}
