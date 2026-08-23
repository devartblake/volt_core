import 'package:hive/hive.dart';

import '../models/form_response_record.dart';

class FormResponsesBox {
  FormResponsesBox._();

  static const boxName = 'form_responses';
  static Box<FormResponseRecord>? _box;

  static Box<FormResponseRecord> get box {
    final cached = _box;
    if (cached != null && cached.isOpen) return cached;
    if (Hive.isBoxOpen(boxName)) return _box = Hive.box<FormResponseRecord>(boxName);
    throw StateError('FormResponsesBox.init() must be called before use.');
  }

  static Future<void> init() async {
    final cached = _box;
    if (cached != null && cached.isOpen) return;
    _box = Hive.isBoxOpen(boxName)
        ? Hive.box<FormResponseRecord>(boxName)
        : await Hive.openBox<FormResponseRecord>(boxName);
  }

  static void invalidate() => _box = null;
}
