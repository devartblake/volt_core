import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../data/models/maintenance_record.dart';
import '../data/repositories/maintenance_repository.dart';

final maintenanceRepoProvider = Provider<MaintenanceRepo>((ref) {
  return MaintenanceRepo();
});

final maintenanceListProvider =
StateProvider<List<MaintenanceRecord>>((ref) {
  final repo = ref.watch(maintenanceRepoProvider);
  return repo.getAll();
});

final maintenanceByIdProvider =
Provider.family<MaintenanceRecord?, String>((ref, id) {
  final repo = ref.watch(maintenanceRepoProvider);
  return repo.getById(id);
});
