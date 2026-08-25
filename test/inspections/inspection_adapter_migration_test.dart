import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/modules/inspections/domain/entities/inspection_entity.dart';
import 'package:voltcore/modules/inspections/domain/inspection_checklist.dart';
import 'package:voltcore/modules/inspections/infra/models/inspection.dart';

/// Captures what [InspectionAdapter.write] emits, as (fieldIndex, value) pairs.
class _CapturingWriter implements BinaryWriter {
  final List<MapEntry<int, dynamic>> fields = [];
  int? _pending;

  /// The count the adapter *claims* to write, i.e. the leading `writeByte(66)`.
  /// Kept separate from [fields] so the two can be compared.
  int? declaredCount;

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

/// Replays captured fields, which is what a stored Hive row decodes as.
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

/// How many fields the adapter writes today. Bump alongside the adapter's
/// leading `writeByte(n)`; the test below asserts they agree.
const kInspectionAdapterFieldCount = 66;

void main() {
  final adapter = InspectionAdapter();

  _CapturingWriter encode(Inspection model) {
    final writer = _CapturingWriter();
    adapter.write(writer, model);
    return writer;
  }

  group('InspectionAdapter', () {
    test('round-trips the fields added after the address split', () {
      final model = inspectionFromEntity(
        InspectionEntity.newDraft().copyWith(
          address: '952 Flushing Ave',
          addressLine2: 'Suite 3',
          city: 'Brooklyn',
          state: 'NY',
          postalCode: '11206',
        ).withChecklistNote('exhaust_ok', 'Minor soot.'),
      );

      final restored = adapter.read(_ReplayReader(encode(model).fields));

      expect(restored.addressLine2, 'Suite 3');
      expect(restored.city, 'Brooklyn');
      expect(restored.state, 'NY');
      expect(restored.postalCode, '11206');
      expect(restored.checklistNotes, {'exhaust_ok': 'Minor soot.'});
    });

    // Every field added after this type shipped must tolerate being absent,
    // because rows already on a technician's device carry no entry for it.
    // Truncating to each historical field count is how a *future* field 66
    // gets caught too: add one without a `defaultValue:` (or a nullable
    // constructor parameter) and the shortest truncation below throws
    // "type 'Null' is not a subtype of type 'String' in type cast" — which is
    // exactly what the technician's device would do on every inspection.
    //
    // 61 is the field count of the release before the address split.
    const oldestShippedFieldCount = 61;

    for (var size = oldestShippedFieldCount;
        size <= kInspectionAdapterFieldCount;
        size++) {
      test('reads a row holding only the first $size fields', () {
        final model = inspectionFromEntity(
          InspectionEntity.newDraft().copyWith(address: 'Legacy row'),
        );

        final truncated =
            encode(model).fields.where((field) => field.key < size).toList();
        expect(truncated, hasLength(size));

        final restored = adapter.read(_ReplayReader(truncated));

        // Whatever is missing falls back to a usable empty value rather than
        // throwing, and what *was* stored is untouched.
        expect(restored.address, 'Legacy row');
        expect(restored.formattedAddress, 'Legacy row');
        expect(restored.addressLine2, isA<String>());
        expect(restored.city, isA<String>());
        expect(restored.state, isA<String>());
        expect(restored.postalCode, isA<String>());
        expect(restored.checklistNotes, isA<Map<String, String>>());
      });
    }

    test('declares exactly as many fields as it writes', () {
      // Guards the hand-maintained count. The adapter opens with a single
      // writeByte(n) and Hive reads exactly n fields back, so if adding a
      // field does not also bump that number the tail is silently dropped on
      // every load.
      final writer = encode(inspectionFromEntity(InspectionEntity.newDraft()));

      expect(writer.declaredCount, writer.fields.length);
      expect(writer.declaredCount, kInspectionAdapterFieldCount);
      expect(
        writer.fields.map((f) => f.key).toSet(),
        hasLength(kInspectionAdapterFieldCount),
      );
      expect(
        writer.fields.map((f) => f.key).reduce((a, b) => a > b ? a : b),
        kInspectionAdapterFieldCount - 1,
      );
    });
  });
}
