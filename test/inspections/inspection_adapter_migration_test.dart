import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/inspections/domain/entities/inspection_entity.dart';
import 'package:voltcore/modules/inspections/domain/inspection_checklist.dart';
import 'package:voltcore/modules/inspections/infra/models/inspection.dart';

import '../support/hive_adapter_probe.dart';

/// Field count of the release before the address split.
const _fieldCountBeforeAddressSplit = 61;

void main() {
  final probe = HiveAdapterProbe<Inspection>(InspectionAdapter());

  Inspection sample() => inspectionFromEntity(
        InspectionEntity.newDraft().copyWith(address: 'Legacy row'),
      );

  // That every adapter *decodes* a truncated row is covered once, for all
  // eight, in test/storage/hive_adapter_forward_compat_test.dart. What is
  // specific to Inspection — and what that generic test deliberately does not
  // assert — is which values a pre-split row comes back with.
  group('InspectionAdapter across the address split', () {
    test('round-trips the fields the split added', () {
      final model = inspectionFromEntity(
        InspectionEntity.newDraft().copyWith(
          address: '952 Flushing Ave',
          addressLine2: 'Suite 3',
          city: 'Brooklyn',
          state: 'NY',
          postalCode: '11206',
        ).withChecklistNote('exhaust_ok', 'Minor soot.'),
      );

      final restored = probe.readTruncatedTo(66, model);

      expect(restored.addressLine2, 'Suite 3');
      expect(restored.city, 'Brooklyn');
      expect(restored.state, 'NY');
      expect(restored.postalCode, '11206');
      expect(restored.checklistNotes, {'exhaust_ok': 'Minor soot.'});
    });

    test('a pre-split row keeps its address and gains empty parts', () {
      final restored =
          probe.readTruncatedTo(_fieldCountBeforeAddressSplit, sample());

      expect(restored.address, 'Legacy row');
      expect(restored.addressLine2, '');
      expect(restored.city, '');
      expect(restored.state, '');
      expect(restored.postalCode, '');
      expect(restored.checklistNotes, isEmpty);

      // The whole point of leaving `address` as the street line: an old
      // record composes back to exactly what was stored, so its report and
      // its list row are unchanged by the split.
      expect(restored.formattedAddress, 'Legacy row');
    });
  });
}
