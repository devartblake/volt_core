import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/theme/status_colors.dart';
import 'package:voltcore/modules/inventory/domain/stock.dart';
import 'package:voltcore/modules/inventory/infra/inventory_repository.dart';
import 'package:voltcore/modules/materials/domain/material_item.dart';
import 'package:voltcore/modules/materials/infra/materials_repository.dart';
import 'package:voltcore/modules/materials/presenter/job_context_providers.dart';
import 'package:voltcore/modules/materials/presenter/materials_editor.dart';

class _MemRepo extends MaterialsRepository {
  _MemRepo(this.store);
  final Map<String, List<MaterialItem>> store;

  @override
  Future<List<MaterialItem>> load(MaterialOwner owner) async =>
      store[owner.storeKey] ?? const [];
}

const _profile = MaterialOwner.generator(key: 'g|rg|1', make: 'Generac', model: 'RG', serial: '1');

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.pump(const Duration(milliseconds: 150));
  }
}

Widget _host(MaterialsMode mode, Map<String, int> usage) => ProviderScope(
      overrides: [
        materialsRepositoryProvider.overrideWithValue(_MemRepo({
          _profile.storeKey: [
            const MaterialItem(id: 'a', slot: MaterialSlot.airFilter, partNumber: 'AF-25'),
            const MaterialItem(id: 'b', slot: MaterialSlot.blockHeater, partNumber: 'BH1'),
          ],
        })),
        stockLevelsProvider.overrideWith((ref) async => const <StockLevel>[]),
        generatorPartUsageProvider('g|rg|1').overrideWith((ref) async => usage),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [StatusColors.light]),
        home: Scaffold(
          body: SingleChildScrollView(
            child: MaterialsEditor(owner: _profile, mode: mode),
          ),
        ),
      ),
    );

void main() {
  testWidgets('a profile item says how many jobs list the same part', (t) async {
    t.view.physicalSize = const Size(800, 4000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(MaterialsMode.profile, {'AF25': 3, 'BH1': 1}));
    await _settle(t);
    expect(find.byKey(const ValueKey('a-used-on')), findsOneWidget);
    expect(find.text('Used on 3 jobs'), findsOneWidget);
    expect(find.text('Used on 1 job'), findsOneWidget);
  });

  testWidgets('a part on no jobs shows nothing, and job lists never show it', (t) async {
    t.view.physicalSize = const Size(800, 4000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(MaterialsMode.profile, {'OTHER': 2}));
    await _settle(t);
    expect(find.textContaining('Used on'), findsNothing);

    await t.pumpWidget(_host(MaterialsMode.inspection, {'AF25': 3}));
    await _settle(t);
    expect(find.textContaining('Used on'), findsNothing);
  });
}
