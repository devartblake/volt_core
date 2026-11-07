import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/theme/status_colors.dart';
import 'package:voltcore/shared/widgets/status_chip.dart';
import 'package:voltcore/modules/maintenance/infra/models/maintenance_record.dart';
import 'package:voltcore/modules/maintenance/infra/repositories/maintenance_hive_repository.dart';
import 'package:voltcore/modules/maintenance/presenter/controllers/maintenance_list_progress.dart';
import 'package:voltcore/modules/maintenance/presenter/controllers/maintenance_providers.dart';
import 'package:voltcore/modules/materials/domain/material_item.dart';
import 'package:voltcore/modules/materials/infra/materials_repository.dart';
import 'package:voltcore/modules/maintenance/presenter/pages/maintenance_list_page.dart';

/// In-memory repo: Hive writes hang on the widget-test fake clock.
class _MemRepo extends MaintenanceRepo {
  _MemRepo(this.records);

  final Map<String, MaintenanceRecord> records;

  @override
  List<MaintenanceRecord> getAll() => records.values.toList();

  @override
  Future<void> delete(String id) async => records.remove(id);

  @override
  Future<void> restore(MaintenanceRecord rec) async => records[rec.id] = rec;
}

class _NoMaterials extends MaterialsRepository {
  @override
  Future<List<({MaterialOwnerType type, String id, List<MaterialItem> items})>>
      allJobLists() async => const [];
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  late _MemRepo repo;

  setUp(() {
    repo = _MemRepo({
      'a': MaintenanceRecord(id: 'a', siteCode: 'SITE-A')..completed = true,
      'b': MaintenanceRecord(id: 'b', siteCode: 'SITE-B'),
    });
  });

  Widget app() => ProviderScope(
        overrides: [
          maintenanceRepoProvider.overrideWithValue(repo),
          // The real stores are Hive-backed, which hangs on the test clock.
          materialsRepositoryProvider
              .overrideWithValue(_NoMaterials()),
          maintenancePhotoLookupProvider.overrideWithValue((id) async => 0),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: const [StatusColors.light]),
          home: const MaintenanceListPage(),
        ),
      );

  void size(WidgetTester tester) {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      previous?.call(details);
    };
    addTearDown(() => FlutterError.onError = previous);
  }

  testWidgets('each record shows its status chip', (tester) async {
    size(tester);
    await tester.pumpWidget(app());
    await _settle(tester);

    expect(find.text('SITE-A'), findsOneWidget);
    expect(find.text('SITE-B'), findsOneWidget);
    expect(find.widgetWithText(StatusChip, 'Completed'), findsOneWidget);
    expect(find.widgetWithText(StatusChip, 'In progress'), findsOneWidget);
  });

  testWidgets('filter chips narrow the list', (tester) async {
    size(tester);
    await tester.pumpWidget(app());
    await _settle(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
    await _settle(tester);
    expect(find.text('SITE-A'), findsOneWidget);
    expect(find.text('SITE-B'), findsNothing);

    await tester.tap(find.widgetWithText(ChoiceChip, 'In progress'));
    await _settle(tester);
    expect(find.text('SITE-A'), findsNothing);
    expect(find.text('SITE-B'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await _settle(tester);
    expect(find.text('SITE-A'), findsOneWidget);
    expect(find.text('SITE-B'), findsOneWidget);
  });

  testWidgets('swipe deletes, and Undo brings back the very same record',
      (tester) async {
    size(tester);
    final original = repo.records['b']!;
    await tester.pumpWidget(app());
    await _settle(tester);

    await tester.drag(find.text('SITE-B'), const Offset(-900, 0));
    await _settle(tester);
    expect(find.text('SITE-B'), findsNothing);
    expect(repo.records.containsKey('b'), isFalse);
    expect(find.text('SITE-B deleted'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await _settle(tester);
    expect(repo.records['b'], same(original));
    expect(find.text('SITE-B'), findsOneWidget);
    // The other record was never touched.
    expect(find.text('SITE-A'), findsOneWidget);
  });
}
