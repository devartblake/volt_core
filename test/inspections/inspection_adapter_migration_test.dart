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

    test('reads a row written before those fields existed', () {
      // The migration case, and the reason inspection.g.dart reads fields 61+
      // with null-safe casts. That file is checked in without build_runner in
      // the pubspec, so regenerating it would emit bare `as String` casts —
      // and every inspection already on a technician's tablet would start
      // throwing a TypeError on load.
      final model = inspectionFromEntity(
        InspectionEntity.newDraft().copyWith(address: 'Legacy row'),
      );

      final legacyFields =
          encode(model).fields.where((field) => field.key <= 60).toList();
      expect(legacyFields, hasLength(61), reason: 'fields 0..60 only');

      final restored = adapter.read(_ReplayReader(legacyFields));

      expect(restored.address, 'Legacy row');
      expect(restored.addressLine2, '');
      expect(restored.city, '');
      expect(restored.state, '');
      expect(restored.postalCode, '');
      expect(restored.checklistNotes, isEmpty);

      // And it still composes back to exactly what was stored.
      expect(restored.formattedAddress, 'Legacy row');
    });

    test('declares exactly as many fields as it writes', () {
      // Guards the hand-maintained count. The adapter opens with a single
      // writeByte(n) and Hive reads exactly n fields back, so if adding a
      // field does not also bump that number the tail is silently dropped on
      // every load.
      final writer = encode(inspectionFromEntity(InspectionEntity.newDraft()));

      expect(writer.declaredCount, writer.fields.length);
      expect(writer.declaredCount, 66);
      expect(writer.fields.map((f) => f.key).toSet(), hasLength(66));
      expect(
        writer.fields.map((f) => f.key).reduce((a, b) => a > b ? a : b),
        65,
      );
    });
  });
}
