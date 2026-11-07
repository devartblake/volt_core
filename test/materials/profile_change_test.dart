import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/modules/materials/domain/material_item.dart';
import 'package:voltcore/modules/materials/domain/material_list.dart';
import 'package:voltcore/modules/materials/domain/profile_change.dart';
import 'package:voltcore/modules/materials/infra/materials_repository.dart';
import 'package:voltcore/modules/materials/infra/profile_changes_repository.dart';

MaterialItem item(
  String id,
  MaterialSlot slot, {
  MaterialRole role = MaterialRole.none,
  String pn = '',
  String name = '',
  String mfr = '',
  int qty = 1,
}) =>
    MaterialItem(
      id: id,
      slot: slot,
      role: role,
      partNumber: pn,
      partName: name,
      manufacturer: mfr,
      quantity: qty,
    );

/// A Hive box that lives in memory, so the repository can be tested without
/// disk or timers.
class MemBox implements Box<String> {
  final Map<dynamic, String> map = {};
  @override
  String? get(dynamic key, {String? defaultValue}) => map[key] ?? defaultValue;
  @override
  Future<void> put(dynamic key, String value) async => map[key] = value;
  @override
  Iterable<String> get values => map.values;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A memory-only stand-in for the materials store.
class MemMaterials extends MaterialsRepository {
  MemMaterials([Map<String, List<MaterialItem>>? seed]) : store = seed ?? {};
  final Map<String, List<MaterialItem>> store;
  int saves = 0;
  @override
  Future<List<({MaterialOwnerType type, String id, List<MaterialItem> items})>>
      allJobLists() async => const [];
  @override
  Future<List<MaterialItem>> load(MaterialOwner o) async =>
      store[o.storeKey] ?? const [];
  @override
  Future<List<MaterialItem>> save(MaterialOwner o, List<MaterialItem> i) async {
    saves++;
    return store[o.storeKey] = MaterialListOps.forSaving(i);
  }
}

void main() {
  final oil1 = item('o1', MaterialSlot.oilFilter,
      role: MaterialRole.primary, pn: 'LF3000', name: 'Oil', qty: 1);
  final oil2 = item('o2', MaterialSlot.oilFilter,
      role: MaterialRole.secondary, pn: 'LF9000');
  final air = item('a1', MaterialSlot.airFilter, pn: 'AF25');

  group('diffProfiles', () {
    test('no change gives no changes, whatever the order', () {
      expect(ProfileChanges.diffProfiles([oil1, oil2, air], [air, oil2, oil1]),
          isEmpty);
    });

    test('a new part is an add with its slot, role and fields', () {
      final fuel = item('f1', MaterialSlot.fuelFilter,
          role: MaterialRole.primary,
          pn: 'FS1',
          name: 'Fuel',
          mfr: 'Fleetguard',
          qty: 2);
      final d = ProfileChanges.diffProfiles([oil1], [oil1, fuel]);
      expect(d, hasLength(1));
      expect(d.single.kind, ProfileChangeKind.add);
      expect(d.single.slot, MaterialSlot.fuelFilter);
      expect(d.single.item.partNumber, 'FS1');
      expect(d.single.item.manufacturer, 'Fleetguard');
      expect(d.single.item.quantity, 2);
      expect(d.single.item.role, MaterialRole.primary);
    });

    test('a missing part is a remove', () {
      final d = ProfileChanges.diffProfiles([oil1, air], [oil1]);
      expect(d.single.kind, ProfileChangeKind.remove);
      expect(d.single.itemId, 'a1');
    });

    test('an edited part is an update listing only the fields that moved', () {
      final d = ProfileChanges.diffProfiles(
        [oil1],
        [oil1.copyWith(partNumber: 'LF3001', quantity: 2)],
      );
      expect(d.single.kind, ProfileChangeKind.update);
      expect(d.single.fields.map((f) => f.field), ['partNumber', 'quantity']);
      expect(d.single.fields.first.from, 'LF3000');
      expect(d.single.fields.first.to, 'LF3001');
      expect(d.single.fields.last.from, '1');
      expect(d.single.fields.last.to, '2');
    });

    test('a role swap shows as an update on both parts', () {
      final d = ProfileChanges.diffProfiles([oil1, oil2], [
        oil1.copyWith(role: MaterialRole.secondary),
        oil2.copyWith(role: MaterialRole.primary),
      ]);
      expect(d, hasLength(2));
      expect(d.every((c) => c.fields.single.field == 'role'), isTrue);
    });

    test('whitespace-only differences and blank new parts are ignored', () {
      final d = ProfileChanges.diffProfiles(
        [oil1],
        [
          oil1.copyWith(partNumber: ' LF3000 '),
          item('blank', MaterialSlot.battery),
        ],
      );
      expect(d, isEmpty);
    });

    test('empty to full is all adds; full to empty is all removes', () {
      expect(ProfileChanges.diffProfiles([], [oil1, air]),
          hasLength(2));
      expect(
          ProfileChanges.diffProfiles([oil1, air], []).map((c) => c.kind),
          [ProfileChangeKind.remove, ProfileChangeKind.remove]);
    });
  });

  group('applyChanges', () {
    test('applying a diff to the same profile gives the proposed list', () {
      final proposed = [
        oil1.copyWith(partNumber: 'LF3001'),
        item('f1', MaterialSlot.fuelFilter, pn: 'FS1'),
      ];
      final changes = ProfileChanges.diffProfiles([oil1, oil2, air], proposed);
      final r = ProfileChanges.applyChanges([oil1, oil2, air], changes);
      final byId = {for (final i in r.items) i.id: i};
      expect(byId['o1']!.partNumber, 'LF3001');
      expect(byId.containsKey('o2'), isFalse);
      expect(byId.containsKey('a1'), isFalse);
      expect(byId['f1']!.partNumber, 'FS1');
      expect(r.applied, hasLength(4));
      expect(r.skippedStale, isEmpty);
    });

    test('removing the primary promotes the secondary', () {
      final changes = ProfileChanges.diffProfiles([oil1, oil2], [oil2]);
      final r = ProfileChanges.applyChanges([oil1, oil2], changes);
      expect(r.items.single.id, 'o2');
      expect(r.items.single.role, MaterialRole.primary);
    });

    test('adding a second primary leaves one primary only', () {
      final extra = item('o3', MaterialSlot.oilFilter,
          role: MaterialRole.primary, pn: 'NEW');
      final changes = ProfileChanges.diffProfiles([oil1, oil2], [oil1, oil2, extra]);
      final r = ProfileChanges.applyChanges([oil1, oil2], changes);
      final oils = r.items.where((i) => i.slot == MaterialSlot.oilFilter);
      expect(oils.where((i) => i.role == MaterialRole.primary), hasLength(1));
      expect(oils.where((i) => i.role == MaterialRole.secondary), hasLength(1));
      expect(oils, hasLength(3));
    });

    test('only the chosen changes are applied', () {
      final changes = ProfileChanges.diffProfiles(
        [oil1, air],
        [oil1.copyWith(partNumber: 'X'), air.copyWith(partNumber: 'Y')],
      );
      final r =
          ProfileChanges.applyChanges([oil1, air], changes, only: {'a1'});
      final byId = {for (final i in r.items) i.id: i};
      expect(byId['a1']!.partNumber, 'Y');
      expect(byId['o1']!.partNumber, 'LF3000');
      expect(r.applied, ['a1']);
    });

    test('applying nothing leaves the list as it was', () {
      final r = ProfileChanges.applyChanges([oil1, air], const []);
      expect(r.items.map((i) => i.id).toSet(), {'o1', 'a1'});
    });
  });

  group('conflicts', () {
    test('an update is stale when the part was changed since', () {
      final changes = ProfileChanges.diffProfiles(
          [oil1], [oil1.copyWith(partNumber: 'LF3001')]);
      final moved = oil1.copyWith(partNumber: 'SOMEONE-ELSE');
      expect(ProfileChanges.stateOf([moved], changes.single), ChangeState.stale);
      expect(ProfileChanges.stateOf([oil1], changes.single), ChangeState.ok);
    });

    test('an update is stale when the part is gone', () {
      final changes = ProfileChanges.diffProfiles(
          [oil1], [oil1.copyWith(partNumber: 'LF3001')]);
      expect(ProfileChanges.stateOf([], changes.single), ChangeState.stale);
    });

    test('an update the profile already has is already applied', () {
      final changes = ProfileChanges.diffProfiles(
          [oil1], [oil1.copyWith(partNumber: 'LF3001')]);
      expect(
        ProfileChanges.stateOf(
            [oil1.copyWith(partNumber: 'LF3001')], changes.single),
        ChangeState.alreadyApplied,
      );
    });

    test('a remove is stale when the part changed, already done when gone', () {
      final changes = ProfileChanges.diffProfiles([air], []);
      expect(ProfileChanges.stateOf([air.copyWith(partNumber: 'Z')], changes.single),
          ChangeState.stale);
      expect(ProfileChanges.stateOf([], changes.single),
          ChangeState.alreadyApplied);
      expect(ProfileChanges.stateOf([air], changes.single), ChangeState.ok);
    });

    test('an add is stale when a single slot has been filled meanwhile', () {
      final proposed = [item('a2', MaterialSlot.airFilter, pn: 'NEW')];
      final changes = ProfileChanges.diffProfiles([], proposed);
      expect(ProfileChanges.stateOf([air], changes.single), ChangeState.stale);
      expect(ProfileChanges.stateOf([], changes.single), ChangeState.ok);
      // A multi slot has room.
      final fuelAdd = ProfileChanges.diffProfiles(
          [], [item('f9', MaterialSlot.fuelFilter, pn: 'F')]);
      expect(
          ProfileChanges.stateOf(
              [item('f1', MaterialSlot.fuelFilter, pn: 'F0')], fuelAdd.single),
          ChangeState.ok);
    });

    test('stale changes are left out but the rest apply', () {
      final changes = ProfileChanges.diffProfiles(
        [oil1, air],
        [oil1.copyWith(partNumber: 'X'), air.copyWith(partNumber: 'Y')],
      );
      // Someone changed the oil filter meanwhile.
      final now = [oil1.copyWith(partNumber: 'OTHER'), air];
      final r = ProfileChanges.applyChanges(now, changes);
      final byId = {for (final i in r.items) i.id: i};
      expect(byId['o1']!.partNumber, 'OTHER');
      expect(byId['a1']!.partNumber, 'Y');
      expect(r.applied, ['a1']);
      expect(r.skippedStale, ['o1']);
    });

    test('the reviewer can force a stale update, but not one on a missing part',
        () {
      final changes = ProfileChanges.diffProfiles(
          [oil1], [oil1.copyWith(partNumber: 'X')]);
      final moved = [oil1.copyWith(partNumber: 'OTHER')];
      final forced =
          ProfileChanges.applyChanges(moved, changes, includeStale: true);
      expect(forced.items.single.partNumber, 'X');

      final gone = ProfileChanges.applyChanges([], changes, includeStale: true);
      expect(gone.items, isEmpty);
      expect(gone.applied, isEmpty);
      expect(gone.skippedStale, ['o1']);
    });

    test('already-applied changes are reported, not re-applied', () {
      final changes = ProfileChanges.diffProfiles([air], []);
      final r = ProfileChanges.applyChanges([], changes);
      expect(r.alreadyApplied, ['a1']);
      expect(r.applied, isEmpty);
    });
  });

  group('proposalFromJob', () {
    test('a job list that matches the profile proposes nothing', () {
      final job = MaterialListOps.cloneWithNewIds([oil1, oil2, air]);
      final proposed = ChangesHelper.fromJob([oil1, oil2, air], job);
      expect(proposed, isEmpty);
    });

    test('a different part number on a single slot is an update', () {
      final job = MaterialListOps.cloneWithNewIds(
          [air.copyWith(partNumber: 'AF99')]);
      final changes = ChangesHelper.fromJob([air], job);
      expect(changes.single.kind, ProfileChangeKind.update);
      expect(changes.single.itemId, 'a1');
      expect(changes.single.fields.single.to, 'AF99');
    });

    test('a new part number on a multi slot is an add, and the old one a remove',
        () {
      final job = MaterialListOps.cloneWithNewIds(
          [oil1.copyWith(partNumber: 'NEW-OIL')]);
      final changes = ChangesHelper.fromJob([oil1], job);
      expect(changes.map((c) => c.kind).toSet(),
          {ProfileChangeKind.add, ProfileChangeKind.remove});
    });

    test('profile dates are not turned into changes', () {
      final dated = oil1.copyWith(dateUsed: DateTime(2026, 1, 5));
      final job = MaterialListOps.cloneWithNewIds([oil1]);
      expect(ChangesHelper.fromJob([dated], job), isEmpty);
    });
  });

  group('serialisation', () {
    test('a request survives JSON and a cloud row', () {
      final changes = ProfileChanges.diffProfiles(
          [oil1], [oil1.copyWith(partNumber: 'X'), air]);
      final r = ProfileChangeRequest(
        id: 'r1',
        generatorKey: 'g|rg|1',
        make: 'Generac',
        model: 'RG',
        serial: '1',
        proposedBy: 'u1',
        proposedByName: 'Tech One',
        createdAt: DateTime.utc(2026, 11, 8, 9),
        updatedAt: DateTime.utc(2026, 11, 8, 9),
        note: 'Wrong filter',
        changes: changes,
      );
      final back = ProfileChangeRequest.decode(ProfileChangeRequest.encode(r))!;
      expect(back.changes, hasLength(2));
      expect(back.changes.first.fields.single.to, 'X');
      expect(back.note, 'Wrong filter');

      final row = profileChangeToRow(r, 'tenant');
      expect(row['tenant_id'], 'tenant');
      expect(row['equipment_key'], 'g|rg|1');
      expect(row['status'], 'pending');
      final fromRow = profileChangeFromRow(row)!;
      expect(fromRow.id, 'r1');
      expect(fromRow.proposedByName, 'Tech One');
      expect(fromRow.changes, hasLength(2));
    });

    test('junk decodes to null instead of throwing', () {
      expect(ProfileChangeRequest.decode('not json'), isNull);
      expect(ProfileChangeRequest.decode('{"id":""}'), isNull);
    });
  });

  group('ProfileChangesRepository', () {
    const owner = MaterialOwner.generator(
        key: 'g|rg|1', make: 'Generac', model: 'RG', serial: '1');
    late MemBox box;
    late List<Map<String, dynamic>> upserts;
    late int n;
    late DateTime clock;
    late String? tenant;

    ProfileChangesRepository repo({
      String user = 'tech-1',
      List<Map<String, dynamic>> cloud = const [],
    }) =>
        ProfileChangesRepository(
          box: box,
          upsert: (t, id, row) async => upserts.add({...row, '_table': t}),
          fetch: (t) async => cloud,
          tenantId: () => tenant,
          userId: () => user,
          newId: () => 'req-${++n}',
          now: () => clock = clock.add(const Duration(minutes: 1)),
        );

    setUp(() {
      box = MemBox();
      upserts = [];
      n = 0;
      clock = DateTime.utc(2026, 11, 8, 9);
      tenant = 'tenant-1';
    });

    test('propose stores a pending request, queues it, and leaves the profile alone',
        () async {
      final materials = MemMaterials({
        owner.storeKey: [oil1]
      });
      final r = await repo().propose(
        generatorKey: owner.key,
        make: 'Generac',
        model: 'RG',
        serial: '1',
        current: [oil1],
        proposed: [oil1.copyWith(partNumber: 'X')],
        note: '  wrong  ',
        proposedByName: 'Tech One',
      );
      expect(r.status, ProfileRequestStatus.pending);
      expect(r.note, 'wrong');
      expect(r.proposedBy, 'tech-1');
      expect(upserts.single['_table'], kProfileChangeRequestsTable);
      expect(upserts.single['status'], 'pending');
      expect(materials.store[owner.storeKey]!.single.partNumber, 'LF3000');
      expect(materials.saves, 0);
      expect(await repo().pending(), hasLength(1));
    });

    test('propose needs a reason and a real difference', () async {
      expect(
        () => repo().propose(
            generatorKey: owner.key,
            current: [oil1],
            proposed: [oil1.copyWith(partNumber: 'X')],
            note: '  '),
        throwsArgumentError,
      );
      expect(
        () => repo().propose(
            generatorKey: owner.key,
            current: [oil1],
            proposed: [oil1],
            note: 'why'),
        throwsArgumentError,
      );
    });

    test('with no tenant the request stays on the device only', () async {
      tenant = null;
      await repo().propose(
          generatorKey: owner.key,
          current: [],
          proposed: [air],
          note: 'missing');
      expect(upserts, isEmpty);
      expect(await repo().all(), hasLength(1));
    });

    test('withdraw only works on a pending request', () async {
      final r = await repo().propose(
          generatorKey: owner.key, current: [], proposed: [air], note: 'x');
      final w = await repo().withdraw(r.id);
      expect(w!.status, ProfileRequestStatus.withdrawn);
      expect(upserts.last['status'], 'withdrawn');
      expect(await repo().pending(), isEmpty);
      // Withdrawn stays withdrawn; rejecting it does nothing.
      final again = await repo(user: 'sup').reject(r.id, note: 'no');
      expect(again!.status, ProfileRequestStatus.withdrawn);
    });

    test('reject leaves the profile alone and records who and why', () async {
      final materials = MemMaterials({
        owner.storeKey: [oil1]
      });
      final r = await repo().propose(
          generatorKey: owner.key,
          current: [oil1],
          proposed: [oil1.copyWith(partNumber: 'X')],
          note: 'x');
      final rej = await repo(user: 'sup-1').reject(r.id, note: ' not right ');
      expect(rej!.status, ProfileRequestStatus.rejected);
      expect(rej.reviewedBy, 'sup-1');
      expect(rej.reviewNote, 'not right');
      expect(rej.reviewedAt, isNotNull);
      expect(materials.store[owner.storeKey]!.single.partNumber, 'LF3000');
      expect(materials.saves, 0);
    });

    test('approve applies to the profile through the materials store', () async {
      final materials = MemMaterials({
        owner.storeKey: [oil1, air]
      });
      final r = await repo().propose(
          generatorKey: owner.key,
          make: 'Generac',
          model: 'RG',
          serial: '1',
          current: [oil1, air],
          proposed: [oil1.copyWith(partNumber: 'X')],
          note: 'x');
      final result = await repo(user: 'sup-1')
          .approve(r.id, materials: materials);
      expect(result.applied, hasLength(2));
      expect(materials.saves, 1);
      expect(materials.store[owner.storeKey]!.single.partNumber, 'X');
      final saved = (await repo().byId(r.id))!;
      expect(saved.status, ProfileRequestStatus.approved);
      expect(saved.reviewedBy, 'sup-1');
      expect(upserts.last['status'], 'approved');
    });

    test('approve selected applies only those and still closes the request',
        () async {
      final materials = MemMaterials({
        owner.storeKey: [oil1, air]
      });
      final r = await repo().propose(
          generatorKey: owner.key,
          current: [oil1, air],
          proposed: [oil1.copyWith(partNumber: 'X'), air.copyWith(partNumber: 'Y')],
          note: 'x');
      await repo(user: 'sup').approve(r.id,
          materials: materials, only: {'a1'});
      final byId = {for (final i in materials.store[owner.storeKey]!) i.id: i};
      expect(byId['a1']!.partNumber, 'Y');
      expect(byId['o1']!.partNumber, 'LF3000');
    });

    test('approve with only stale changes applies nothing and stays pending',
        () async {
      final materials = MemMaterials({
        owner.storeKey: [oil1.copyWith(partNumber: 'OTHER')]
      });
      final r = await repo().propose(
          generatorKey: owner.key,
          current: [oil1],
          proposed: [oil1.copyWith(partNumber: 'X')],
          note: 'x');
      final result = await repo(user: 'sup').approve(r.id, materials: materials);
      expect(result.applied, isEmpty);
      expect(result.skippedStale, ['o1']);
      expect(materials.saves, 0);
      expect((await repo().byId(r.id))!.status, ProfileRequestStatus.pending);
      // Forcing it through is the reviewer's call.
      await repo(user: 'sup').approve(r.id,
          materials: materials, only: {'o1'}, includeStale: true);
      expect(materials.store[owner.storeKey]!.single.partNumber, 'X');
    });

    test('forGenerator and newest-first ordering', () async {
      final a = await repo().propose(
          generatorKey: 'k1', current: [], proposed: [air], note: 'a');
      final b = await repo().propose(
          generatorKey: 'k2', current: [], proposed: [air], note: 'b');
      final c = await repo().propose(
          generatorKey: 'k1', current: [], proposed: [oil1], note: 'c');
      expect((await repo().all()).map((r) => r.id), [c.id, b.id, a.id]);
      expect((await repo().forGenerator('k1')).map((r) => r.id), [c.id, a.id]);
    });

    test('refreshFromCloud adds new rows and keeps the newer copy', () async {
      final local = await repo().propose(
          generatorKey: owner.key, current: [], proposed: [air], note: 'x');
      final approved = local.copyWith(
        status: ProfileRequestStatus.approved,
        updatedAt: local.updatedAt.add(const Duration(hours: 1)),
      );
      final other = ProfileChangeRequest(
        id: 'remote-1',
        generatorKey: 'k9',
        proposedBy: 'tech-2',
        createdAt: DateTime.utc(2026, 11, 8),
        updatedAt: DateTime.utc(2026, 11, 8),
        changes: ProfileChanges.diffProfiles([], [air]),
      );
      final stale = local.copyWith(
          status: ProfileRequestStatus.rejected,
          updatedAt: local.updatedAt.subtract(const Duration(days: 1)));
      final count = await repo(cloud: [
        profileChangeToRow(approved, 't'),
        profileChangeToRow(other, 't'),
        profileChangeToRow(stale, 't'),
      ]).refreshFromCloud();
      expect(count, 2);
      expect((await repo().byId(local.id))!.status,
          ProfileRequestStatus.approved);
      expect(await repo().byId('remote-1'), isNotNull);
    });
  });
}

/// The diff of the profile against a job's list, as the technician flow does.
class ChangesHelper {
  static List<ProfileItemChange> fromJob(
    List<MaterialItem> profile,
    List<MaterialItem> job,
  ) =>
      ProfileChanges.diffProfiles(
          profile, ProfileChanges.proposalFromJob(profile, job));
}
