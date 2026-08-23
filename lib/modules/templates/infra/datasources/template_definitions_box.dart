import 'package:hive/hive.dart';

/// JSON snapshots of published template definitions for offline rendering.
///
/// Template definitions are immutable once published, so a JSON cache is both
/// compact and safe to reuse after a restart. Responses retain the revision id
/// that selects the correct snapshot.
class TemplateDefinitionsBox {
  TemplateDefinitionsBox._();

  static const boxName = 'form_template_definitions';
  static Box<dynamic>? _box;

  static Box<dynamic> get box {
    final cached = _box;
    if (cached != null && cached.isOpen) return cached;
    if (Hive.isBoxOpen(boxName)) return _box = Hive.box<dynamic>(boxName);
    throw StateError('TemplateDefinitionsBox.init() must be called before use.');
  }

  static Future<void> init() async {
    final cached = _box;
    if (cached != null && cached.isOpen) return;
    _box = Hive.isBoxOpen(boxName)
        ? Hive.box<dynamic>(boxName)
        : await Hive.openBox<dynamic>(boxName);
  }

  static void invalidate() => _box = null;
}
