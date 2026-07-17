import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Thin wrapper around `connectivity_plus` that exposes a simple online/offline
/// signal for the sync layer.
///
/// Note: connectivity only reports the network *interface* state, not whether
/// the internet is actually reachable. That's fine here — [SyncService] treats
/// any failed request as a retryable error, so a false "online" just results in
/// an attempt that re-queues.
class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _online = true;

  /// Last known status without hitting the platform channel again.
  bool get isOnlineCached => _online;

  /// Emits whenever the online/offline status flips.
  Stream<bool> get onStatusChange => _controller.stream;

  Future<void> init() async {
    _online = await isOnline();
    _sub ??= _connectivity.onConnectivityChanged.listen((results) {
      final online = _isOnline(results);
      if (online != _online) {
        _online = online;
        _controller.add(online);
        if (kDebugMode) {
          debugPrint('[Connectivity] ${online ? 'ONLINE' : 'OFFLINE'}');
        }
      }
    });
  }

  /// Actively check the current connectivity state.
  Future<bool> isOnline() async {
    try {
      final results = await _connectivity.checkConnectivity();
      _online = _isOnline(results);
    } catch (_) {
      // If the platform check fails, assume online so we still attempt syncs.
      _online = true;
    }
    return _online;
  }

  bool _isOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any((r) => r != ConnectivityResult.none);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _controller.close();
  }
}
