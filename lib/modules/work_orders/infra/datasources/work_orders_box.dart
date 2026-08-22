import 'package:hive/hive.dart';

import '../models/work_order_record.dart';

class WorkOrdersBox {
  WorkOrdersBox._();

  static const boxName = 'work_orders';
  static Box<WorkOrderRecord>? _box;

  static Box<WorkOrderRecord> get box =>
      _box ?? (throw StateError('WorkOrdersBox.init() must be called before use.'));

  static Future<void> init() async {
    _box = Hive.isBoxOpen(boxName)
        ? Hive.box<WorkOrderRecord>(boxName)
        : await Hive.openBox<WorkOrderRecord>(boxName);
  }
}
