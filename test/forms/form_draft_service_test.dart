import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/core/services/forms/form_draft_service.dart';
import 'package:voltcore/modules/inspections/domain/entities/inspection_entity.dart';
import 'package:voltcore/modules/inspections/infra/models/inspection.dart';
import 'package:voltcore/modules/inspections/infra/models/nameplate_data.dart';

InspectionEntity _entity({
  String id = 'i1',
  String siteCode = 'AS-114',
  DateTime? updatedAt,
}) {
  final base = InspectionEntity.newDraft();
  return base.copyWith(
    id: id,
    siteCode: siteCode,
    updatedAt: updatedAt ?? DateTime(2026, 7, 20, 10),
  );
}

void main() {
  late Directory tempDir;

  setUpAll(() {
    Hive.registerAdapter(InspectionAdapter());
    Hive.registerAdapter(NameplateDataAdapter());
  });

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('voltcore_drafts_test');
    Hive.init(tempDir.path);
    await FormDraftService.instance.init();
  });

  tearDown(() async {
    await Hive.deleteBoxFromDisk(FormDraftService.boxName);
    await Hive.deleteBoxFromDisk(FormDraftService.timestampBoxName);
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group('FormDraftService', () {
    test('round-trips a draft through Hive', () async {
      final entity = _entity(siteCode: 'AS-999');
      await FormDraftService.instance.saveDraft(entity);

      final loaded = FormDraftService.instance.loadDraft('i1');
      expect(loaded, isNotNull);
      expect(loaded!.id, 'i1');
      expect(loaded.siteCode, 'AS-999');
    });

    test('hasDraft reflects presence', () async {
      expect(FormDraftService.instance.hasDraft('i1'), isFalse);
      await FormDraftService.instance.saveDraft(_entity());
      expect(FormDraftService.instance.hasDraft('i1'), isTrue);
    });

    test('clearDraft removes it', () async {
      await FormDraftService.instance.saveDraft(_entity());
      await FormDraftService.instance.clearDraft('i1');

      expect(FormDraftService.instance.hasDraft('i1'), isFalse);
      expect(FormDraftService.instance.loadDraft('i1'), isNull);
    });

    test('loadDraft returns null for an unknown id', () {
      expect(FormDraftService.instance.loadDraft('nope'), isNull);
    });

    test('saving the same id twice keeps one entry, latest wins', () async {
      await FormDraftService.instance.saveDraft(_entity(siteCode: 'first'));
      await FormDraftService.instance.saveDraft(_entity(siteCode: 'second'));

      expect(FormDraftService.instance.allDrafts().length, 1);
      expect(FormDraftService.instance.loadDraft('i1')!.siteCode, 'second');
    });

    test('debounced save collapses rapid edits into one write', () async {
      for (var i = 0; i < 5; i++) {
        FormDraftService.instance
            .saveDraftDebounced(_entity(siteCode: 'edit$i'));
      }

      // Nothing written yet — the timer has not fired.
      expect(FormDraftService.instance.hasDraft('i1'), isFalse);

      await Future<void>.delayed(
        FormDraftService.debounce + const Duration(milliseconds: 250),
      );

      expect(FormDraftService.instance.loadDraft('i1')!.siteCode, 'edit4');
      expect(FormDraftService.instance.allDrafts().length, 1);
    });

    test('cancelPending drops a queued write without deleting a saved draft',
        () async {
      await FormDraftService.instance.saveDraft(_entity(siteCode: 'kept'));

      FormDraftService.instance.saveDraftDebounced(_entity(siteCode: 'queued'));
      FormDraftService.instance.cancelPending('i1');

      await Future<void>.delayed(
        FormDraftService.debounce + const Duration(milliseconds: 250),
      );

      expect(FormDraftService.instance.loadDraft('i1')!.siteCode, 'kept');
    });

    test('allDrafts is newest-first by write time', () async {
      await FormDraftService.instance.saveDraft(_entity(id: 'old'));
      // Write times are recorded per save; separate them enough to order.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await FormDraftService.instance.saveDraft(_entity(id: 'new'));

      final drafts = FormDraftService.instance.allDrafts();
      expect(drafts.map((d) => d.id).toList(), ['new', 'old']);
    });

    test('records when a draft was written', () async {
      final before = DateTime.now();
      await FormDraftService.instance.saveDraft(_entity());
      final at = FormDraftService.instance.draftSavedAt('i1');

      expect(at, isNotNull);
      expect(at!.isBefore(before.subtract(const Duration(seconds: 1))), isFalse);
    });

    test('draft write time is independent of the entity updatedAt', () async {
      // The Hive Inspection model has no updatedAt column — toEntity()
      // substitutes DateTime.now() — so restore logic must use draftSavedAt.
      await FormDraftService.instance.saveDraft(
        _entity(updatedAt: DateTime(2020, 1, 1)),
      );

      expect(FormDraftService.instance.draftSavedAt('i1'), isNotNull);
      expect(
        FormDraftService.instance.draftSavedAt('i1')!.year,
        DateTime.now().year,
      );
    });

    test('clearDraft removes the recorded time too', () async {
      await FormDraftService.instance.saveDraft(_entity());
      await FormDraftService.instance.clearDraft('i1');

      expect(FormDraftService.instance.draftSavedAt('i1'), isNull);
    });
  });
}
