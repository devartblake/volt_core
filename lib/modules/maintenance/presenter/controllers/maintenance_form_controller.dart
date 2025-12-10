import 'package:flutter_riverpod/legacy.dart';
import '../../domain/repositories/maintenance_repository.dart' as legacy;
import '../../infra/models/maintenance_record.dart';
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
  final legacy.MaintenanceRepo _repo;

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
final maintenanceFormControllerProvider = StateNotifierProvider.family<
    MaintenanceFormController, MaintenanceFormState?, String?>(
      (ref, id) {
    final repo = ref.watch(maintenanceRepoProvider);
    return MaintenanceFormController(repo, initialId: id);
  },
);
