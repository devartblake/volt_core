import 'package:hive/hive.dart';

/// Drives a Hive [TypeAdapter] without a real box, so a stored row can be
/// truncated and replayed.
///
/// ## The invariant this exists to protect
///
/// A Hive row stores only the fields that existed when it was written. Add a
/// field to a model and every row already on a technician's device comes back
/// with `fields[n] == null` for it. The generated (and hand-written) adapters
/// in this project read fields as `fields[n] as String`, which throws a
/// `TypeError` on null — and because the whole record fails to decode, the
/// symptom is not a blank column, it is the entire list failing to load.
///
/// So: **every field added after a model has shipped must tolerate absence.**
/// Two ways to get that, both of which survive regeneration because they live
/// in the model rather than in the generated text:
///
///   * `@HiveField(n, defaultValue: '')` — hive_generator then emits
///     `fields[n] == null ? '' : fields[n] as String`.
///   * a nullable constructor parameter — the generator keys its cast off the
///     parameter type, so `Map<String, String>?` yields `as Map?`.
///
/// `hive_adapter_forward_compat_test.dart` enforces this by replaying each
/// adapter's own output truncated to every field count the model has ever had.
/// Adding a field without one of the two treatments fails it immediately, with
/// the same error the device would throw.
class HiveAdapterProbe<T> {
  const HiveAdapterProbe(this.adapter);

  final TypeAdapter<T> adapter;

  /// Encode [model] and report what the adapter wrote.
  CapturedRow encode(T model) {
    final writer = _CapturingWriter();
    adapter.write(writer, model);
    return CapturedRow(writer.declaredCount, writer.fields);
  }

  /// Decode a row holding only the fields with index `< size`, i.e. what a
  /// build that predates every later field would have stored.
  T readTruncatedTo(int size, T model) {
    final kept =
        encode(model).fields.where((field) => field.key < size).toList();
    return adapter.read(_ReplayReader(kept));
  }
}

/// What an adapter emitted for one record.
class CapturedRow {
  const CapturedRow(this.declaredCount, this.fields);

  /// The count the adapter *claims*, i.e. its leading `writeByte(n)`. Kept
  /// apart from [fields] so the two can be compared — Hive reads back exactly
  /// this many fields, so if it drifts below what is written the tail is
  /// silently dropped on every load.
  final int? declaredCount;

  /// `(fieldIndex, value)` in write order.
  final List<MapEntry<int, dynamic>> fields;
}

class _CapturingWriter implements BinaryWriter {
  final List<MapEntry<int, dynamic>> fields = [];
  int? declaredCount;
  int? _pending;

  @override
  void writeByte(int byte) {
    // The first writeByte is the field count; after that they alternate
    // index, value.
    if (declaredCount == null) {
      declaredCount = byte;
    } else {
      _pending = byte;
    }
  }

  @override
  void write<T>(T value, {bool writeTypeId = true}) {
    fields.add(MapEntry(_pending!, value));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _ReplayReader implements BinaryReader {
  _ReplayReader(this.fields);

  final List<MapEntry<int, dynamic>> fields;
  int _cursor = 0;
  bool _countRead = false;

  @override
  int readByte() {
    if (!_countRead) {
      _countRead = true;
      return fields.length;
    }
    return fields[_cursor].key;
  }

  @override
  dynamic read([int? typeId]) {
    final value = fields[_cursor].value;
    _cursor++;
    return value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
