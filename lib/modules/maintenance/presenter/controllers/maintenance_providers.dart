import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../materials/infra/materials_repository.dart';
import '../../../../core/services/photos/photo_attachment.dart';
import '../../../../core/services/photos/photo_service.dart';
import '../../infra/models/maintenance_record.dart';
import '../../infra/repositories/maintenance_hive_repository.dart' as infra;
import '../../domain/repositories/maintenance_repository.dart';
import '../../infra/repositories/maintenance_repository_impl.dart';
import '../../domain/usecases/create_maintenance_usecase.dart';
import '../../domain/usecases/list_maintenance_usecase.dart';

/// Legacy Hive-level repo for full MaintenanceRecord operations.
/// This powers the existing UI (form/detail/list).
final maintenanceRepoProvider = Provider<infra.MaintenanceRepo>((ref) {
  return infra.MaintenanceRepo();
});

/// Simple in-memory list used by MaintenanceListPage (MaintenanceRecord).
final maintenanceListProvider =
StateProvider<List<MaintenanceRecord>>((ref) {
  final repo = ref.watch(maintenanceRepoProvider);
  return repo.getAll();
});

/// Get a full MaintenanceRecord by ID.
final maintenanceByIdProvider =
Provider.family<MaintenanceRecord?, String>((ref, id) {
  final repo = ref.watch(maintenanceRepoProvider);
  return repo.getById(id);
});

/// Domain-level repository backed by Hive, returning MaintenanceJobEntity.
final maintenanceDomainRepositoryProvider =
Provider<MaintenanceRepository>((ref) {
  // Uses MaintenanceBoxes.maintenance internally.
  return MaintenanceRepositoryImpl();
});

/// Use cases wired to the domain repository (MaintenanceJobEntity).
final createMaintenanceUseCaseProvider =
Provider<CreateMaintenanceUseCase>((ref) {
  final repo = ref.watch(maintenanceDomainRepositoryProvider);
  return CreateMaintenanceUseCase(repo);
});

final listMaintenanceUseCaseProvider =
Provider<ListMaintenanceUseCase>((ref) {
  final repo = ref.watch(maintenanceDomainRepositoryProvider);
  return ListMaintenanceUseCase(repo);
});

/// How many photos a maintenance record has, for the form's progress. Photos
/// are stored apart from the record, so the form refreshes this when the
/// technician moves between steps.
final maintenancePhotoCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, id) async {
  try {
    final photos = await PhotoService.instance
        .listForOwner(PhotoAttachment.ownerMaintenance, id);
    return photos.length;
  } catch (_) {
    return 0;
  }
});

/// How many parts are listed on a maintenance record, for the form's progress.
/// The materials editor saves on its own, so the form refreshes this when the
/// technician moves between steps.
final maintenanceMaterialCountProvider =
    FutureProvider.autoDispose.family<int, String>((ref, id) async {
  try {
    final items = await ref
        .watch(materialsRepositoryProvider)
        .load(MaterialOwner.maintenance(id: id));
    return items.length;
  } catch (_) {
    return 0;
  }
});
