import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/app.dart';
import 'core/services/bootstrap.dart';
import 'core/services/hive/hive_service.dart';
import 'core/services/supabase/supabase_service.dart';
import 'core/storage/hive/hive_boxes.dart';
import 'modules/maintenance/infra/datasources/hive_boxes_maintenance.dart';
import 'core/configs/env.dart'; // for Env.current if you want flavor-based .env

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Load the proper .env *before* anything uses EnvConfig.current
  // You can switch file based on flavor/env if you want.
  final envFile = switch (Env.current) {
    AppEnvironment.dev => '.env.dev',
    AppEnvironment.staging => '.env.staging',
    AppEnvironment.prod => '.env.prod',
  };

  await dotenv.load(fileName: envFile);

  // 2) Init Hive (adapters etc.)
  await Hive.initFlutter();
  await HiveService.init();

  // 3) Init core services (this is where SupabaseService.init() runs)
  await initCoreServices();

  // 4) Any extra explicit init (you technically don’t need SupabaseService.init()
  //    again if initCoreServices already calls it, but leaving your structure)
  await SupabaseService.init();

  // 5) Maintenance Hive boxes
  await MaintenanceBoxes.init();
  HiveBoxes();

  runApp(
    const ProviderScope(
      child: VoltcoreApp(),
    ),
  );
}
