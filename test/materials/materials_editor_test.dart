import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/theme/status_colors.dart';
import 'package:voltcore/modules/inventory/domain/catalog_part.dart';
import 'package:voltcore/modules/inventory/domain/stock.dart';
import 'package:voltcore/modules/inventory/infra/inventory_repository.dart';
import 'package:voltcore/modules/materials/domain/material_item.dart';
import 'package:voltcore/modules/materials/domain/material_list.dart';
import 'package:voltcore/modules/materials/infra/materials_repository.dart';
import 'package:voltcore/modules/materials/presenter/job_context_providers.dart';
import 'package:voltcore/modules/materials/presenter/materials_editor.dart';

/// In-memory store: widget tests run on a fake clock, where Hive writes never
/// complete.
class _MemRepo extends MaterialsRepository {
  _MemRepo([Map<String, List<MaterialItem>>? seed]) : store = seed ?? {};

  final Map<String, List<MaterialItem>> store;
  final List<String> saves = [];

  @override
  Future<List<MaterialItem>> load(MaterialOwner owner) async =>
      store[owner.storeKey] ?? const [];

  @override
  Future<List<MaterialItem>> save(
    MaterialOwner owner,
    List<MaterialItem> items,
  ) async {
    final kept = MaterialListOps.forSaving(items);
    store[owner.storeKey] = kept;
    saves.add(owner.storeKey);
    return kept;
  }

  @override
  Future<void> saveDraft(MaterialOwner owner, List<MaterialItem> items) async {
    store[owner.storeKey] = items;
  }
}

const _job = MaterialOwner.inspection(id: 'insp-1', equipmentKey: 'g|rg|1');
const _profile = MaterialOwner.generator(
  key: 'g|rg|1',
  make: 'Generac',
  model: 'RG',
  serial: '1',
);

/// The page chrome has a sync indicator that animates forever, so
/// pumpAndSettle would never return; advance a fixed amount instead.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

