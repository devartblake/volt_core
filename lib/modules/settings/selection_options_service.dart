import 'package:hive/hive.dart';

class SelectionOptionsService {
  static const _boxName = 'selection_options';
  static const kTechs = 'techs';
  static const kMakes = 'makes';
  static const kVoltages = 'voltages';

  Box? _box; // <-- nullable so we can guard safely

  bool get isReady => _box != null;

  /// Call once at startup (or let UI await via selectionOptionsReadyProvider)
  Future<void> init() async {
    if (_box != null) return;
    final b = await Hive.openBox(_boxName);
    if (!b.containsKey(kTechs)) await b.put(kTechs, <String>[]);
    if (!b.containsKey(kMakes)) await b.put(kMakes, <String>[]);
    if (!b.containsKey(kVoltages)) await b.put(kVoltages, <String>[]);
    _box = b;
  }

  /// For UI that wants to be extra safe, ensures readiness.
  Future<void> ensureReady() => init();

  // Getters are now guarded; return [] until ready instead of throwing
  List<String> get techs =>
      List<String>.from((_box?.get(kTechs, defaultValue: <String>[]) ?? <String>[]) as List);
  List<String> get makes =>
      List<String>.from((_box?.get(kMakes, defaultValue: <String>[]) ?? <String>[]) as List);
  List<String> get voltages =>
      List<String>.from((_box?.get(kVoltages, defaultValue: <String>[]) ?? <String>[]) as List);

  Future<void> addTech(String v)     async => _add(kTechs, v);
  Future<void> addMake(String v)     async => _add(kMakes, v);
  Future<void> addVoltage(String v)  async => _add(kVoltages, v);

  Future<void> removeTechAt(int i)     async => _removeAt(kTechs, i);
  Future<void> removeMakeAt(int i)     async => _removeAt(kMakes, i);
  Future<void> removeVoltageAt(int i)  async => _removeAt(kVoltages, i);

  Future<void> _add(String key, String value) async {
    await ensureReady();
    final list = List<String>.from(_box!.get(key, defaultValue: <String>[]) as List);
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    if (!list.contains(trimmed)) {
      list.add(trimmed);
      await _box!.put(key, list);
    }
  }

  Future<void> _removeAt(String key, int index) async {
    await ensureReady();
    final list = List<String>.from(_box!.get(key, defaultValue: <String>[]) as List);
    if (index < 0 || index >= list.length) return;
    list.removeAt(index);
    await _box!.put(key, list);
  }
}
