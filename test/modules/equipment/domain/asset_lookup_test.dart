import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/equipment/domain/asset_lookup.dart';
import 'package:voltcore/modules/equipment/domain/entities/equipment_entity.dart';

void main() {
  const asset = EquipmentEntity(
    id: 'asset-123',
    name: 'Cummins C100',
    make: 'Cummins',
    model: 'C100',
    serialNumber: 'SN-009',
    voltage: '480V',
    location: 'North roof',
    siteCode: 'Q884',
  );

  group('normalizeAssetLookup', () {
    test('uses the final segment of a QR URL', () {
      expect(
        normalizeAssetLookup('https://voltcore.example/assets/ASSET-123'),
        'asset-123',
      );
    });

    test('trims and folds a scanner value', () {
      expect(normalizeAssetLookup('  SN-009\n'), 'sn-009');
    });
  });

  group('assetMatchesLookup', () {
    test('matches exact asset id, serial number and site code', () {
      expect(assetMatchesLookup(asset, 'asset-123'), isTrue);
      expect(assetMatchesLookup(asset, 'sn-009'), isTrue);
      expect(assetMatchesLookup(asset, 'Q884'), isTrue);
    });

    test('matches a QR URL containing the asset id', () {
      expect(
        assetMatchesLookup(asset, 'https://voltcore.example/assets/asset-123'),
        isTrue,
      );
    });

    test('keeps browse matching for human-facing fields', () {
      expect(assetMatchesLookup(asset, 'north'), isTrue);
      expect(assetMatchesLookup(asset, 'different'), isFalse);
    });
  });
}
