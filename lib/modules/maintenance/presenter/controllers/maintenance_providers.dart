import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../infra/models/maintenance_record.dart';
import '../../infra/repositories/maintenance_entity.dart' as legacy;
import '../../infra/repositories/maintenance_repository_impl.dart';
import '../../domain/repositories/maintenance_repository.dart';
import '../../domain/usecases/create_maintenance_usecase.dart';
import '../../domain/usecases/list_maintenance_usecase.dart';

/// Legacy Hive-level repo for full MaintenanceRecord operations.
///
/// This is what your existing pages (form, detail, list) are using.
final maintenanceRepoProvider = Provider<legacy.MaintenanceRepo>((ref) {
  return legacy.MaintenanceRepo();
});

/// Domain-level repository backed by Hive, returning MaintenanceJobEntity.
final maintenanceDomainRepositoryProvider =
Provider<MaintenanceRepository>((ref) {
  return MaintenanceRepositoryImpl();
});

/// Simple list provider used by MaintenanceListPage (uses MaintenanceRecord).
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

/// Use cases wired to the *domain* repository (MaintenanceJobEntity).
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
