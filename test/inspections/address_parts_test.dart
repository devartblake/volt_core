import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/inspections/domain/entities/inspection_entity.dart';
import 'package:voltcore/modules/inspections/infra/models/inspection.dart';

void main() {
  group('composeAddress', () {
    test('joins the parts the way a US address is written', () {
      expect(
        composeAddress(
          line1: '952 Flushing Ave',
          line2: 'Suite 3',
          city: 'Brooklyn',
          state: 'NY',
          postalCode: '11206',
        ),
        '952 Flushing Ave, Suite 3, Brooklyn, NY 11206',
      );
    });

    test('state and zip stay one unit, not comma-separated', () {
      final composed = composeAddress(
        line1: '1 Main St',
        city: 'Queens',
        state: 'NY',
        postalCode: '11101',
      );
      expect(composed, '1 Main St, Queens, NY 11101');
      expect(composed, isNot(contains('NY, 11101')));
    });

    test('drops blank parts instead of leaving stray separators', () {
      expect(
        composeAddress(line1: '1 Main St', city: 'Queens'),
        '1 Main St, Queens',
      );
      expect(composeAddress(line1: '1 Main St'), '1 Main St');
      expect(composeAddress(line1: ''), '');
      // Whitespace-only is blank, not a part.
      expect(composeAddress(line1: '1 Main St', line2: '   '), '1 Main St');
    });

    test('a record written before the split is unchanged by it', () {
      // Old rows carry the whole one-line address in line1 and nothing else.
      // If composing altered them, every existing inspection would re-render
      // differently on its own report.
      const legacy = '952 Flushing Ave, Suite 3, Brooklyn NY 11206';
      expect(composeAddress(line1: legacy), legacy);

      final entity = InspectionEntity.newDraft().copyWith(address: legacy);
      expect(entity.formattedAddress, legacy);
      expect(entity.displayTitle, legacy);
    });
  });

  group('the Hive model round-trips the new fields', () {
    test('entity -> model -> entity keeps every address part', () {
      final original = InspectionEntity.newDraft().copyWith(
        address: '952 Flushing Ave',
        addressLine2: 'Suite 3',
        city: 'Brooklyn',
        state: 'NY',
        postalCode: '11206',
      );

      final restored = inspectionFromEntity(original).toEntity();

      expect(restored.address, '952 Flushing Ave');
      expect(restored.addressLine2, 'Suite 3');
      expect(restored.city, 'Brooklyn');
      expect(restored.state, 'NY');
      expect(restored.postalCode, '11206');
      expect(restored.formattedAddress, original.formattedAddress);
    });

    test('the printed report gets the whole address, not just the street', () {
      final model = inspectionFromEntity(
        InspectionEntity.newDraft().copyWith(
          address: '952 Flushing Ave',
          addressLine2: 'Suite 3',
          city: 'Brooklyn',
          state: 'NY',
          postalCode: '11206',
        ),
      );

      expect(model.address, '952 Flushing Ave');
      expect(
        model.formattedAddress,
        '952 Flushing Ave, Suite 3, Brooklyn, NY 11206',
      );
    });
  });
}
