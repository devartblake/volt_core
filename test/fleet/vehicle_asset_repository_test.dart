import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_asset.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_asset_catalog_item.dart';
import 'package:voltcore/modules/fleet/infra/mappers/vehicle_asset_supabase_mapper.dart';
import 'package:voltcore/modules/fleet/infra/models/vehicle_asset_catalog_item_record.dart';
import 'package:voltcore/modules/fleet/infra/models/vehicle_asset_record.dart';
import 'package:voltcore/modules/fleet/infra/repositories/vehicle_asset_repository.dart';

const String _tenant = 'tenant-1';

void main() {
  late Box<VehicleAssetCatalogItemRecord> catalogBox;
  late Box<VehicleAssetRecord> assetBox;
  late VehicleAssetRepositoryImpl repository;
  late List<VehicleAssetCatalogItem> queuedItems;
  late List<VehicleAsset> queuedAssets;

  setUpAll(() {
    Hive.init('.dart_tool/fleet_asset_test_hive');
    if (!Hive.isAdapterRegistered(kVehicleAssetCatalogItemTypeId)) {
      Hive.registerAdapter(VehicleAssetCatalogItemRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(kVehicleAssetTypeId)) {
      Hive.registerAdapter(VehicleAssetRecordAdapter());
    }
  });

  setUp(() async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    catalogBox = await Hive.openBox<VehicleAssetCatalogItemRecord>('k_$stamp');
    assetBox = await Hive.openBox<VehicleAssetRecord>('a_$stamp');
    queuedItems = [];
    queuedAssets = [];

    repository = VehicleAssetRepositoryImpl(
      catalogBox: catalogBox,
      assetBox: assetBox,
      tenantIdReader: () => _tenant,
      catalogQueueWriter: (item) async => queuedItems.add(item),
      assetQueueWriter: (asset) async => queuedAssets.add(asset),
      // No Supabase client: hydration is best-effort and not what these assert.
    );
  });

  tearDown(() async {
    await catalogBox.deleteFromDisk();
    await assetBox.deleteFromDisk();
  });

  Future<VehicleAssetCatalogItem> givenTool({
    String name = 'WERNER 8FT LADDER',
    String? partNumber = '6208',
  }) {
    return repository.saveCatalogItem(
      VehicleAssetCatalogItem.newDraft(tenantId: _tenant)
          .copyWith(name: name, partNumber: partNumber),
    );
  }

  group('catalog', () {
    test('saves and enqueues', () async {
      final item = await givenTool();

      expect(catalogBox.get(item.id), isNotNull);
      expect(queuedItems, hasLength(1));
      expect(catalogItemToSupabaseJson(queuedItems.single)['tenant_id'], _tenant);
    });

    test('upper-cases the part number so duplicates cannot hide', () async {
      final item = await givenTool(partNumber: ' 74-031 ');
      expect(item.partNumber, '74-031');
    });

    test('stores a blank part number as null, not empty string', () async {
      // The unique index is partial (`where part_number is not null`), so ''
      // would collide every part-numberless tool with every other one — and
      // several items on the paper form have none.
      final item = await givenTool(name: 'PUSH CART', partNumber: '  ');
      expect(item.partNumber, isNull);
      expect(catalogItemToSupabaseJson(item)['part_number'], isNull);
    });

    test('refuses a duplicate name regardless of case', () async {
      await givenTool();
      expect(
        () => givenTool(name: 'werner 8ft ladder', partNumber: '9999'),
        throwsA(isA<StateError>()),
      );
    });

    test('refuses a duplicate part number and names the other tool', () async {
      await givenTool();
      expect(
        () => givenTool(name: 'SOMETHING ELSE', partNumber: '6208'),
        throwsA(
          isA<StateError>()
              .having((e) => e.message, 'message', contains('WERNER')),
        ),
      );
    });

    test('two part-numberless tools do not collide', () async {
      await givenTool(name: 'PUSH CART', partNumber: null);
      await givenTool(name: '100FT EXTENSION CORD', partNumber: null);
      expect(await repository.listCatalog(), hasLength(2));
    });

    test('refuses a blank name', () async {
      expect(
        () => givenTool(name: '   '),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('hides deactivated entries unless asked', () async {
      final item = await givenTool();
      await repository.saveCatalogItem(item.copyWith(isActive: false));

      expect(await repository.listCatalog(), isEmpty);
      expect(await repository.listCatalog(includeInactive: true), hasLength(1));
    });

    test('displayLabel folds in the part number when there is one', () async {
      final withPart = await givenTool();
      final without = await givenTool(name: 'PUSH CART', partNumber: null);

      expect(withPart.displayLabel, 'WERNER 8FT LADDER · 6208');
      expect(without.displayLabel, 'PUSH CART');
    });
  });

  group('assets', () {
    test('assigns a tool and enqueues it', () async {
      final tool = await givenTool();
      final asset = await repository.saveAsset(
        VehicleAsset.newDraft(
          tenantId: _tenant,
          vehicleId: 'v1',
          catalogId: tool.id,
        ),
      );

      expect(assetBox.get(asset.id), isNotNull);
      expect(queuedAssets, hasLength(1));
      expect(vehicleAssetToSupabaseJson(asset)['tenant_id'], _tenant);
    });

    test('two identical tools are two rows', () async {
      // The whole reason there is no quantity column: the paper form lists the
      // two Werner ladders separately, and on the sample one is missing and
      // the other is not.
      final tool = await givenTool();
      final first = await repository.saveAsset(
        VehicleAsset.newDraft(
            tenantId: _tenant, vehicleId: 'v1', catalogId: tool.id),
      );
      await repository.saveAsset(
        VehicleAsset.newDraft(
            tenantId: _tenant, vehicleId: 'v1', catalogId: tool.id),
      );

      await repository.saveAsset(first.copyWith(isMissing: true));

      final list = await repository.listForVehicle('v1');
      expect(list, hasLength(2));
      expect(list.where((r) => r.asset.isMissing), hasLength(1));
      expect(list.where((r) => !r.asset.isMissing), hasLength(1));
    });

    test('refuses a tool that is not in the catalog', () async {
      expect(
        () => repository.saveAsset(
          VehicleAsset.newDraft(
              tenantId: _tenant, vehicleId: 'v1', catalogId: 'ghost'),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('refuses the same serial in two vehicles', () async {
      // The same numbered tool cannot be in two vans.
      final tool = await givenTool();
      await repository.saveAsset(
        VehicleAsset.newDraft(
          tenantId: _tenant,
          vehicleId: 'v1',
          catalogId: tool.id,
        ).copyWith(serialNumber: 'sn-1'),
      );

      expect(
        () => repository.saveAsset(
          VehicleAsset.newDraft(
            tenantId: _tenant,
            vehicleId: 'v2',
            catalogId: tool.id,
          ).copyWith(serialNumber: 'SN-1'),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('a retired tool frees its serial', () async {
      final tool = await givenTool();
      final original = await repository.saveAsset(
        VehicleAsset.newDraft(
          tenantId: _tenant,
          vehicleId: 'v1',
          catalogId: tool.id,
        ).copyWith(serialNumber: 'SN-1'),
      );
      await repository.retireAsset(original.id);

      // The replacement tool legitimately carries the same number.
      final replacement = await repository.saveAsset(
        VehicleAsset.newDraft(
          tenantId: _tenant,
          vehicleId: 'v2',
          catalogId: tool.id,
        ).copyWith(serialNumber: 'SN-1'),
      );
      expect(replacement.serialNumber, 'SN-1');
    });

    test('unserialised tools do not collide with each other', () async {
      final tool = await givenTool();
      for (var i = 0; i < 3; i++) {
        await repository.saveAsset(
          VehicleAsset.newDraft(
              tenantId: _tenant, vehicleId: 'v1', catalogId: tool.id),
        );
      }
      expect(await repository.listForVehicle('v1'), hasLength(3));
    });

    test('retiring clears missing', () async {
      // A retired tool is not coming back, so leaving it flagged would keep it
      // on the attention list forever.
      final tool = await givenTool();
      final asset = await repository.saveAsset(
        VehicleAsset.newDraft(
          tenantId: _tenant,
          vehicleId: 'v1',
          catalogId: tool.id,
        ).copyWith(isMissing: true),
      );

      final retired = await repository.retireAsset(asset.id);
      expect(retired.isRetired, isTrue);
      expect(retired.isMissing, isFalse);
      expect(retired.needsAttention, isFalse);
    });

    test('retired tools drop off the list unless asked for', () async {
      final tool = await givenTool();
      final asset = await repository.saveAsset(
        VehicleAsset.newDraft(
            tenantId: _tenant, vehicleId: 'v1', catalogId: tool.id),
      );
      await repository.retireAsset(asset.id);

      expect(await repository.listForVehicle('v1'), isEmpty);
      expect(
        await repository.listForVehicle('v1', includeRetired: true),
        hasLength(1),
      );
    });

    test('sorts anything needing attention to the top', () async {
      // A missing ladder is why somebody opened the screen.
      final ladder = await givenTool();
      final bender = await givenTool(name: 'IDEAL 1/2 EMT BENDER', partNumber: '74-031');

      await repository.saveAsset(
        VehicleAsset.newDraft(
            tenantId: _tenant, vehicleId: 'v1', catalogId: bender.id),
      );
      await repository.saveAsset(
        VehicleAsset.newDraft(
          tenantId: _tenant,
          vehicleId: 'v1',
          catalogId: ladder.id,
        ).copyWith(isMissing: true),
      );

      final list = await repository.listForVehicle('v1');
      expect(list.first.asset.isMissing, isTrue);
      expect(list.first.displayLabel, startsWith('WERNER'));
    });

    test('renders a row whose catalog entry has not synced', () async {
      // Dropping it would hide exactly the tool somebody needs to ask about.
      final tool = await givenTool();
      final asset = await repository.saveAsset(
        VehicleAsset.newDraft(
          tenantId: _tenant,
          vehicleId: 'v1',
          catalogId: tool.id,
        ).copyWith(serialNumber: 'SN-9'),
      );
      await catalogBox.delete(tool.id);

      final list = await repository.listForVehicle('v1');
      expect(list, hasLength(1));
      expect(list.single.item, isNull);
      expect(list.single.displayLabel, 'Unknown tool · SN-9');
      expect(list.single.asset.id, asset.id);
    });

    test('only returns assets for the vehicle asked about', () async {
      final tool = await givenTool();
      await repository.saveAsset(
        VehicleAsset.newDraft(
            tenantId: _tenant, vehicleId: 'v1', catalogId: tool.id),
      );
      await repository.saveAsset(
        VehicleAsset.newDraft(
            tenantId: _tenant, vehicleId: 'v2', catalogId: tool.id),
      );

      expect(await repository.listForVehicle('v1'), hasLength(1));
    });
  });

  group('readiness', () {
    test('keeps the crew vocabulary from the paper form', () {
      expect(AssetReadiness.fmc.label, 'FMC');
      expect(AssetReadiness.nmc.label, 'NMC');
      expect(AssetReadiness.nmc.description, 'Not mission capable');
    });

    test('round-trips and degrades safely', () {
      for (final value in AssetReadiness.values) {
        expect(AssetReadinessX.fromWire(value.wire), value);
      }
      expect(AssetReadinessX.fromWire('sideways'), AssetReadiness.fmc);
      expect(AssetReadinessX.fromWire(null), AssetReadiness.fmc);
    });

    test('needsAttention covers both missing and NMC, but not retired', () {
      final base = VehicleAsset.newDraft(
        tenantId: _tenant,
        vehicleId: 'v1',
        catalogId: 'k1',
      );

      expect(base.needsAttention, isFalse);
      expect(base.copyWith(isMissing: true).needsAttention, isTrue);
      expect(
        base.copyWith(readiness: AssetReadiness.nmc).needsAttention,
        isTrue,
      );
      expect(
        base
            .copyWith(isMissing: true, retiredAt: DateTime.now().toUtc())
            .needsAttention,
        isFalse,
      );
    });
  });

  group('supabase mapper', () {
    test('round-trips an asset', () {
      final original = VehicleAsset.newDraft(
        tenantId: _tenant,
        vehicleId: 'v1',
        catalogId: 'k1',
      ).copyWith(
        serialNumber: 'SN-1',
        readiness: AssetReadiness.nmc,
        isMissing: true,
        notes: 'Bent rail',
      );

      final restored =
          vehicleAssetFromSupabaseJson(vehicleAssetToSupabaseJson(original));

      expect(restored.serialNumber, 'SN-1');
      expect(restored.readiness, AssetReadiness.nmc);
      expect(restored.isMissing, isTrue);
      expect(restored.notes, 'Bent rail');
      expect(restored.isRetired, isFalse);
    });

    test('round-trips a catalog item', () {
      final original = VehicleAssetCatalogItem.newDraft(tenantId: _tenant)
          .copyWith(name: 'PUSH CART', category: 'Material handling');

      final restored =
          catalogItemFromSupabaseJson(catalogItemToSupabaseJson(original));

      expect(restored.name, 'PUSH CART');
      expect(restored.partNumber, isNull);
      expect(restored.category, 'Material handling');
      expect(restored.isActive, isTrue);
    });
  });
}
