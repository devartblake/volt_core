import 'entities/inspection_entity.dart';

/// One row of the post-inspection checklist.
///
/// The ten items were previously written out longhand in the section widget,
/// with the completion count re-listing all ten a second time in a separate
/// array. Adding an item meant editing both, and per-item conclusions would
/// have needed a third list of keys to store notes against. This is the one
/// list; everything that needs to walk the checklist walks this.
class InspectionChecklistItem {
  const InspectionChecklistItem({
    required this.key,
    required this.label,
    required this.read,
    required this.write,
  });

  /// Stable storage key. Persisted in [InspectionEntity.checklistNotes] and in
  /// the sync payload, so **renaming one orphans every conclusion written
  /// against it**. These deliberately match the payload field names the remote
  /// datasource already uses for the answers themselves.
  final String key;

  /// Text shown on the row, and in the conclusion dialog's header.
  final String label;

  final bool Function(InspectionEntity) read;
  final InspectionEntity Function(InspectionEntity, bool) write;
}

/// The post-inspection checklist, in display order.
final List<InspectionChecklistItem> kInspectionChecklist = [
  InspectionChecklistItem(
    key: 'genset_runs_under_load',
    label: 'Generator runs under load',
    read: (e) => e.gensetRunsUnderLoad,
    write: (e, v) => e.copyWith(gensetRunsUnderLoad: v),
  ),
  InspectionChecklistItem(
    key: 'voltage_frequency_ok',
    label: 'Voltage & frequency acceptable',
    read: (e) => e.voltageFrequencyOk,
    write: (e, v) => e.copyWith(voltageFrequencyOk: v),
  ),
  InspectionChecklistItem(
    key: 'exhaust_ok',
    label: 'Exhaust condition OK',
    read: (e) => e.exhaustOk,
    write: (e, v) => e.copyWith(exhaustOk: v),
  ),
  InspectionChecklistItem(
    key: 'grounding_bonding_ok',
    label: 'Grounding / Bonding OK',
    read: (e) => e.groundingBondingOk,
    write: (e, v) => e.copyWith(groundingBondingOk: v),
  ),
  InspectionChecklistItem(
    key: 'control_panel_ok',
    label: 'Control panel OK',
    read: (e) => e.controlPanelOk,
    write: (e, v) => e.copyWith(controlPanelOk: v),
  ),
  InspectionChecklistItem(
    key: 'safety_devices_ok',
    label: 'Safety devices operational',
    read: (e) => e.safetyDevicesOk,
    write: (e, v) => e.copyWith(safetyDevicesOk: v),
  ),
  InspectionChecklistItem(
    key: 'deficiencies_documented',
    label: 'Deficiencies documented',
    read: (e) => e.deficienciesDocumented,
    write: (e, v) => e.copyWith(deficienciesDocumented: v),
  ),
  InspectionChecklistItem(
    key: 'loadbank_done',
    label: 'Loadbank test completed',
    read: (e) => e.loadbankDone,
    write: (e, v) => e.copyWith(loadbankDone: v),
  ),
  InspectionChecklistItem(
    key: 'ats_verified',
    label: 'ATS verified',
    read: (e) => e.atsVerified,
    write: (e, v) => e.copyWith(atsVerified: v),
  ),
  InspectionChecklistItem(
    key: 'fuel_stored_over_1yr',
    label: 'Fuel stored over 1 year',
    read: (e) => e.fuelStoredOver1Yr,
    write: (e, v) => e.copyWith(fuelStoredOver1Yr: v),
  ),
];

extension InspectionChecklistX on InspectionEntity {
  /// How many checklist items are answered yes.
  int get checklistCompletedCount =>
      kInspectionChecklist.where((item) => item.read(this)).length;

  /// Conclusion recorded for [key], or empty when none was written.
  String checklistNoteFor(String key) => checklistNotes[key] ?? '';

  /// Copy with [key]'s conclusion set to [note], or removed when it is blank.
  ///
  /// Removing rather than storing "" keeps the map to the items that actually
  /// have something to say, so "does this item have a conclusion?" stays a
  /// plain key check.
  InspectionEntity withChecklistNote(String key, String note) {
    final next = Map<String, String>.of(checklistNotes);
    final trimmed = note.trim();
    if (trimmed.isEmpty) {
      next.remove(key);
    } else {
      next[key] = trimmed;
    }
    return copyWith(checklistNotes: next);
  }
}
