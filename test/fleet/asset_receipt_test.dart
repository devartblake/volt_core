import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/modules/fleet/domain/entities/asset_disclaimer.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_asset.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_asset_catalog_item.dart';
import 'package:voltcore/modules/fleet/domain/entities/vehicle_asset_check.dart';
import 'package:voltcore/modules/fleet/infra/mappers/vehicle_asset_check_supabase_mapper.dart';
import 'package:voltcore/modules/fleet/infra/models/fleet_reference_records.dart';
import 'package:voltcore/modules/fleet/infra/models/vehicle_asset_catalog_item_record.dart';
import 'package:voltcore/modules/fleet/infra/models/vehicle_asset_check_record.dart';
import 'package:voltcore/modules/fleet/infra/models/vehicle_asset_record.dart';
import 'package:voltcore/modules/fleet/infra/repositories/vehicle_asset_check_repository.dart';
import 'package:voltcore/modules/fleet/infra/repositories/vehicle_asset_repository.dart';

const String _tenant = 'tenant-1';
const String _vehicle = 'van-b';

void main() {
  late Box<VehicleAssetCatalogItemRecord> catalogBox;
  late Box<VehicleAssetRecord> assetBox;
  late Box<VehicleAssetCheckRecord> checkBox;
  late Box<VehicleAssetCheckLineRecord> lineBox;
  late Box<AssetDisclaimerRecord> disclaimerBox;
  late Box<FleetDepotRecord> depotBox;

  late VehicleAssetRepositoryImpl assets;
  late VehicleAssetCheckRepositoryImpl receipts;
  late List<VehicleAssetCheck> queuedChecks;
  late List<VehicleAssetCheckLine> queuedLines;

  setUpAll(() {
    Hive.init('.dart_tool/fleet_receipt_test_hive');

    // One statement each, not a loop over a map. Hive resolves adapters by the
    // registered TYPE, and a `Map<int, TypeAdapter<dynamic>>` registers every
    // one of them as `TypeAdapter<dynamic>` — after which writing an asset
    // picks up the catalog adapter and throws a type error that looks like a
    // bug in the model.
    if (!Hive.isAdapterRegistered(kVehicleAssetCatalogItemTypeId)) {
      Hive.registerAdapter(VehicleAssetCatalogItemRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(kVehicleAssetTypeId)) {
      Hive.registerAdapter(VehicleAssetRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(kVehicleAssetCheckTypeId)) {
      Hive.registerAdapter(VehicleAssetCheckRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(kVehicleAssetCheckLineTypeId)) {
      Hive.registerAdapter(VehicleAssetCheckLineRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(kAssetDisclaimerTypeId)) {
      Hive.registerAdapter(AssetDisclaimerRecordAdapter());
    }
    if (!Hive.isAdapterRegistered(kFleetDepotTypeId)) {
      Hive.registerAdapter(FleetDepotRecordAdapter());
    }
  });

  setUp(() async {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    catalogBox = await Hive.openBox<VehicleAssetCatalogItemRecord>('k_$stamp');
    assetBox = await Hive.openBox<VehicleAssetRecord>('a_$stamp');
    checkBox = await Hive.openBox<VehicleAssetCheckRecord>('c_$stamp');
    lineBox = await Hive.openBox<VehicleAssetCheckLineRecord>('l_$stamp');
    disclaimerBox = await Hive.openBox<AssetDisclaimerRecord>('d_$stamp');
    depotBox = await Hive.openBox<FleetDepotRecord>('p_$stamp');

    queuedChecks = [];
    queuedLines = [];

    assets = VehicleAssetRepositoryImpl(
      catalogBox: catalogBox,
      assetBox: assetBox,
      tenantIdReader: () => _tenant,
      catalogQueueWriter: (_) async {},
      assetQueueWriter: (_) async {},
    );

    receipts = VehicleAssetCheckRepositoryImpl(
      checkBox: checkBox,
      lineBox: lineBox,
      disclaimerBox: disclaimerBox,
      depotBox: depotBox,
      assets: assets,
      tenantIdReader: () => _tenant,
      checkQueueWriter: (check) async => queuedChecks.add(check),
      lineQueueWriter: (line) async => queuedLines.add(line),
    );
  });

  tearDown(() async {
    for (final box in [
      catalogBox,
      assetBox,
      checkBox,
      lineBox,
      disclaimerBox,
      depotBox,
    ]) {
      await box.deleteFromDisk();
    }
  });

  Future<VehicleAsset> givenTool({
    String name = 'WERNER 8FT LADDER',
    String? partNumber = '6208',
    String? serial,
  }) async {
    // Reuse the catalog entry when one already exists. Two ladders are two
    // ASSETS of one catalog TYPE — that split is the point of phase 3, and a
    // helper that made a second catalog row per ladder would be testing a
    // shape the app does not have.
    final existing = await assets.listCatalog();
    final item = existing.where((i) => i.name == name).firstOrNull ??
        await assets.saveCatalogItem(
          VehicleAssetCatalogItem.newDraft(tenantId: _tenant)
              .copyWith(name: name, partNumber: partNumber),
        );
    return assets.saveAsset(
      VehicleAsset.newDraft(
        tenantId: _tenant,
        vehicleId: _vehicle,
        catalogId: item.id,
      ).copyWith(serialNumber: serial),
    );
  }

  /// A receipt taken all the way through the operator's signature.
  Future<VehicleAssetCheck> signedBy(
    VehicleAssetCheck draft, {
    String operator = 'Steve',
  }) {
    final now = DateTime.now().toUtc();
    return receipts.save(
      draft.copyWith(
        operatorName: operator,
        dispatcherName: 'Morgan',
        disclaimerAcceptedAt: now,
        operatorSignaturePath: 'signatures/fleet/${draft.id}_operator.png',
        operatorSignedAt: now,
      ),
    );
  }

  group('starting a receipt', () {
    test('prefills one line per tool, all present and FMC', () async {
      await givenTool(name: 'IDEAL 1/2 EMT BENDER', partNumber: '74-031');
      await givenTool();

      final draft = await receipts.startReceipt(_vehicle);

      expect(draft.lines, hasLength(2));
      expect(draft.lines.every((l) => !l.isMissing), isTrue);
      expect(
        draft.lines.every((l) => l.readiness == AssetReadiness.fmc),
        isTrue,
      );
      expect(draft.stage, ReceiptStage.draft);
    });

    test('copies the tool name in rather than pointing at the catalog',
        () async {
      // The whole reason the line carries a snapshot: renaming the catalog
      // entry next year must not rewrite what was signed for this year.
      final tool = await givenTool(name: 'WERNER 8FT LADDER');
      final draft = await receipts.startReceipt(_vehicle);

      final catalog = await assets.listCatalog();
      await assets.saveCatalogItem(
        catalog.single.copyWith(name: 'WERNER 8FT LADDER (TYPE 1A)'),
      );

      expect(draft.lines.single.assetName, 'WERNER 8FT LADDER');
      expect(draft.lines.single.vehicleAssetId, tool.id);
    });

    test('carries yesterday\'s problem forward instead of resetting it',
        () async {
      final tool = await givenTool();
      await assets.saveAsset(
        tool.copyWith(readiness: AssetReadiness.nmc, isMissing: true),
      );

      final draft = await receipts.startReceipt(_vehicle);

      // Making the driver re-report the same broken ladder every morning is
      // how a form starts being signed without being read.
      expect(draft.lines.single.isMissing, isTrue);
      expect(draft.lines.single.readiness, AssetReadiness.nmc);
    });

    test('two identical ladders are two independent lines', () async {
      await givenTool(serial: 'LAD-1');
      await givenTool(serial: 'LAD-2');

      final draft = await receipts.startReceipt(_vehicle);
      expect(draft.lines, hasLength(2));

      final marked = draft.withLine(
        draft.lines.first.copyWith(isMissing: true, reason: 'Left on site'),
      );
      expect(marked.missingCount, 1);
    });
  });

  group('what blocks a signature', () {
    test('a missing tool with no reason', () async {
      await givenTool();
      final draft = await receipts.startReceipt(_vehicle);

      final marked = draft.copyWith(operatorName: 'Steve').withLine(
            draft.lines.single.copyWith(isMissing: true),
          );

      expect(
        marked.problemsBeforeSigning,
        contains(contains('marked missing')),
      );

      final explained = marked.withLine(
        marked.lines.single.copyWith(reason: 'Left on the Flushing Ave job'),
      );
      expect(
        explained.problemsBeforeSigning,
        isNot(contains(contains('marked missing'))),
      );
    });

    test('no operator name', () async {
      await givenTool();
      final draft = await receipts.startReceipt(_vehicle);

      expect(draft.problemsBeforeSigning, contains(contains('operator')));
    });

    test('the disclaimer has not been accepted', () async {
      await givenTool();
      final draft = await receipts.startReceipt(_vehicle);
      final named = draft.copyWith(operatorName: 'Steve');

      expect(
        named.problemsBeforeSigning,
        contains(contains('asset disclaimer')),
      );

      expect(
        named
            .copyWith(disclaimerAcceptedAt: DateTime.now().toUtc())
            .problemsBeforeSigning,
        isEmpty,
      );
    });

    test('a vehicle carrying no tools', () async {
      final draft = await receipts.startReceipt(_vehicle);

      expect(draft.lines, isEmpty);
      expect(
        draft.problemsBeforeSigning,
        contains(contains('nothing to sign for')),
      );
    });

    test('dispatch cannot counter-sign before the operator signs', () async {
      await givenTool();
      final draft = await receipts.startReceipt(_vehicle);

      expect(
        draft.copyWith(dispatcherName: 'Morgan').problemsBeforeCountersigning,
        contains(contains('operator has to sign')),
      );
    });
  });

  group('signing', () {
    test('writes the answers onto the vehicle\'s standing state', () async {
      await givenTool();
      final draft = await receipts.startReceipt(_vehicle);

      await signedBy(
        draft.withLine(
          draft.lines.single
              .copyWith(isMissing: true, reason: 'Left on site'),
        ),
      );

      // This is what puts the badge on the fleet list without replaying every
      // receipt ever signed.
      final tools = await assets.listForVehicle(_vehicle);
      expect(tools.single.asset.isMissing, isTrue);
    });

    test('a draft does not touch the standing state', () async {
      await givenTool();
      final draft = await receipts.startReceipt(_vehicle);

      await receipts.save(
        draft.withLine(
          draft.lines.single.copyWith(isMissing: true, reason: 'Maybe'),
        ),
      );

      // Nothing is binding until somebody signs; a half-filled form left open
      // in the yard must not flag the van.
      final tools = await assets.listForVehicle(_vehicle);
      expect(tools.single.asset.isMissing, isFalse);
    });

    test('enqueues the header and every line', () async {
      await givenTool();
      await givenTool(name: 'PUSH CART', partNumber: null);
      final draft = await receipts.startReceipt(_vehicle);

      await signedBy(draft);

      expect(queuedChecks, hasLength(1));
      expect(queuedLines, hasLength(2));
      // Without tenant_id the sync queue's re-stamp skips the row and it fails
      // RLS forever. Both tables, not just the header.
      expect(assetCheckToSupabaseJson(queuedChecks.single)['tenant_id'], _tenant);
      for (final line in queuedLines) {
        expect(assetCheckLineToSupabaseJson(line)['tenant_id'], _tenant);
      }
    });

    test('a retired tool is not re-flagged by an old line', () async {
      final tool = await givenTool();
      final draft = await receipts.startReceipt(_vehicle);
      await assets.retireAsset(tool.id);

      await signedBy(
        draft.withLine(
          draft.lines.single.copyWith(isMissing: true, reason: 'Left on site'),
        ),
      );

      final all = await assets.listForVehicle(_vehicle, includeRetired: true);
      // Retired means gone for good. Flagging it missing would park it on the
      // attention list forever waiting for something nobody expects back.
      expect(all.single.asset.isMissing, isFalse);
    });
  });

  group('immutability', () {
    test('a counter-signed receipt cannot be edited', () async {
      await givenTool();
      final draft = await receipts.startReceipt(_vehicle);
      final signed = await signedBy(draft);

      final complete = await receipts.save(
        signed.copyWith(
          dispatcherSignaturePath: 'signatures/fleet/${signed.id}_dispatcher.png',
          dispatcherSignedAt: DateTime.now().toUtc(),
        ),
      );
      expect(complete.stage, ReceiptStage.complete);

      // Mirrors the database trigger. Without it the screen would accept the
      // edit, queue it, and only fail hours later.
      expect(
        () => receipts.save(complete.copyWith(notes: 'changed my mind')),
        throwsA(isA<ReceiptIsFinalized>()),
      );
    });

    test('a receipt awaiting verification is still editable by dispatch',
        () async {
      await givenTool();
      final draft = await receipts.startReceipt(_vehicle);
      final signed = await signedBy(draft);

      final updated =
          await receipts.save(signed.copyWith(dispatcherName: 'Morgan R.'));
      expect(updated.dispatcherName, 'Morgan R.');
    });
  });

  group('stages', () {
    test('draft, then awaiting, then complete', () async {
      await givenTool();
      final draft = await receipts.startReceipt(_vehicle);
      expect(draft.stage, ReceiptStage.draft);

      final signed = await signedBy(draft);
      expect(signed.stage, ReceiptStage.awaitingCountersign);

      final complete = await receipts.save(
        signed.copyWith(
          dispatcherSignaturePath: 'p.png',
          dispatcherSignedAt: DateTime.now().toUtc(),
        ),
      );
      expect(complete.stage, ReceiptStage.complete);
    });

    test('history comes back newest first, with its lines', () async {
      await givenTool();
      final first = await signedBy(await receipts.startReceipt(_vehicle));
      await Future<void>.delayed(const Duration(milliseconds: 5));
      final second = await signedBy(
        (await receipts.startReceipt(_vehicle))
            .copyWith(checkedAt: DateTime.now().toUtc().add(const Duration(minutes: 1))),
      );

      final history = await receipts.listForVehicle(_vehicle);

      expect(history.map((c) => c.id), [second.id, first.id]);
      expect(history.first.lines, hasLength(1));
    });

    test('two receipts on the same day are both kept', () async {
      // No unique index on (vehicle, date), on purpose: vans go out twice and
      // drivers swap mid-shift. A uniqueness rule here would surface as a
      // duplicate-key error in a yard with no signal.
      await givenTool();
      await signedBy(await receipts.startReceipt(_vehicle));
      await signedBy(await receipts.startReceipt(_vehicle));

      expect(await receipts.listForVehicle(_vehicle), hasLength(2));
    });
  });

  group('the disclaimer', () {
    test('falls back to the built-in transcription when nothing is published',
        () async {
      final disclaimer = await receipts.currentDisclaimer();

      expect(disclaimer.version, kBuiltInDisclaimerVersion);
      expect(disclaimer.clauses, hasLength(5));
      expect(disclaimer.clauses.first.heading, 'Responsibility');
    });

    test('prefers the newest published version', () async {
      for (final version in [1, 2]) {
        await disclaimerBox.put(
          'd$version',
          AssetDisclaimerRecord(
            id: 'd$version',
            tenantId: _tenant,
            version: version,
            clausesJson: encodeClauses(
              [DisclaimerClause(heading: 'H$version', body: 'B$version')],
            ),
            publishedAt: DateTime.utc(2026, version),
          ),
        );
      }

      expect((await receipts.currentDisclaimer()).version, 2);
    });

    test('a signed receipt can still fetch the version it was signed under',
        () async {
      for (final version in [1, 2]) {
        await disclaimerBox.put(
          'd$version',
          AssetDisclaimerRecord(
            id: 'd$version',
            tenantId: _tenant,
            version: version,
            clausesJson: encodeClauses(
              [DisclaimerClause(heading: 'H$version', body: 'B$version')],
            ),
            publishedAt: DateTime.utc(2026, version),
          ),
        );
      }

      // Reprinting a 2026 receipt with 2027 clauses would misstate what the
      // person agreed to.
      final signed = await receipts.disclaimerVersion(1);
      expect(signed.version, 1);
      expect(signed.clauses.single.heading, 'H1');
    });

    test('an unavailable version says so instead of substituting another',
        () async {
      final missing = await receipts.disclaimerVersion(7);

      expect(missing.version, 7);
      expect(missing.clauses, isEmpty);
      expect(missing.intro, contains('not available on this device'));
    });

    test('the built-in text matches the seed SQL word for word', () {
      // Two sources of a legal clause is one too many. The app falls back to
      // the constant offline; the database gets the seed. If they drift, some
      // drivers accept one wording and some another, and nothing in the record
      // would show it.
      final seed = File('supabase/manual/seed_asset_disclaimer.sql')
          .readAsStringSync();

      for (final clause in kBuiltInDisclaimerClauses) {
        expect(
          seed.contains(clause.heading),
          isTrue,
          reason: 'seed SQL is missing the "${clause.heading}" clause',
        );
        expect(
          seed.contains(clause.body),
          isTrue,
          reason: 'the "${clause.heading}" clause body differs between '
              'kBuiltInDisclaimerClauses and the seed SQL',
        );
      }
      expect(seed.contains(kBuiltInDisclaimerIntro), isTrue);
      expect(seed.contains(kBuiltInDisclaimerClosing), isTrue);
    });
  });

  group('supabase mapping', () {
    test('a header round-trips', () async {
      await givenTool();
      final signed = await signedBy(await receipts.startReceipt(_vehicle));

      final restored =
          assetCheckFromSupabaseJson(assetCheckToSupabaseJson(signed));

      expect(restored.id, signed.id);
      expect(restored.operatorName, 'Steve');
      expect(restored.dispatcherName, 'Morgan');
      expect(restored.disclaimerVersion, signed.disclaimerVersion);
      expect(restored.operatorSignedAt, signed.operatorSignedAt);
      expect(restored.operatorSignaturePath, signed.operatorSignaturePath);
    });

    test('a line round-trips, snapshot included', () async {
      await givenTool(name: 'IDEAL METAL FISH TAPE', partNumber: '31-056');
      final draft = await receipts.startReceipt(_vehicle);
      final line = draft.lines.single
          .copyWith(readiness: AssetReadiness.nmc, reason: 'Kinked');

      final restored =
          assetCheckLineFromSupabaseJson(assetCheckLineToSupabaseJson(line));

      expect(restored.assetName, 'IDEAL METAL FISH TAPE');
      expect(restored.partNumber, '31-056');
      expect(restored.readiness, AssetReadiness.nmc);
      expect(restored.reason, 'Kinked');
      expect(restored.isException, isTrue);
    });

    test('clauses survive both encodings', () {
      const clauses = [
        DisclaimerClause(heading: 'Responsibility', body: 'Body one.'),
        DisclaimerClause(heading: 'Condition', body: 'Body two.'),
      ];

      // Supabase hands back a decoded list; Hive hands back a JSON string.
      // Both land in decodeClauses so the two paths cannot disagree.
      expect(decodeClauses(encodeClauses(clauses)), clauses);
      expect(
        decodeClauses(clauses.map((c) => c.toJson()).toList()),
        clauses,
      );
      expect(decodeClauses(null), isEmpty);
    });
  });
}
