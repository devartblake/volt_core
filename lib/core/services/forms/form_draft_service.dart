import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import '../../../modules/inspections/domain/entities/inspection_entity.dart';
import '../../../modules/inspections/infra/models/inspection.dart';

/// Keeps in-progress form edits so leaving a long form doesn't lose the work.
///
/// The inspection form holds nine sections and ~25 fields; before this, walking
/// away, tapping a nav item, or a browser back-gesture discarded everything
/// silently. Edits are written here (debounced) while typing, and cleared once
/// the record is really saved.
///
/// Drafts live in their own box so they never appear in the inspection list —
/// they reuse the existing [Inspection] adapter rather than introducing another
/// serializer.
class FormDraftService {
  FormDraftService._();

  static final FormDraftService instance = FormDraftService._();

  static const String boxName = 'inspection_drafts';

  /// Timestamps live in their own box: the Hive [Inspection] model has no
  /// `updatedAt` column, and `toEntity()` substitutes `DateTime.now()`, so a
  /// draft read back would always look newer than the record it came from.
  static const String timestampBoxName = 'inspection_draft_times';

  /// How long to wait after the last keystroke before writing.
  static const Duration debounce = Duration(milliseconds: 800);

  Box<Inspection>? _box;
  Box<String>? _times;
  final Map<String, Timer> _pending = {};

  /// Open the drafts boxes. Safe to call repeatedly.
  Future<void> init() async {
    if (_box == null || !_box!.isOpen) {
      _box = Hive.isBoxOpen(boxName)
          ? Hive.box<Inspection>(boxName)
          : await Hive.openBox<Inspection>(boxName);
    }
    if (_times == null || !_times!.isOpen) {
      _times = Hive.isBoxOpen(timestampBoxName)
          ? Hive.box<String>(timestampBoxName)
          : await Hive.openBox<String>(timestampBoxName);
    }
  }

  bool get isReady => _box != null && _box!.isOpen;

  /// Queue a draft write for [entity], collapsing rapid edits into one write.
  void saveDraftDebounced(InspectionEntity entity) {
    _pending[entity.id]?.cancel();
    _pending[entity.id] = Timer(debounce, () {
      _pending.remove(entity.id);
      unawaited(saveDraft(entity));
    });
  }

  /// Write a draft immediately. Never throws — losing a draft must not break
  /// the form the user is still typing into.
  Future<void> saveDraft(InspectionEntity entity) async {
    try {
      await init();
      await _box!.put(entity.id, inspectionFromEntity(entity));
      await _times!.put(entity.id, DateTime.now().toIso8601String());
      if (kDebugMode) {
        debugPrint('[FormDraft] saved draft ${entity.id}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[FormDraft] save failed: $e');
    }
  }

  /// The stored draft for [id], or null when there is none.
  InspectionEntity? loadDraft(String id) {
    final box = _box;
    if (box == null || !box.isOpen) return null;
    return box.get(id)?.toEntity();
  }

  /// When the draft for [id] was written, or null if there is no draft.
  ///
  /// Read this rather than the entity's `updatedAt`, which the Hive model does
  /// not persist.
  DateTime? draftSavedAt(String id) {
    final times = _times;
    if (times == null || !times.isOpen) return null;
    final raw = times.get(id);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  bool hasDraft(String id) {
    final box = _box;
    return box != null && box.isOpen && box.containsKey(id);
  }

  /// Drop the draft for [id] — call once the record is actually saved, or when
  /// the user chooses to discard it.
  Future<void> clearDraft(String id) async {
    _pending.remove(id)?.cancel();
    try {
      await init();
      await _box!.delete(id);
      await _times!.delete(id);
    } catch (e) {
      if (kDebugMode) debugPrint('[FormDraft] clear failed: $e');
    }
  }

  /// Cancel any queued write for [id] without deleting an existing draft.
  void cancelPending(String id) => _pending.remove(id)?.cancel();

  /// Every draft currently stored, newest first by when it was written.
  List<InspectionEntity> allDrafts() {
    final box = _box;
    if (box == null || !box.isOpen) return const [];

    final items = box.values.map((m) => m.toEntity()).toList()
      ..sort((a, b) {
        final at = draftSavedAt(a.id) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = draftSavedAt(b.id) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
    return items;
  }
}
