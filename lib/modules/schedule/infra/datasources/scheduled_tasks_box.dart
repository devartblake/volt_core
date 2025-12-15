import 'package:hive/hive.dart';
import '../models/schedule_task.dart';

class ScheduledTasksBox {
  static const String boxName = 'scheduled_tasks';

  static Future<Box<ScheduledTask>> open() async {
    if (!Hive.isAdapterRegistered(kScheduledTaskTypeId)) {
      Hive.registerAdapter(ScheduledTaskAdapter());
    }
    return Hive.openBox<ScheduledTask>(boxName);
  }

  static Box<ScheduledTask> get box => Hive.box<ScheduledTask>(boxName);
}
