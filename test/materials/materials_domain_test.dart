import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/modules/materials/domain/material_item.dart';
import 'package:voltcore/modules/materials/domain/material_list.dart';
import 'package:voltcore/modules/materials/infra/materials_repository.dart';

MaterialItem _item(
  String id,
  MaterialSlot slot, {
  MaterialRole role = MaterialRole.none,
  String part = '',
}) =>
    MaterialItem(id: id, slot: slot, role: role, partNumber: part);

List<MaterialItem> _slot(List<MaterialItem> l, MaterialSlot s) =>
    MaterialListOps.forSlot(l, s);

void main() {
  group('slots', () {
    test('there are ten, with the right ones taking more than one', () {
      expect(MaterialSlot.values.length, 10);
      final multi = MaterialSlot.values.where((s) => s.multiple).toSet();
      expect(multi, {
        MaterialSlot.fuelFilter,
        MaterialSlot.oilFilter,
        MaterialSlot.lubeFilter,
        MaterialSlot.battery,
        MaterialSlot.additionalParts,
      });
    });

    test('additional parts are a plain list with no primary / secondary', () {
      expect(MaterialSlot.additionalParts.usesRoles, isFalse);
      expect(MaterialSlot.oilFilter.usesRoles, isTrue);
    });

    test('wire names round-trip and are unique', () {
      final wires = MaterialSlot.values.map((s) => s.wire).toSet();
      expect(wires.length, 10);
      for (final s in MaterialSlot.values) {
        expect(MaterialSlot.fromWire(s.wire), s);
      }
      expect(MaterialSlot.fromWire('nope'), isNull);
    });
  });

  group('MaterialItem', () {
    test('a fresh item is blank; any detail makes it not blank', () {
      expect(_item('a', MaterialSlot.airFilter).isBlank, isTrue);
      expect(_item('a', MaterialSlot.airFilter, part: 'AF-1').isBlank, isFalse);
      expect(
          _item('a', MaterialSlot.airFilter).copyWith(needsReplacement: true).isBlank,
          isFalse);
    });

    test('quantity never goes below zero', () {
      expect(_item('a', MaterialSlot.airFilter).copyWith(quantity: -3).quantity, 0);
    });

    test('the date can be set and cleared', () {
      final i = _item('a', MaterialSlot.airFilter)
          .copyWith(dateUsed: DateTime(2026, 11, 3));
      expect(i.dateUsed, DateTime(2026, 11, 3));
      expect(i.copyWith(dateUsed: null).dateUsed, isNull);
      // Changing something else leaves the date alone.
      expect(i.copyWith(quantity: 2).dateUsed, DateTime(2026, 11, 3));
    });

    test('JSON round-trips every field', () {
      final i = MaterialItem(
        id: 'x',
        slot: MaterialSlot.fuelFilter,
        role: MaterialRole.secondary,
        partNumber: 'FF-5',
        partName: 'Fleetguard fuel filter',
        manufacturer: 'Fleetguard',
        quantity: 2,
        dateUsed: DateTime(2026, 10, 1),
        needsReplacement: true,
        notes: 'spin-on',
      );
      expect(MaterialItem.fromJson(i.toJson()), i);
    });

    test('a list survives encode/decode and skips unknown slots and garbage',
        () {
      final raw = MaterialItem.encodeList([_item('a', MaterialSlot.battery)]);
      expect(MaterialItem.decodeList(raw).length, 1);
      expect(MaterialItem.decodeList(null), isEmpty);
      expect(MaterialItem.decodeList('not json'), isEmpty);
      expect(
          MaterialItem.decodeList('[{"id":"z","slot":"future_slot"}]'), isEmpty);
    });
  });

  group('generatorProfileKey', () {
    test('ignores case and spacing', () {
      expect(
        generatorProfileKey(make: ' Generac ', model: 'RG  048', serial: 'sn1'),
        generatorProfileKey(make: 'generac', model: 'rg 048', serial: 'SN1'),
      );
    });

    test('differs by serial', () {
      expect(
        generatorProfileKey(make: 'Generac', model: 'RG048', serial: '1'),
        isNot(generatorProfileKey(make: 'Generac', model: 'RG048', serial: '2')),
      );
    });

    test('is empty when nothing identifies the generator', () {
      expect(generatorProfileKey(make: '', model: '', serial: ''), '');
      expect(generatorProfileKey(make: 'Generac', model: '', serial: ''), '');
      expect(generatorProfileKey(make: '', model: '', serial: 'K79'), isNotEmpty);
    });
  });

  group('MaterialListOps', () {
    test('a single-item slot takes only one', () {
      var l = MaterialListOps.add(const [], MaterialSlot.airFilter);
      l = MaterialListOps.add(l, MaterialSlot.airFilter);
      expect(_slot(l, MaterialSlot.airFilter).length, 1);
    });

    test('multi slots: first is primary, second secondary, then unlabelled', () {
      var l = <MaterialItem>[];
      for (var i = 0; i < 4; i++) {
        l = MaterialListOps.add(l, MaterialSlot.oilFilter);
      }
      final roles = _slot(l, MaterialSlot.oilFilter).map((i) => i.role).toList();
      expect(roles, [
        MaterialRole.primary,
        MaterialRole.secondary,
        MaterialRole.none,
        MaterialRole.none,
      ]);
    });

    test('additional parts never get roles', () {
      var l = MaterialListOps.add(const [], MaterialSlot.additionalParts);
      l = MaterialListOps.add(l, MaterialSlot.additionalParts);
      expect(_slot(l, MaterialSlot.additionalParts).length, 2);
      expect(
          _slot(l, MaterialSlot.additionalParts).every((i) => i.role == MaterialRole.none),
          isTrue);
    });

    test('removing the primary promotes the next item', () {
      var l = <MaterialItem>[
        _item('p', MaterialSlot.fuelFilter, role: MaterialRole.primary),
        _item('s', MaterialSlot.fuelFilter, role: MaterialRole.secondary),
      ];
      l = MaterialListOps.remove(l, 'p');
      expect(l.single.id, 's');
      expect(l.single.role, MaterialRole.primary);
    });

    test('making an item primary demotes the old primary and keeps one each', () {
      var l = <MaterialItem>[
        _item('a', MaterialSlot.oilFilter, role: MaterialRole.primary),
        _item('b', MaterialSlot.oilFilter, role: MaterialRole.secondary),
        _item('c', MaterialSlot.oilFilter),
      ];
      l = MaterialListOps.setRole(l, 'c', MaterialRole.primary);
      final byId = {for (final i in l) i.id: i.role};
      expect(byId['c'], MaterialRole.primary);
      expect(byId['a'], MaterialRole.secondary);
      expect(byId['b'], MaterialRole.none);
    });

    test('swapping secondary to primary trades places', () {
      var l = <MaterialItem>[
        _item('a', MaterialSlot.lubeFilter, role: MaterialRole.primary),
        _item('b', MaterialSlot.lubeFilter, role: MaterialRole.secondary),
      ];
      l = MaterialListOps.setRole(l, 'b', MaterialRole.primary);
      final byId = {for (final i in l) i.id: i.role};
      expect(byId['b'], MaterialRole.primary);
      expect(byId['a'], MaterialRole.secondary);
    });

    test('normalize repairs two primaries and no primary', () {
      final two = MaterialListOps.normalize([
        _item('a', MaterialSlot.oilFilter, role: MaterialRole.primary),
        _item('b', MaterialSlot.oilFilter, role: MaterialRole.primary),
      ]);
      expect(two.where((i) => i.role == MaterialRole.primary).length, 1);

      final none = MaterialListOps.normalize([
        _item('a', MaterialSlot.oilFilter),
        _item('b', MaterialSlot.oilFilter),
      ]);
      expect(none.first.role, MaterialRole.primary);
    });

    test('forSaving drops blank items but keeps real ones', () {
      final out = MaterialListOps.forSaving([
        _item('blank', MaterialSlot.airFilter),
        _item('real', MaterialSlot.fuelFilter, part: 'FF-1'),
      ]);
      expect(out.map((i) => i.id), ['real']);
      expect(out.single.role, MaterialRole.primary);
    });

    test('cloning for a job gives new ids and clears date and flag', () {
      final src = [
        MaterialItem(
          id: 'orig',
          slot: MaterialSlot.airFilter,
          partNumber: 'AF-9',
          dateUsed: DateTime(2026, 1, 1),
          needsReplacement: true,
        ),
      ];
      final copy = MaterialListOps.cloneWithNewIds(src);
      expect(copy.single.id, isNot('orig'));
      expect(copy.single.partNumber, 'AF-9');
      expect(copy.single.dateUsed, isNull);
      expect(copy.single.needsReplacement, isFalse);
    });

    test('needed() returns only items due for replacement', () {
      final l = [
        _item('a', MaterialSlot.airFilter, part: '1'),
        _item('b', MaterialSlot.battery, part: '2').copyWith(needsReplacement: true),
      ];
      expect(MaterialListOps.needed(l).map((i) => i.id), ['b']);
    });

    test('legacy dates are read from the primary item of each slot', () {
      final l = [
        MaterialItem(
          id: 'o',
          slot: MaterialSlot.oilFilter,
          role: MaterialRole.primary,
          dateUsed: DateTime(2026, 10, 2),
        ),
        MaterialItem(
          id: 'b',
          slot: MaterialSlot.battery,
          role: MaterialRole.primary,
          dateUsed: DateTime(2025, 5, 6),
        ),
      ];
      final d = MaterialListOps.legacyDates(l);
      expect(d.oil, '2026-10-02');
      expect(d.battery, '2025-05-06');
      expect(d.fuel, '');
      expect(d.air, '');
    });

    test('old date fields seed items so the dates are not lost', () {
      final l = MaterialListOps.seedFromLegacyDates(
        oil: '2026-10-02',
        air: '2026-09-01',
        fuel: '',
        battery: 'garbage',
      );
      expect(l.length, 2);
      expect(_slot(l, MaterialSlot.oilFilter).single.dateUsed,
          DateTime(2026, 10, 2));
      expect(_slot(l, MaterialSlot.airFilter).single.dateUsed,
          DateTime(2026, 9, 1));
    });
  });

  group('MaterialsRepository', () {
    late Directory dir;
    late Box<String> box;
    late List<(String, String, Map<String, dynamic>)> upserts;
    late List<(String, String)> deletes;

    MaterialsRepository repo({String? tenant = 'tenant-1'}) =>
        MaterialsRepository(
          box: box,
          tenantId: () => tenant,
          upsert: (t, id, row) async => upserts.add((t, id, row)),
          delete: (t, id) async => deletes.add((t, id)),
        );

    setUpAll(() async {
      dir = Directory.systemTemp.createTempSync('voltcore_materials');
      Hive.init(dir.path);
      box = await Hive.openBox<String>('materials_test');
    });

    setUp(() async {
      await box.clear();
      upserts = [];
      deletes = [];
    });

    tearDownAll(() async {
      await Hive.close();
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {}
    });

    const job = MaterialOwner.inspection(id: 'insp-1', equipmentKey: 'g|rg|1');
    const profile = MaterialOwner.generator(
        key: 'g|rg|1', make: 'Generac', model: 'RG', serial: '1');

    test('saves and loads, dropping blank items', () async {
      final r = repo();
      await r.save(job, [
        _item('keep', MaterialSlot.airFilter, part: 'AF-1'),
        _item('blank', MaterialSlot.battery),
      ]);
      final back = await r.load(job);
      expect(back.map((i) => i.id), ['keep']);
    });

    test('job lines go to job_material_lines with the job fields', () async {
      await repo().save(job, [_item('a', MaterialSlot.airFilter, part: 'AF-1')]);
      expect(upserts.single.$1, kJobMaterialLinesTable);
      final row = upserts.single.$3;
      expect(row['job_type'], 'inspection');
      expect(row['job_id'], 'insp-1');
      expect(row['equipment_key'], 'g|rg|1');
      expect(row['tenant_id'], 'tenant-1');
      expect(row['slot_type'], 'air_filter');
      expect(row['part_number'], 'AF-1');
      expect(row['status'], 'listed');
    });

    test('a generator profile goes to asset_parts with the generator fields',
        () async {
      await repo().save(profile, [_item('a', MaterialSlot.battery, part: 'B1')]);
      expect(upserts.single.$1, kAssetPartsTable);
      final row = upserts.single.$3;
      expect(row['equipment_key'], 'g|rg|1');
      expect(row['make'], 'Generac');
      expect(row.containsKey('job_id'), isFalse);
    });

    test('saving again queues only what changed, and deletes what was removed',
        () async {
      final r = repo();
      final a = _item('a', MaterialSlot.airFilter, part: 'AF-1');
      final b = _item('b', MaterialSlot.coolantFilter, part: 'CF-1');
      await r.save(job, [a, b]);
      upserts.clear();

      await r.save(job, [a, b.copyWith(quantity: 3)]);
      expect(upserts.map((u) => u.$2), ['b']);

      upserts.clear();
      await r.save(job, [a]);
      expect(deletes.map((d) => d.$2), ['b']);
    });

    test('with no tenant it still saves on the device and queues nothing',
        () async {
      final r = repo(tenant: null);
      await r.save(job, [_item('a', MaterialSlot.airFilter, part: 'AF-1')]);
      expect((await r.load(job)).length, 1);
      expect(upserts, isEmpty);
    });

    test('saveDraft keeps items locally without queueing', () async {
      final r = repo();
      await r.saveDraft(job, [_item('a', MaterialSlot.airFilter)]);
      expect((await r.load(job)).length, 1);
      expect(upserts, isEmpty);
    });

    test('different owners do not mix', () async {
      final r = repo();
      await r.save(job, [_item('a', MaterialSlot.airFilter, part: '1')]);
      await r.save(profile, [_item('b', MaterialSlot.battery, part: '2')]);
      expect((await r.load(job)).single.id, 'a');
      expect((await r.load(profile)).single.id, 'b');
    });
  });
}
