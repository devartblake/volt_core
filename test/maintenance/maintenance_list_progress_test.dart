import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/theme/status_colors.dart';
import 'package:voltcore/modules/maintenance/infra/models/maintenance_record.dart';
import 'package:voltcore/modules/maintenance/infra/repositories/maintenance_hive_repository.dart';
import 'package:voltcore/modules/maintenance/presenter/controllers/maintenance_list_progress.dart';
import 'package:voltcore/modules/maintenance/presenter/controllers/maintenance_providers.dart';
import 'package:voltcore/modules/maintenance/presenter/pages/maintenance_list_page.dart';
import 'package:voltcore/modules/materials/domain/material_item.dart';
import 'package:voltcore/modules/materials/infra/materials_repository.dart';
import 'package:voltcore/shared/widgets/status_chip.dart';

class _MemRepo extends MaintenanceRepo {
  _MemRepo(this.records);
  final Map<String, MaintenanceRecord> records;
  @override
  List<MaintenanceRecord> getAll() => records.values.toList();
}

class _FakeMaterials extends MaterialsRepository {
  _FakeMaterials(this.counts);
  final Map<String, int> counts;
  int reads = 0;

  @override
  Future<List<({MaterialOwnerType type, String id, List<MaterialItem> items})>>
      allJobLists() async {
    reads++;
    return [
      for (final e in counts.entries)
        (
          type: MaterialOwnerType.maintenance,
          id: e.key,
          items: [
            for (var i = 0; i < e.value; i++)
              MaterialItem(id: '${e.key}-$i', slot: MaterialSlot.airFilter),
          ],
        ),
    ];
  }
}

MaintenanceRecord _siteDone(String id) => MaintenanceRecord(id: id)
  ..siteCode = 'S-$id'
  ..address = '244 East 168 Street'
  ..dateOfService = DateTime(2026, 11, 3)
  ..technicianName = 'Daniel'
  ..generatorMake = 'Generac'
  ..generatorModel = 'RG048'
  ..generatorSerial = 'SN1';

void main() {
  group('maintenanceInProgressLabel', () {
    test('plain until counts are known or a step is done', () {
      final blank = MaintenanceRecord(id: 'x');
      expect(maintenanceInProgressLabel(blank, null), 'In progress');
      expect(maintenanceInProgressLabel(_siteDone('x'), null), 'In progress');
      expect(maintenanceInProgressLabel(blank, (photos: 0, materials: 0)),
          'In progress');
    });

    test('adds the step count, including photos and parts', () {
      expect(
          maintenanceInProgressLabel(
              _siteDone('x'), (photos: 0, materials: 0)),
          'In progress - 1 of 8');
      expect(
          maintenanceInProgressLabel(
              _siteDone('x'), (photos: 2, materials: 1)),
          'In progress - 3 of 8');
    });
  });

  group('list page', () {
    late _FakeMaterials materials;
    var photoLookups = <String>[];

    Widget app(Map<String, MaintenanceRecord> records) => ProviderScope(
          overrides: [
            maintenanceRepoProvider.overrideWithValue(_MemRepo(records)),
            materialsRepositoryProvider.overrideWithValue(materials),
            maintenancePhotoLookupProvider.overrideWithValue((id) async {
              photoLookups.add(id);
              return id == 'a' ? 2 : 0;
            }),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: const [StatusColors.light]),
            home: const MaintenanceListPage(),
          ),
        );

    testWidgets('chip shows the step count, counts read once', (tester) async {
      materials = _FakeMaterials({'a': 1});
      photoLookups = [];
      tester.view.physicalSize = const Size(900, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final previous = FlutterError.onError;
      FlutterError.onError = (d) {
        if (d.exceptionAsString().contains('overflowed')) return;
        previous?.call(d);
      };
      addTearDown(() => FlutterError.onError = previous);

      await tester.pumpWidget(app({
        'a': _siteDone('a'),
        'b': MaintenanceRecord(id: 'b', siteCode: 'S-b'),
        'c': _siteDone('c')..completed = true,
      }));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }

      expect(find.widgetWithText(StatusChip, 'In progress - 3 of 8'),
          findsOneWidget);
      expect(find.widgetWithText(StatusChip, 'In progress'), findsOneWidget);
      expect(find.widgetWithText(StatusChip, 'Completed'), findsOneWidget);
      expect(materials.reads, 1);
      // Completed records are skipped.
      expect(photoLookups.toSet(), {'a', 'b'});
      expect(photoLookups.length, 2);
    });
  });
}
