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

class _MemRepo extends MaintenanceRepo {
  _MemRepo(this.records);
  final Map<String, MaintenanceRecord> records;
  @override
  List<MaintenanceRecord> getAll() => records.values.toList();
}

class _NoMaterials extends MaterialsRepository {
  @override
  Future<List<({MaterialOwnerType type, String id, List<MaterialItem> items})>>
      allJobLists() async => const [];
}

void main() {
  testWidgets('maintenance list builds cards lazily (300 records)', (t) async {
    t.view.physicalSize = const Size(400, 700);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final prev = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.exceptionAsString().contains('overflowed')) return;
      prev?.call(d);
    };
    addTearDown(() => FlutterError.onError = prev);

    final repo = _MemRepo({
      for (var i = 0; i < 300; i++)
        'r$i': MaintenanceRecord(id: 'r$i', siteCode: 'SITE-$i'),
    });
    await t.pumpWidget(ProviderScope(
      overrides: [
        maintenanceRepoProvider.overrideWithValue(repo),
        materialsRepositoryProvider.overrideWithValue(_NoMaterials()),
        maintenancePhotoLookupProvider.overrideWithValue((id) async => 0),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [StatusColors.light]),
        home: const MaintenanceListPage(),
      ),
    ));
    for (var i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 150));
    }
    final built = find.byType(Dismissible).evaluate().length;
    expect(built, greaterThan(0));
    expect(built, lessThan(60));
  });
}
