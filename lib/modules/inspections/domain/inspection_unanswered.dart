import 'entities/inspection_entity.dart';
import 'inspection_checklist.dart';

/// One required item that has not been answered yet.
class UnansweredItem {
  const UnansweredItem({
    required this.sectionKey,
    required this.sectionLabel,
    required this.label,
  });

  /// Matches the form's section id (`_FormSection.name`), so the page can
  /// scroll to the section.
  final String sectionKey;
  final String sectionLabel;
  final String label;
}

/// The required items still unanswered on [i], in form order.
///
/// Required means:
/// * Site information: site code, site grade and street address.
/// * Post-inspection: each checklist item that is not ticked *and* has no
///   written conclusion (a "no" is a valid answer once it says why).
/// * Signatures: customer name and both signatures.
///
/// There is no per-field scroll target in the form, so the jump goes to the
/// section.
List<UnansweredItem> unansweredItems(InspectionEntity i) {
  const site = ('siteInfo', 'Site information');
  const post = ('postInspection', 'Post-inspection');
  const sigs = ('signatures', 'Signatures');

  UnansweredItem item((String, String) s, String label) => UnansweredItem(
      sectionKey: s.$1, sectionLabel: s.$2, label: label);

  return [
    if (i.siteCode.trim().isEmpty) item(site, 'Site code'),
    if (i.siteGrade.trim().isEmpty) item(site, 'Site grade'),
    if (i.address.trim().isEmpty) item(site, 'Street address'),
    for (final c in kInspectionChecklist)
      if (!c.read(i) && i.checklistNoteFor(c.key).isEmpty) item(post, c.label),
    if (i.customerName.trim().isEmpty) item(sigs, 'Customer name'),
    if (i.technicianSignaturePath.trim().isEmpty)
      item(sigs, 'Technician signature'),
    if (i.customerSignaturePath.trim().isEmpty)
      item(sigs, 'Customer signature'),
  ];
}

/// [items] grouped by section, keeping first-seen (form) order.
Map<String, List<UnansweredItem>> groupUnansweredBySection(
    List<UnansweredItem> items) {
  final out = <String, List<UnansweredItem>>{};
  for (final it in items) {
    out.putIfAbsent(it.sectionKey, () => []).add(it);
  }
  return out;
}
