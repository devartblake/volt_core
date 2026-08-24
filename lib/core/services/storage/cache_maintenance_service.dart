import 'package:flutter/foundation.dart';

import 'file_storage_service.dart';

class CacheClearResult {
  const CacheClearResult({
    required this.cleared,
    required this.message,
  });

  final bool cleared;
  final String message;
}

/// Clears only disposable platform cache data.
///
/// Hive boxes, sync outbox entries, PDFs, photos, signatures, and other
/// persistent evidence are intentionally outside this boundary.
class CacheMaintenanceService {
  CacheMaintenanceService._();

  static final CacheMaintenanceService instance = CacheMaintenanceService._();

  Future<CacheClearResult> clearTemporaryCache() async {
    if (kIsWeb) {
      return const CacheClearResult(
        cleared: false,
        message: 'Voltcore has no disposable filesystem cache on web. '
            'Offline records and generated documents were left untouched.',
      );
    }

    await FileStorageService.instance.cleanCache();
    return const CacheClearResult(
      cleared: true,
      message: 'Temporary cache cleared. Offline records and queued sync work '
          'were preserved.',
    );
  }
}
