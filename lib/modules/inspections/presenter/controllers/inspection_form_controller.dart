// lib/modules/inspections/presenter/controllers/inspection_form_controller.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../domain/entities/inspection_entity.dart';
import '../../domain/usecases/create_inspections_usecase.dart';
import '../../domain/usecases/update_inspections_usecase.dart';
import '../../domain/usecases/list_inspections_usecase.dart';

// Reuse the shared repository + list usecase from the list controller
import 'inspection_list_controller.dart';

/// Provide ONLY the create/update usecases here, based on the shared repo.
final createInspectionUsecaseProvider =
Provider<CreateInspectionUsecase>((ref) {
  final repo = ref.watch(inspectionRepositoryProvider);
  return CreateInspectionUsecase(repo);
});

final updateInspectionUsecaseProvider =
Provider<UpdateInspectionUsecase>((ref) {
  final repo = ref.watch(inspectionRepositoryProvider);
  return UpdateInspectionUsecase(repo);
});

/// Simple form state for a single inspection.
class InspectionFormState {
  final InspectionEntity? inspection;
  final bool isSaving;
  final bool isLoading;
  final String? error;

  const InspectionFormState({
    required this.inspection,
    required this.isSaving,
    required this.isLoading,
    this.error,
  });

  const InspectionFormState.initial()
      : inspection = null,
        isSaving = false,
        isLoading = false,
        error = null;

  bool get isEditing => inspection != null;

  InspectionFormState copyWith({
    InspectionEntity? inspection,
    bool? isSaving,
    bool? isLoading,
    String? error,
  }) {
    return InspectionFormState(
      inspection: inspection ?? this.inspection,
      isSaving: isSaving ?? this.isSaving,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class InspectionFormController
    extends StateNotifier<InspectionFormState> {
  final ListInspectionsUsecase _listUsecase;
  final CreateInspectionUsecase _createUsecase;
  final UpdateInspectionUsecase _updateUsecase;

  InspectionFormController(
      this._listUsecase,
      this._createUsecase,
      this._updateUsecase,
      ) : super(const InspectionFormState.initial());

  /// Load an existing inspection for editing (by id).
  Future<void> loadForEdit(String id) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final all = await _listUsecase();
      final found = all.firstWhere(
            (i) => i.id == id,
        orElse: () =>
        throw StateError('Inspection $id not found'),
      );
      state = state.copyWith(
        isLoading: false,
        inspection: found,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Save (create or update) an inspection.
  Future<void> save(InspectionEntity inspection) async {
    state = state.copyWith(isSaving: true, error: null);

    try {
      final result = state.isEditing
          ? await _updateUsecase(inspection)
          : await _createUsecase(inspection);

      state = state.copyWith(
        isSaving: false,
        inspection: result,
      );
    } catch (e) {
      state = state.copyWith(
        isSaving: false,
        error: e.toString(),
      );
    }
  }

  /// Local-only update of the current inspection in state.
  void updateDraft(InspectionEntity inspection) {
    state = state.copyWith(inspection: inspection);
  }

  void reset() {
    state = const InspectionFormState.initial();
  }
}

/// Provider for the controller.
final inspectionFormControllerProvider =
StateNotifierProvider<InspectionFormController, InspectionFormState>(
        (ref) {
      // Reuse the globally defined list usecase
      final listUsecase = ref.watch(listInspectionsUsecaseProvider);
      final createUsecase =
      ref.watch(createInspectionUsecaseProvider);
      final updateUsecase =
      ref.watch(updateInspectionUsecaseProvider);

      return InspectionFormController(
        listUsecase,
        createUsecase,
        updateUsecase,
      );
    });
