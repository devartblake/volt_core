import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/inspections/domain/entities/inspection_entity.dart';
import 'package:voltcore/modules/inspections/domain/inspection_checklist.dart';
import 'package:voltcore/modules/inspections/domain/inspection_completion.dart';
import 'package:voltcore/modules/materials/domain/material_item.dart';

MaterialItem part(MaterialSlot slot, {String pn = 'X1', String name = ''}) =>
    MaterialItem(id: '${slot.wire}-$pn-$name', slot: slot, partNumber: pn, partName: name);

List<MaterialItem> all5() => [
      part(MaterialSlot.airFilter),
      part(MaterialSlot.fuelFilter),
      part(MaterialSlot.oilFilter),
      part(MaterialSlot.coolantFilter),
      part(MaterialSlot.battery),
    ];

InspectionEntity withDone(int n) {
  var e = InspectionEntity.newDraft();
  for (final c in kInspectionChecklist.take(n)) {
    e = c.write(e, true);
  }
  return e;
}

void main() {
  final total = kInspectionChecklist.length;
  final half = (total + 1) ~/ 2;

  test('checklist: exactly 50 percent is met, one under is not', () {
    expect(total, greaterThan(1));
    final at = InspectionCompletion.of(withDone(half), []);
    expect(at.checklistMet, isTrue);
    final under = InspectionCompletion.of(withDone(half - 1), []);
    expect(under.checklistMet, isFalse);
    expect(under.reasons.first,
        'Post-inspection checklist ${half - 1} of $total done ($half needed)');
  });

  test('a conclusion note counts as answered', () {
    var e = withDone(half - 1);
    e = e.withChecklistNote(kInspectionChecklist[total - 1].key, 'Low');
    expect(InspectionCompletion.of(e, []).checklistMet, isTrue);
  });

  test('none met: checklist and five parts listed', () {
    final c = InspectionCompletion.of(InspectionEntity.newDraft(), []);
    expect(c.isFinished, isFalse);
    expect(c.reasons, hasLength(6));
    expect(c.remainingCount, 6);
    expect(c.reasons, contains('Missing part number: Coolant filter'));
    expect(c.reasons, contains('Missing part number: Oil or lube filter'));
  });

  test('all five met and checklist met is finished', () {
    final c = InspectionCompletion.of(withDone(total), all5());
    expect(c.isFinished, isTrue);
    expect(c.reasons, isEmpty);
    expect(c.checklistRatio, 1.0);
  });

  test('lube filter satisfies the oil or lube requirement', () {
    final items = all5()..removeWhere((m) => m.slot == MaterialSlot.oilFilter);
    expect(InspectionCompletion.of(withDone(total), items).isFinished, isFalse);
    items.add(part(MaterialSlot.lubeFilter));
    expect(InspectionCompletion.of(withDone(total), items).isFinished, isTrue);
  });

  test('name only, blank or whitespace part number does not count', () {
    final items = all5()..removeWhere((m) => m.slot == MaterialSlot.battery);
    items.add(part(MaterialSlot.battery, pn: '', name: 'Big battery'));
    var c = InspectionCompletion.of(withDone(total), items);
    expect(c.missingParts, [PartRequirement.battery]);
    items.add(part(MaterialSlot.battery, pn: '   ', name: 'b2'));
    c = InspectionCompletion.of(withDone(total), items);
    expect(c.isFinished, isFalse);
    items.add(part(MaterialSlot.battery, pn: ' 12V '));
    expect(InspectionCompletion.of(withDone(total), items).isFinished, isTrue);
  });

  test('slots that are not required do not stand in', () {
    final items = [part(MaterialSlot.fuelWaterSeparator), part(MaterialSlot.additionalParts)];
    expect(InspectionCompletion.of(withDone(total), items).missingParts, hasLength(5));
  });

  test('an empty checklist counts as met', () {
    final c = InspectionCompletion.fromCounts(
        answered: 0, total: 0, items: all5());
    expect(c.checklistMet, isTrue);
    expect(c.checklistRatio, 1.0);
    expect(c.isFinished, isTrue);
  });

  test('odd totals: 5 of 9 needed, 4 of 9 not', () {
    expect(InspectionCompletion.fromCounts(answered: 5, total: 9, items: []).checklistMet, isTrue);
    final c = InspectionCompletion.fromCounts(answered: 4, total: 9, items: []);
    expect(c.checklistMet, isFalse);
    expect(c.checklistNeeded, 5);
  });
}
