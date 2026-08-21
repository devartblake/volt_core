import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../domain/entities/inspection_entity.dart';
import '../../domain/usecases/list_inspections_usecase.dart';
import '../../infra/repositories/inspection_repository_impl.dart';

// The repository provider lives with the implementation, in
// inspection_repository_impl.dart. A second copy used to be declared here,
// so which instance you got depended on which file you imported.

/// Usecase provider
final listInspectionsUsecaseProvider =
Provider<ListInspectionsUsecase>((ref) {
  final repo = ref.watch(inspectionRepositoryProvider);
  return ListInspectionsUsecase(repo);
});

/// Simple list state
class InspectionListState {
  final List<InspectionEntity> items;
  final bool isLoading;
  final String? error;

  const InspectionListState({
    required this.items,
    required this.isLoading,
    this.error,
  });

  const InspectionListState.initial()
      : items = const [],
        isLoading = false,
        error = null;

  InspectionListState copyWith({
    List<InspectionEntity>? items,
    bool? isLoading,
    String? error,
  }) {
    return InspectionListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class InspectionListController extends StateNotifier<InspectionListState> {
  final ListInspectionsUsecase _listUsecase;

  InspectionListController(this._listUsecase)
      : super(const InspectionListState.initial());

  Future<void> loadInspections() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final items = await _listUsecase();
      state = state.copyWith(items: items, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

final inspectionListControllerProvider =
StateNotifierProvider<InspectionListController, InspectionListState>((ref) {
  final listUsecase = ref.watch(listInspectionsUsecaseProvider);
  return InspectionListController(listUsecase);
});
