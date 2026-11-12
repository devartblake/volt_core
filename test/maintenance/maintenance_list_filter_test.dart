import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/maintenance/domain/maintenance_list_filter.dart';
import 'package:voltcore/modules/maintenance/infra/models/maintenance_record.dart';

void main() {
  final done = MaintenanceRecord(id: 'a')..completed = true;
  final open1 = MaintenanceRecord(id: 'b');
  final open2 = MaintenanceRecord(id: 'c');
  final all = [open1, done, open2];

  test('All keeps everything in order', () {
    expect(filterMaintenance(all, MaintenanceStatusFilter.all), all);
  });

  test('In progress keeps only unfinished records, in order', () {
    expect(filterMaintenance(all, MaintenanceStatusFilter.inProgress),
        [open1, open2]);
  });

  test('Completed keeps only finished records', () {
    expect(filterMaintenance(all, MaintenanceStatusFilter.completed), [done]);
  });

  test('empty input gives empty output for every filter', () {
    for (final f in MaintenanceStatusFilter.values) {
      expect(filterMaintenance(const [], f), isEmpty);
    }
  });

  test('filtering does not mutate the input', () {
    final copy = [...all];
    filterMaintenance(all, MaintenanceStatusFilter.completed);
    expect(all, copy);
  });
}
