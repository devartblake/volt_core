import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/settings/app_preferences_service.dart';
import '../../../auth/domain/user_role.dart';
import '../../../auth/presenter/controllers/auth_controller.dart';
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

/// Whether the signed-in role may delete inspections (admin, supervisor).
/// Its own provider so tests can override it.
final inspectionCanDeleteProvider = Provider<bool>((ref) {
  final role = ref.watch(authStateProvider.select((a) => a.currentRole));
  return role == UserRole.admin || role == UserRole.supervisor;
});
