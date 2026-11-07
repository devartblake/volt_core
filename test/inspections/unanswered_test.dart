import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/inspections/domain/entities/inspection_entity.dart';
import 'package:voltcore/modules/inspections/domain/inspection_checklist.dart';
import 'package:voltcore/modules/inspections/domain/inspection_unanswered.dart';

void main() {
  test('a blank draft lists site, every checklist item and signatures', () {
    final items = unansweredItems(InspectionEntity.newDraft());
    final groups = groupUnansweredBySection(items);
    expect(groups.keys, ['siteInfo', 'postInspection', 'signatures']);
    expect(groups['siteInfo']!.map((i) => i.label),
        ['Site code', 'Site grade', 'Street address']);
    expect(groups['postInspection'], hasLength(kInspectionChecklist.length));
    expect(groups['signatures'], hasLength(3));
  });

  test('a ticked item, or an unticked one with a conclusion, is answered', () {
    var e = InspectionEntity.newDraft();
    final first = kInspectionChecklist[0];
    final second = kInspectionChecklist[1];
    e = first.write(e, true);
    e = e.withChecklistNote(second.key, 'Voltage low, needs regulator');
    final labels = unansweredItems(e).map((i) => i.label);
    expect(labels, isNot(contains(first.label)));
    expect(labels, isNot(contains(second.label)));
    expect(labels, contains(kInspectionChecklist[2].label));
  });

  test('fully answered gives an empty list', () {
    var e = InspectionEntity.newDraft().copyWith(
      siteCode: 'S1',
      siteGrade: 'Green',
      address: '1 Main St',
      customerName: 'Pat',
      technicianSignaturePath: 'a.png',
      customerSignaturePath: 'b.png',
    );
    for (final c in kInspectionChecklist) {
      e = c.write(e, true);
    }
    expect(unansweredItems(e), isEmpty);
  });
}
