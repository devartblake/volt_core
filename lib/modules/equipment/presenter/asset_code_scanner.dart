import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/mobile_asset_code_scanner.dart';

/// Reads a barcode / QR / nameplate code with the camera.
///
/// Kept behind an interface so the search page never touches a camera plugin
/// directly: tests override [assetCodeScannerProvider] with a fake, and
/// platforms without a camera simply report [isSupported] false so the Scan
/// button is hidden.
abstract class AssetCodeScanner {
  /// Whether this platform can scan at all.
  bool get isSupported;

  /// Opens the scanner and returns the scanned text, or null if cancelled.
  Future<String?> scan(BuildContext context);
}

/// For tests and platforms without a camera.
class UnsupportedAssetCodeScanner implements AssetCodeScanner {
  const UnsupportedAssetCodeScanner();

  @override
  bool get isSupported => false;

  @override
  Future<String?> scan(BuildContext context) async => null;
}

final assetCodeScannerProvider = Provider<AssetCodeScanner>(
  (ref) => const MobileAssetCodeScanner(),
);
