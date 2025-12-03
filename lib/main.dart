import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:voltcore/features/maintenance/infra/models/maintenance_record.dart';
import '../app/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/inspections/infra/models/load_test_record.dart';
import 'features/inspections/infra/models/nameplate_data.dart';
import 'features/inspections/infra/models/test_interval_record.dart';
import 'features/inspections/infra/datasources/hive_boxes.dart';
import 'features/inspections/infra/models/inspection.dart';
import 'features/maintenance/infra/datasources/hive_boxes_maintenance.dart';

void main() async {
  // Ensure Flutte is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  Hive.registerAdapter(MaintenanceRecordAdapter());
  Hive.registerAdapter(InspectionAdapter());
  Hive.registerAdapter(LoadTestRecordAdapter());
  Hive.registerAdapter(NameplateDataAdapter());
  Hive.registerAdapter(TestIntervalRecordAdapter());

  // Initialize all boxes
  try {
    await MaintenanceBoxes.init();
    // Add other box initializations here:
    // await InspectionBoxes.init();
    // await OtherBoxes.init();

    debugPrint('✅ All Hive boxes initialized successfully');
  } catch (e) {
    debugPrint('❌ Error initializing Hive boxes: $e');
    // Handle initialization error - maybe show error screen
  }

  await HiveBoxes.init();

  runApp(const ProviderScope(child:App()));
}

class App extends ConsumerWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //final appRouter = ref.watch(goRouterProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Generator Compliance',
      theme: buildTheme(),
      routerConfig: appRouter,
    );
  }
}
