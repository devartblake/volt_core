import '../infra/models/maintenance_record.dart';
import 'maintenance_progress.dart';

/// A field the progress model needs before a step counts as "Done".
enum MaintenanceField {
  address(MaintenanceStep.siteInfo),
  dateOfService(MaintenanceStep.siteInfo),
  technicianName(MaintenanceStep.siteInfo),
  generatorMake(MaintenanceStep.siteInfo),
  generatorModel(MaintenanceStep.siteInfo),
  generatorSerial(MaintenanceStep.siteInfo),
  technicianSignature(MaintenanceStep.signatures),
  customerSignature(MaintenanceStep.signatures);

  const MaintenanceField(this.step);

  /// The form step the field lives on.
  final MaintenanceStep step;
}

/// Light, non-blocking validation for the maintenance form.
///
/// These are the same requirements [MaintenanceProgress] uses to mark Site
/// Information and Signatures "Done". They only produce messages to show
/// inline; nothing here ever stops a save.
class MaintenanceValidation {
  const MaintenanceValidation._();

  static const requiredMessage = 'Required to finish';

  static bool _filled(String? s) => (s ?? '').trim().isNotEmpty;

  /// Whether [field] has what the progress model needs.
  static bool isFilled(MaintenanceRecord m, MaintenanceField field) {
    switch (field) {
      case MaintenanceField.address:
        return _filled(m.address);
      case MaintenanceField.dateOfService:
        return m.dateOfService != null;
      case MaintenanceField.technicianName:
        return _filled(m.technicianName);
      case MaintenanceField.generatorMake:
        return _filled(m.generatorMake);
      case MaintenanceField.generatorModel:
        return _filled(m.generatorModel);
      case MaintenanceField.generatorSerial:
        return _filled(m.generatorSerial);
      case MaintenanceField.technicianSignature:
        return _filled(m.technicianSignatureName) ||
            _filled(m.technicianSignaturePath);
      case MaintenanceField.customerSignature:
        return _filled(m.customerSignatureName) ||
            _filled(m.customerSignaturePath);
    }
  }

  /// Inline message for [field], or null when it is fine.
  static String? messageFor(MaintenanceRecord m, MaintenanceField field) =>
      isFilled(m, field) ? null : requiredMessage;

  /// Every field still missing on [step] (empty for optional steps).
  static List<MaintenanceField> missingOn(
    MaintenanceRecord m,
    MaintenanceStep step,
  ) =>
      [
        for (final f in MaintenanceField.values)
          if (f.step == step && !isFilled(m, f)) f,
      ];

  /// Messages to show given which steps have been "revealed" (the user has
  /// visited and left them, or tapped Complete & Save). Steps not revealed
  /// show nothing, so a fresh form is not covered in red.
  static Map<MaintenanceField, String> issues(
    MaintenanceRecord m, {
    required Set<MaintenanceStep> revealed,
  }) =>
      {
        for (final f in MaintenanceField.values)
          if (revealed.contains(f.step) && !isFilled(m, f))
            f: requiredMessage,
      };
}