void main() {
  Widget host(
    _MemRepo repo, {
    MaterialsMode mode = MaterialsMode.inspection,
    MaterialOwner? profileOwner,
    bool canEditProfile = false,
    bool readOnly = false,
    List<MaterialItem> Function()? seed,
    ValueChanged<List<MaterialItem>>? onChanged,
    double textScale = 1.0,
    List<StockLevel> stock = const [],
  }) =>
      ProviderScope(
        // A fresh state per mode when one test builds several.
        key: ValueKey(mode),
        overrides: [
          materialsRepositoryProvider.overrideWithValue(repo),
          stockLevelsProvider.overrideWith((ref) async => stock),
          // "Used on N jobs" reads every saved job list; no device store here.
          jobPartsListsProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp(
          theme: ThemeData(extensions: const [StatusColors.light]),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: MaterialsEditor(
                owner: _job,
                mode: mode,
                profileOwner: profileOwner,
                canEditProfile: canEditProfile,
                readOnly: readOnly,
                seed: seed,
                onChanged: onChanged,
              ),
            ),
          ),
        ),
      );

  void size(WidgetTester tester, Size s) {
    tester.view.physicalSize = s;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('shows all ten slots', (tester) async {
    size(tester, const Size(800, 3000));
    await tester.pumpWidget(host(_MemRepo()));
    await _settle(tester);

    for (final slot in MaterialSlot.values) {
      expect(find.text(slot.label), findsOneWidget, reason: slot.label);
    }
  });

  testWidgets('adding a part to a single slot, then it cannot be added twice',
      (tester) async {
    size(tester, const Size(800, 3000));
    await tester.pumpWidget(host(_MemRepo()));
    await _settle(tester);

    await tester.tap(find.text('Air filter'));
    await _settle(tester);
    await tester.tap(find.text('Add air filter'));
    await _settle(tester);

    expect(find.text('Part number'), findsOneWidget);
    expect(find.text('Part name'), findsOneWidget);
    expect(find.text('Manufacturer'), findsOneWidget);
    expect(find.text('Date used'), findsOneWidget);
    expect(find.text('Qty'), findsOneWidget);
    // One filter only: no "Add another" and no second "Add" button.
    expect(find.text('Add another'), findsNothing);
    expect(find.text('Add air filter'), findsNothing);
  });

  testWidgets('a multi slot allows another, labelled primary then secondary',
      (tester) async {
    size(tester, const Size(800, 3000));
    await tester.pumpWidget(host(_MemRepo()));
    await _settle(tester);

    await tester.tap(find.text('Oil filter'));
    await _settle(tester);
    await tester.tap(find.text('Add oil filter'));
    await _settle(tester);
    await tester.tap(find.text('Add another'));
    await _settle(tester);

    expect(find.widgetWithText(ButtonSegment<MaterialRole>, 'Primary'),
        findsNothing); // segments are not widgets; check the control instead
    expect(find.byType(SegmentedButton<MaterialRole>), findsNWidgets(2));
    expect(find.text('Primary'), findsNWidgets(2));
    expect(find.text('Secondary'), findsNWidgets(2));
  });

  testWidgets('additional parts take many with no primary / secondary',
      (tester) async {
    size(tester, const Size(800, 3000));
    await tester.pumpWidget(host(_MemRepo()));
    await _settle(tester);

    await tester.tap(find.text('Additional parts'));
    await _settle(tester);
    await tester.tap(find.text('Add additional parts'));
    await _settle(tester);
    await tester.tap(find.text('Add another'));
    await _settle(tester);

    expect(find.byType(SegmentedButton<MaterialRole>), findsNothing);
    expect(find.text('Part number'), findsNWidgets(2));
  });

  testWidgets('typing saves to the store after a pause and reports changes',
      (tester) async {
    size(tester, const Size(800, 3000));
    final repo = _MemRepo();
    List<MaterialItem>? reported;
    await tester.pumpWidget(host(repo, onChanged: (l) => reported = l));
    await _settle(tester);

    await tester.tap(find.text('Battery'));
    await _settle(tester);
    await tester.tap(find.text('Add battery'));
    await _settle(tester);

    await tester.enterText(find.widgetWithText(TextFormField, 'Part number'), 'bat-27');
    await tester.pump();
    expect(reported!.single.partNumber, 'bat-27');
    // Nothing is written until typing pauses.
    expect(repo.saves, isEmpty);

    await tester.pump(const Duration(seconds: 2));
    expect(repo.saves, [_job.storeKey]);
    expect(repo.store[_job.storeKey]!.single.partNumber, 'bat-27');
  });

  testWidgets('quantity steps up and down but not below zero', (tester) async {
    size(tester, const Size(800, 3000));
    List<MaterialItem>? reported;
    await tester.pumpWidget(host(_MemRepo(), onChanged: (l) => reported = l));
    await _settle(tester);

    await tester.tap(find.text('Racor filter'));
    await _settle(tester);
    await tester.tap(find.text('Add racor filter'));
    await _settle(tester);

    await tester.tap(find.byTooltip('More'));
    await tester.pump();
    expect(reported!.single.quantity, 2);

    await tester.tap(find.byTooltip('Fewer'));
    await tester.pump();
    await tester.tap(find.byTooltip('Fewer'));
    await tester.pump();
    expect(reported!.single.quantity, 0);
    final fewer = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.remove));
    expect(fewer.onPressed, isNull);
  });

  testWidgets('the date is "Not recorded" until picked, then can be cleared',
      (tester) async {
    size(tester, const Size(800, 3000));
    List<MaterialItem>? reported;
    await tester.pumpWidget(host(_MemRepo(), onChanged: (l) => reported = l));
    await _settle(tester);

    await tester.tap(find.text('Block heater'));
    await _settle(tester);
    await tester.tap(find.text('Add block heater'));
    await _settle(tester);

    expect(find.text('Not recorded'), findsOneWidget);

    await tester.tap(find.text('Not recorded'));
    await _settle(tester);
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await _settle(tester);
    expect(reported!.single.dateUsed, isNotNull);
    expect(find.text('Not recorded'), findsNothing);

    await tester.tap(find.byTooltip('Clear date'));
    await tester.pump();
    expect(reported!.single.dateUsed, isNull);
  });

  testWidgets('"Needs replacement" is only on inspections', (tester) async {
    size(tester, const Size(800, 3000));
    for (final entry in {
      MaterialsMode.inspection: true,
      MaterialsMode.maintenance: false,
      MaterialsMode.profile: false,
    }.entries) {
      await tester.pumpWidget(host(_MemRepo(), mode: entry.key));
      await _settle(tester);
      await tester.tap(find.text('Coolant filter'));
      await _settle(tester);
      await tester.tap(find.text('Add coolant filter'));
      await _settle(tester);
      expect(find.text('Needs replacement'),
          entry.value ? findsOneWidget : findsNothing,
          reason: entry.key.name);
    }
  });

  testWidgets('flagging a part shows a Due chip and a count', (tester) async {
    size(tester, const Size(800, 3000));
    await tester.pumpWidget(host(_MemRepo()));
    await _settle(tester);

    await tester.tap(find.text('Air filter'));
    await _settle(tester);
    await tester.tap(find.text('Add air filter'));
    await _settle(tester);
    await tester.tap(find.byType(Switch));
    await _settle(tester);

    expect(find.text('Due'), findsOneWidget);
    expect(find.text('1 part due for replacement'), findsOneWidget);
  });

  testWidgets('saved items load, with their slots open', (tester) async {
    size(tester, const Size(800, 3000));
    final repo = _MemRepo({
      _job.storeKey: [
        const MaterialItem(
          id: 'a',
          slot: MaterialSlot.fuelFilter,
          role: MaterialRole.primary,
          partNumber: 'FF-77',
          manufacturer: 'Fleetguard',
        ),
      ],
    });
    await tester.pumpWidget(host(repo));
    await _settle(tester);

    expect(find.text('FF-77'), findsOneWidget);
    expect(find.text('Recorded'), findsOneWidget);
  });

  testWidgets('older inspections: their four dates seed the list',
      (tester) async {
    size(tester, const Size(800, 3000));
    await tester.pumpWidget(host(
      _MemRepo(),
      seed: () => MaterialListOps.seedFromLegacyDates(oil: '2026-10-02'),
    ));
    await _settle(tester);

    expect(find.text('Oct 2, 2026'), findsOneWidget);
  });

  testWidgets('read-only shows parts but offers no editing', (tester) async {
    size(tester, const Size(800, 3000));
    final repo = _MemRepo({
      _job.storeKey: [
        const MaterialItem(
          id: 'a',
          slot: MaterialSlot.airFilter,
          partNumber: 'AF-1',
        ),
      ],
    });
    await tester.pumpWidget(host(repo, readOnly: true));
    await _settle(tester);

    expect(find.text('AF-1'), findsOneWidget);
    expect(find.byTooltip('Remove this part'), findsNothing);
    expect(find.textContaining('Add '), findsNothing);
  });

  group('generator profile', () {
    testWidgets('copy from profile fills the list with the profile parts',
        (tester) async {
      size(tester, const Size(800, 3000));
      final repo = _MemRepo({
        _profile.storeKey: [
          const MaterialItem(
            id: 'p1',
            slot: MaterialSlot.oilFilter,
            role: MaterialRole.primary,
            partNumber: 'OF-1',
          ),
        ],
      });
      List<MaterialItem>? reported;
      await tester.pumpWidget(host(repo,
          profileOwner: _profile, onChanged: (l) => reported = l));
      await _settle(tester);

      await tester.tap(find.text('Copy from generator profile'));
      await _settle(tester);

      expect(reported!.single.partNumber, 'OF-1');
      // A copy, not the profile's own item.
      expect(reported!.single.id, isNot('p1'));
      expect(find.text('OF-1'), findsOneWidget);
    });

    testWidgets('copying over existing parts asks first', (tester) async {
      size(tester, const Size(800, 3000));
      final repo = _MemRepo({
        _job.storeKey: [
          const MaterialItem(
              id: 'mine', slot: MaterialSlot.airFilter, partNumber: 'MINE'),
        ],
        _profile.storeKey: [
          const MaterialItem(
              id: 'p', slot: MaterialSlot.battery, partNumber: 'PROFILE'),
        ],
      });
      await tester.pumpWidget(host(repo, profileOwner: _profile));
      await _settle(tester);

      await tester.tap(find.text('Copy from generator profile'));
      await _settle(tester);
      expect(find.text('Replace the parts listed here?'), findsOneWidget);

      await tester.tap(find.text('Keep mine'));
      await _settle(tester);
      expect(find.text('MINE'), findsOneWidget);
      expect(find.text('PROFILE'), findsNothing);
    });

    testWidgets('"Save to profile" is only offered to those who may edit it',
        (tester) async {
      size(tester, const Size(800, 3000));
      await tester.pumpWidget(host(_MemRepo(), profileOwner: _profile));
      await _settle(tester);
      expect(find.text('Save to profile'), findsNothing);

      await tester.pumpWidget(
          host(_MemRepo(), profileOwner: _profile, canEditProfile: true));
      await _settle(tester);
      expect(find.text('Save to profile'), findsOneWidget);
    });

    testWidgets('saving to the profile writes the parts there', (tester) async {
      size(tester, const Size(800, 3000));
      final repo = _MemRepo({
        _job.storeKey: [
          const MaterialItem(
              id: 'a', slot: MaterialSlot.airFilter, partNumber: 'AF-5'),
        ],
      });
      await tester.pumpWidget(
          host(repo, profileOwner: _profile, canEditProfile: true));
      await _settle(tester);

      await tester.tap(find.text('Save to profile'));
      await _settle(tester);
      await tester.tap(find.text('Update profile'));
      await _settle(tester);

      expect(repo.store[_profile.storeKey]!.single.partNumber, 'AF-5');
    });
  });

  for (final entry in {
    'phone': const Size(360, 900),
    'tablet': const Size(1280, 800),
  }.entries) {
    testWidgets('fits at 1.3x text on a ${entry.key}', (tester) async {
      size(tester, entry.value);
      final reports = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) => reports.add(d.toString());
      addTearDown(() => FlutterError.onError = previous);

      final repo = _MemRepo({
        _job.storeKey: [
          const MaterialItem(
            id: 'a',
            slot: MaterialSlot.oilFilter,
            role: MaterialRole.primary,
            partNumber: 'OF-123456',
            partName: 'Heavy duty spin-on oil filter',
            manufacturer: 'Fleetguard',
          ),
        ],
      });
      await tester.pumpWidget(host(repo, textScale: 1.3));
      await _settle(tester);
      tester.takeException();

      final ours = reports
          .where((r) => r.contains('materials_editor.dart'))
          .toList();
      expect(ours, isEmpty, reason: ours.join('\n---\n'));
    });
  }

  group('catalog suggestions', () {
    final t = DateTime.utc(2026);
    StockLevel level(String id, String number,
            {String name = '', String mfr = '', int onHand = 0}) =>
        StockLevel(
          part: CatalogPart(
              id: id, partNumber: number, name: name, manufacturer: mfr,
              createdAt: t, updatedAt: t),
          onHand: onHand,
          reserved: 0,
        );

    Future<void> openAirFilter(
        WidgetTester tester, List<StockLevel> stock) async {
      size(tester, const Size(800, 3000));
      await tester.pumpWidget(host(_MemRepo(), stock: stock));
      await _settle(tester);
      await tester.tap(find.text('Air filter'));
      await _settle(tester);
      await tester.tap(find.text('Add air filter'));
      await _settle(tester);
    }

    testWidgets('typing offers catalog parts; tapping one fills the fields',
        (tester) async {
      final stock = [
        level('1', 'AF25550', name: 'Air filter', mfr: 'Donaldson', onHand: 3),
        level('2', 'ZZ999', name: 'Other'),
      ];
      await openAirFilter(tester, stock);

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Part number'), 'af25');
      await _settle(tester);
      expect(find.textContaining('AF25550 · Air filter'), findsOneWidget);
      expect(find.textContaining('ZZ999'), findsNothing);

      await tester.tap(find.textContaining('AF25550 · Air filter'));
      await _settle(tester);

      expect(find.widgetWithText(TextFormField, 'AF25550'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Air filter'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Donaldson'), findsOneWidget);
      // Exact match now: shows stock instead of suggestions.
      expect(find.text('In stock: 3'), findsOneWidget);
    });

    testWidgets('an exact part number shows its stock', (tester) async {
      await openAirFilter(tester, [level('1', 'AF-1', onHand: 0)]);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Part number'), 'af 1');
      await _settle(tester);
      expect(find.text('Not in stock'), findsOneWidget);
    });

    testWidgets('an unknown part number shows nothing extra', (tester) async {
      await openAirFilter(tester, [level('1', 'AF-1', onHand: 5)]);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Part number'), 'qqq');
      await _settle(tester);
      expect(find.byType(ActionChip), findsNothing);
      expect(find.textContaining('stock'), findsNothing);
    });
  });
}
