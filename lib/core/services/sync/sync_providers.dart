import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'sync_service.dart';

/// The singleton sync orchestrator.
final syncServiceProvider = Provider<SyncService>((ref) => SyncService.instance);

/// Reactive stream of the current [SyncStatus] for UI widgets.
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final service = ref.watch(syncServiceProvider);
  final notifier = service.status;

  late final StreamController<SyncStatus> controller;
  void listener() => controller.add(notifier.value);

  controller = StreamController<SyncStatus>(
    onListen: () {
      controller.add(notifier.value);
      notifier.addListener(listener);
    },
    onCancel: () => notifier.removeListener(listener),
  );

  ref.onDispose(controller.close);
  return controller.stream;
});
