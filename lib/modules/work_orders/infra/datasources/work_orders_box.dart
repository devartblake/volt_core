import 'package:hive/hive.dart';

import '../models/work_order_record.dart';

class WorkOrdersBox {
  WorkOrdersBox._();

  static const boxName = 'work_orders';
  static Box<WorkOrderRecord>? _box;

  /// The open box.
  ///
  /// The cached handle is only trusted while it is still open. HiveService's
  /// reset closes every box and reopens new instances, so a plain non-null
  /// cache hands back a dead one and every use throws "Box has already been
  /// closed" for the rest of the session.
  static Box<WorkOrderRecord> get box {
    final cached = _box;
    if (cached != null && cached.isOpen) return cached;
    if (Hive.isBoxOpen(boxName)) {
      return _box = Hive.box<WorkOrderRecord>(boxName);
    }
    throw StateError('WorkOrdersBox.init() must be called before use.');
  }

  static Future<void> init() async {
    final cached = _box;
    if (cached != null && cached.isOpen) return;
    _box = Hive.isBoxOpen(boxName)
        ? Hive.box<WorkOrderRecord>(boxName)
        : await Hive.openBox<WorkOrderRecord>(boxName);
  }

  /// Drop the cached handle so the next access re-resolves.
  static void invalidate() => _box = null;
}
