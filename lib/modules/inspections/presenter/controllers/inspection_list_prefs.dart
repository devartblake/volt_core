import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/settings/app_preferences_service.dart';
import '../../../auth/domain/user_role.dart';
import '../../../permissions/domain/permission.dart';
import '../../../permissions/presenter/permission_providers.dart';
import '../../domain/inspection_filter_preset.dart';

/// Where the inspections list keeps its saved filter presets and row density.
///
/// An interface so widget tests can supply an in-memory fake: the real one
/// writes to Hive, which hangs on the widget-test fake clock.
abstract class InspectionListPrefs {
  List<InspectionFilterPreset> loadPresets();
  Future<void> savePresets(List<InspectionFilterPreset> presets);
  InspectionDensity loadDensity();
  Future<void> saveDensity(InspectionDensity density);
}

class _HiveInspectionListPrefs implements InspectionListPrefs {
  const _HiveInspectionListPrefs();

  AppPreferencesService get _p => AppPreferencesService.instance;

  @override
  List<InspectionFilterPreset> loadPresets() =>
      InspectionFilterPresetCodec.decode(_p.inspectionFilterPresetsJson);

  @override
  Future<void> savePresets(List<InspectionFilterPreset> presets) =>
      _p.setInspectionFilterPresetsJson(
          InspectionFilterPresetCodec.encode(presets));

  @override
  InspectionDensity loadDensity() =>
      InspectionDensity.parse(_p.inspectionListDensity);

  @override
  Future<void> saveDensity(InspectionDensity density) =>
      _p.setInspectionListDensity(density.name);
}

final inspectionListPrefsProvider =
    Provider<InspectionListPrefs>((_) => const _HiveInspectionListPrefs());

/// Who may delete an inspection: admins and dispatchers only (supervisors and
/// technicians may not). Mirrors the cloud delete policy
/// (`20261110100000_inspections_delete_policy.sql`).
bool roleCanDeleteInspection(UserRole? role) =>
    Permission.deleteInspections.defaultFor(role);

/// Whether the signed-in user may delete inspections (permission
/// `delete_inspections`: admin and dispatcher by default, plus any per-person
/// override). Its own provider so tests can override it.
final inspectionCanDeleteProvider = Provider<bool>(
  (ref) => ref.watch(hasPermissionProvider(Permission.deleteInspections)),
);
