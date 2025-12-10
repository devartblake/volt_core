import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/services/pdf/pdf_prefs_service.dart';
import '../../../../core/services/pdf/pdf_service.dart';
import '../entities/maintenance_job_entity.dart';
import '../../infra/datasources/hive_boxes_maintenance.dart';
import '../../infra/models/maintenance_record.dart';

/// Clean-domain contract for maintenance jobs.
///
/// Infra (Hive/Supabase/etc.) implements this.
abstract class MaintenanceRepository {
  /// List all maintenance jobs.
  ///
  /// You can later add filters (by site, completed, etc.).
  Future<List<MaintenanceJobEntity>> listAll();

  /// Get a single job, or null if not found.
  Future<MaintenanceJobEntity?> getById(String id);

  /// Create a new draft job (backed by Hive via MaintenanceRecord).
  Future<MaintenanceJobEntity> createDraft({String? inspectionId});

  /// Persist the job back to storage.
  Future<void> save(MaintenanceJobEntity job);

  /// Delete by id.
  Future<void> delete(String id);

  /// Export a PDF for a given job.
  Future<void> exportPdf(String id);

  /// Mark a job as completed.
  Future<void> completeJob(String id, {DateTime? completedAt});
}
