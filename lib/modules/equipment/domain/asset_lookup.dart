import 'entities/equipment_entity.dart';

/// Normalizes text produced by a keyboard-wedge barcode/QR scanner.
///
/// Most scanners send their value followed by Enter. Some QR labels contain a
/// Voltcore URL; keeping the final non-empty path segment makes those labels
/// resolve to the asset id as well as plain serial-number labels.
String normalizeAssetLookup(String rawValue) {
  var value = rawValue.trim();
  if (value.isEmpty) return '';

  final uri = Uri.tryParse(value);
  if (uri != null && uri.hasScheme && uri.pathSegments.isNotEmpty) {
    value = uri.pathSegments.last;
  }

  return value.trim().toLowerCase();
}

/// Returns whether [asset] can be located from a manual search or a scanner.
///
/// IDs, serial numbers and site codes are treated as exact identifiers. The
/// human-facing fields retain contains matching so the registry remains useful
/// when the user is browsing rather than scanning a label.
bool assetMatchesLookup(EquipmentEntity asset, String rawQuery) {
  final query = normalizeAssetLookup(rawQuery);
  if (query.isEmpty) return true;

  final identifiers = <String>[
    asset.id,
    asset.serialNumber,
    asset.siteCode,
  ].map(normalizeAssetLookup);
  if (identifiers.any((identifier) => identifier == query)) return true;

  return <String>[
    asset.name,
    asset.make,
    asset.model,
    asset.location,
  ].any((value) => value.toLowerCase().contains(query));
}
