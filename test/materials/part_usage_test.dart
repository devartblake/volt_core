import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/materials/domain/material_item.dart';
import 'package:voltcore/modules/materials/domain/part_usage.dart';

MaterialItem _i(String id, String number) =>
    MaterialItem(id: id, slot: MaterialSlot.oilFilter, partNumber: number);

JobPartsList _l(String id, String gen, List<MaterialItem> items,
        {MaterialOwnerType type = MaterialOwnerType.inspection}) =>
    JobPartsList(type: type, id: id, generatorKey: gen, items: items);

void main() {
  test('counts the jobs of one generator that list each part, once per job', () {
    final lists = [
      _l('1', 'g', [_i('a', 'LF-3000'), _i('b', 'lf 3000'), _i('c', 'AF1')]),
      _l('2', 'g', [_i('a', 'LF3000')], type: MaterialOwnerType.maintenance),
      _l('3', 'other', [_i('a', 'LF3000')]),
      _l('4', '', [_i('a', 'LF3000')]),
    ];
    final u = jobsUsingParts(lists, 'g');
    expect(u['LF3000'], 2);
    expect(u['AF1'], 1);
    expect(u['NOPE'], isNull);
  });

  test('no generator key, no usage; blank part numbers ignored', () {
    expect(jobsUsingParts([_l('1', '', [_i('a', 'X')])], ''), isEmpty);
    expect(jobsUsingParts([_l('1', 'g', [_i('a', ' ')])], 'g'), isEmpty);
  });

  test('usedOnLabel', () {
    expect(usedOnLabel(0), '');
    expect(usedOnLabel(1), 'Used on 1 job');
    expect(usedOnLabel(3), 'Used on 3 jobs');
  });
}
