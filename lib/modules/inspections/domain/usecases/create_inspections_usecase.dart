import '../entities/inspection_entity.dart';
import '../../infra/repositories/inspection_repository.dart';

class CreateInspectionUsecase {
  final InspectionRepository _repository;

  CreateInspectionUsecase(this._repository);

  /// Creates the inspection AND generates its PDF, honouring the device's
  /// export/email preferences.
  ///
  /// This called `createInspection` until now, which only saved
  /// locally and queued the cloud upsert — so the form's "Save & Generate PDF"
  /// button never produced a PDF and `pdfPath` stayed empty on every
  /// inspection. The `*AndExport` variants existed the whole time and were
  /// only reachable from the schedule module.
  Future<InspectionEntity> call(InspectionEntity inspection) {
    return _repository.createAndExport(inspection);
  }
}
