import 'package:flutter_riverpod/legacy.dart';
import '../../infra/models/maintenance_record.dart';
import '../../infra/repositories/maintenance_hive_repository.dart' as infra;
import 'maintenance_providers.dart';

class MaintenanceFormState {
  final MaintenanceRecord record;
  final bool isNew;
  final bool isSaving;
  final Object? error;

  const MaintenanceFormState({
    required this.record,
    required this.isNew,
    this.isSaving = false,
    this.error,
  });

  MaintenanceFormState copyWith({
    MaintenanceRecord? record,
    bool? isNew,
    bool? isSaving,
    Object? error,
  }) {
    return MaintenanceFormState(
      record: record ?? this.record,
      isNew: isNew ?? this.isNew,
      isSaving: isSaving ?? this.isSaving,
      error: error,
    );
  }
}

class MaintenanceFormController
    extends StateNotifier<MaintenanceFormState?> {
  final infra.MaintenanceRepo _repo;

  MaintenanceFormController(
      this._repo, {
        String? initialId,
      }) : super(null) {
    _init(initialId);
  }

  void _init(String? id) {
    // If an id is provided, try to load an existing record.
    if (id != null) {
      final existing = _repo.getById(id);
      if (existing != null) {
        // Records made before the form had a service date: use the day they
        // were created (what the PDF already printed), so it can be seen and
        // corrected instead of staying blank. Saved with the next draft/save.
        existing.dateOfService ??= existing.createdAt;
        state = MaintenanceFormState(
          record: existing,
          isNew: false,
        );
        return;
      }
    }

    // No id or not found → create a new record in Hive.
    final rec = _repo.createNew();
    state = MaintenanceFormState(
      record: rec,
      isNew: true,
    );
  }

  /// Persists the record as it stands, locally only (see
  /// [infra.MaintenanceRepo.saveDraft]). Safe to call often.
  Future<void> saveDraft() async {
    final current = state;
    if (current == null) return;
    await _repo.saveDraft(current.record);
  }

  /// Removes a brand-new record the technician never typed into, so opening
  /// "New record" and backing out leaves nothing behind.
  Future<void> discardIfNew() async {
    final current = state;
    if (current == null || !current.isNew) return;
    await _repo.delete(current.record.id);
  }

  Future<void> save({
    bool markCompleted = false,
    bool requiresFollowUp = false,
    String? followUpNotes,
  }) async {
    final current = state;
    if (current == null) return;

    state = current.copyWith(isSaving: true, error: null);

    try {
      final rec = current.record;

      if (markCompleted) {
        rec.completed = true;
        rec.requiresFollowUp = requiresFollowUp;
        rec.followUpNotes = followUpNotes ?? rec.followUpNotes;
      }

      await _repo.save(rec);

      state = current.copyWith(
        record: rec,
        isSaving: false,
        error: null,
      );
    } catch (e) {
      state = current.copyWith(isSaving: false, error: e);
      rethrow;
    }
  }
}

/// Provider factory with optional maintenance record id.
///
/// `autoDispose` matters: a new record is keyed by a null id, so without it the
/// first "new" form stays cached and every later "new" form reopens that same
/// record (and saving would overwrite it and print its PDF). Each visit to the
/// form now starts from fresh state.
final maintenanceFormControllerProvider =
StateNotifierProvider.autoDispose.family<MaintenanceFormController,
    MaintenanceFormState?, String?>(
      (ref, id) {
    final repo = ref.watch(maintenanceRepoProvider);
    return MaintenanceFormController(repo, initialId: id);
  },
);
