import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'selection_options_service.dart';

final selectionOptionsProvider = Provider<SelectionOptionsService>((ref) {
  final svc = SelectionOptionsService();
  // fire-and-forget init; if you prefer, await in main before runApp
  svc.init();
  return svc;
});

final selectionOptionsReadyProvider = FutureProvider<void>((ref) async {
  final svc = ref.read(selectionOptionsProvider);
  await svc.ensureReady();
});