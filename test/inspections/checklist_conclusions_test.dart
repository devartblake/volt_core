import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/inspections/domain/entities/inspection_entity.dart';
import 'package:voltcore/modules/inspections/domain/inspection_checklist.dart';
import 'package:voltcore/modules/inspections/infra/datasources/inspection_remote_datasource.dart';
import 'package:voltcore/modules/inspections/infra/models/inspection.dart';

void main() {
  group('the checklist is one list', () {
    test('has ten items with unique, stable keys', () {
      expect(kInspectionChecklist, hasLength(10));

      final keys = kInspectionChecklist.map((item) => item.key).toList();
      expect(keys.toSet(), hasLength(keys.length), reason: 'keys must be unique');

      // These are persisted in checklistNotes and in the sync payload. Renaming
      // one silently orphans every conclusion already written against it, so
      // they are pinned here rather than left to drift.
      expect(keys, [
        'genset_runs_under_load',
        'voltage_frequency_ok',
        'exhaust_ok',
        'grounding_bonding_ok',
        'control_panel_ok',
        'safety_devices_ok',
        'deficiencies_documented',
        'loadbank_done',
        'ats_verified',
        'fuel_stored_over_1yr',
      ]);
    });

    test('every item reads back what it writes', () {
      for (final item in kInspectionChecklist) {
        final on = item.write(InspectionEntity.newDraft(), true);
        final off = item.write(InspectionEntity.newDraft(), false);
        expect(item.read(on), isTrue, reason: item.key);
        expect(item.read(off), isFalse, reason: item.key);
      }
    });

    test('writing one item leaves the other nine alone', () {
      // Each item's write is a copyWith on a different field; a copy/paste slip
      // would have two items pointing at the same one.
      for (final item in kInspectionChecklist) {
        final entity = item.write(InspectionEntity.newDraft(), true);
        final on = kInspectionChecklist.where((i) => i.read(entity)).toList();
        expect(on, hasLength(1), reason: '${item.key} moved more than itself');
        expect(on.single.key, item.key);
      }
    });

    test('the completion count tracks the answers', () {
      var entity = InspectionEntity.newDraft();
      expect(entity.checklistCompletedCount, 0);

      entity = kInspectionChecklist[0].write(entity, true);
      entity = kInspectionChecklist[3].write(entity, true);
      expect(entity.checklistCompletedCount, 2);
    });
  });

  group('conclusions', () {
    final item = kInspectionChecklist.first;

    test('are stored against the item they belong to', () {
      final entity = InspectionEntity.newDraft()
          .withChecklistNote(item.key, 'Ran 30 min at 80% load, no alarms.');

      expect(
        entity.checklistNoteFor(item.key),
        'Ran 30 min at 80% load, no alarms.',
      );
      // An untouched item has no conclusion, rather than inheriting one.
      expect(entity.checklistNoteFor('ats_verified'), '');
    });

    test('blank text removes the note rather than storing an empty one', () {
      // The dialog returns "" for a deliberate Clear. Keeping "" would make
      // "does this item have a conclusion?" a length check instead of a key
      // check, and would print an empty row in the report.
      final withNote =
          InspectionEntity.newDraft().withChecklistNote(item.key, 'Something');
      expect(withNote.checklistNotes.containsKey(item.key), isTrue);

      final cleared = withNote.withChecklistNote(item.key, '   ');
      expect(cleared.checklistNotes.containsKey(item.key), isFalse);
      expect(cleared.checklistNoteFor(item.key), '');
    });

    test('are trimmed', () {
      final entity =
          InspectionEntity.newDraft().withChecklistNote(item.key, '  spaced  ');
      expect(entity.checklistNoteFor(item.key), 'spaced');
    });

    test('do not mutate the entity they came from', () {
      final before = InspectionEntity.newDraft();
      final after = before.withChecklistNote(item.key, 'note');

      expect(before.checklistNotes, isEmpty);
      expect(after.checklistNotes, isNotEmpty);
    });

    test('survive the Hive round trip', () {
      final original = InspectionEntity.newDraft()
          .withChecklistNote('exhaust_ok', 'Minor soot at the flange.')
          .withChecklistNote('ats_verified', 'Transferred in 8s.');

      final restored = inspectionFromEntity(original).toEntity();

      expect(restored.checklistNoteFor('exhaust_ok'), 'Minor soot at the flange.');
      expect(restored.checklistNoteFor('ats_verified'), 'Transferred in 8s.');
    });
  });

  group('the sync payload', () {
    test('carries the address parts and the conclusions', () {
      final entity = InspectionEntity.newDraft().copyWith(
        address: '952 Flushing Ave',
        addressLine2: 'Suite 3',
        city: 'Brooklyn',
        state: 'NY',
        postalCode: '11206',
      ).withChecklistNote('exhaust_ok', 'Minor soot.');

      final row = InspectionRemoteDatasource.toSupabaseJson(entity);
      final payload = row['payload'] as Map<String, dynamic>;

      // The top-level column keeps meaning "the whole address", so anything
      // reading the table directly is unaffected by the split.
      expect(row['address'], '952 Flushing Ave, Suite 3, Brooklyn, NY 11206');

      expect(payload['address_line1'], '952 Flushing Ave');
      expect(payload['address_line2'], 'Suite 3');
      expect(payload['address_city'], 'Brooklyn');
      expect(payload['address_state'], 'NY');
      expect(payload['address_postal_code'], '11206');
      expect(payload['checklist_notes'], {'exhaust_ok': 'Minor soot.'});
    });

    test('a legacy row with no parts puts its address on the street line', () {
      // Rows written before the split have only the top-level column. Reading
      // one must not lose the address or scatter it across the new fields.
      const legacy = '952 Flushing Ave, Suite 3, Brooklyn NY 11206';
      final entity = InspectionEntity.newDraft().copyWith(address: legacy);

      final row = InspectionRemoteDatasource.toSupabaseJson(entity);
      expect(row['address'], legacy);
      expect((row['payload'] as Map)['address_line1'], legacy);
    });
  });
}
