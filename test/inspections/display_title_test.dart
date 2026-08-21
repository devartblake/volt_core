import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/inspections/domain/entities/inspection_entity.dart';

void main() {
  group('inspectionDisplayTitle', () {
    final date = DateTime(2026, 8, 21);

    test('prefers the address', () {
      expect(
        inspectionDisplayTitle(
          address: '120 Wall St',
          siteCode: 'SITE-42',
          serviceDate: date,
        ),
        '120 Wall St',
      );
    });

    test('falls back to the site code', () {
      expect(
        inspectionDisplayTitle(
          address: '',
          siteCode: 'SITE-42',
          serviceDate: date,
        ),
        'SITE-42',
      );
    });

    test('falls back to the date rather than a bare placeholder', () {
      // Five screens used to render every incomplete record as "(No address)",
      // which made them indistinguishable in a list. The date at least tells
      // one from another.
      expect(
        inspectionDisplayTitle(address: '', siteCode: '', serviceDate: date),
        'Untitled inspection — 8/21/2026',
      );
    });

    test('treats whitespace-only values as empty', () {
      // Site code and address are hand-typed; a stray space should not count
      // as a title.
      expect(
        inspectionDisplayTitle(
          address: '   ',
          siteCode: '  SITE-42 ',
          serviceDate: date,
        ),
        'SITE-42',
      );
    });

    test('the entity getter uses the same rule', () {
      final entity = InspectionEntity.newDraft().copyWith(address: ' 5 Beekman ');
      expect(entity.displayTitle, '5 Beekman');
    });
  });
}
