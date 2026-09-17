import 'package:hive/hive.dart';

/// Next free typeId after VehicleAssetCheckLineRecord's 80.
const int kAssetDisclaimerTypeId = 81;
const int kFleetDepotTypeId = 82;

// ADDING A FIELD? It must tolerate being absent — read it as
// `fields[n] as String? ?? ''`, never a bare cast, and bump the leading
// writeByte(count). test/storage/hive_adapter_forward_compat_test.dart
// enforces this; update its currentFieldCount and leave
// fieldCountAtLastRelease alone.
@HiveType(typeId: kAssetDisclaimerTypeId)
class AssetDisclaimerRecord {
  const AssetDisclaimerRecord({
    required this.id,
    required this.tenantId,
    required this.version,
    required this.publishedAt,
    this.title = 'Asset Disclaimer',
    this.intro = '',
    this.clausesJson = '[]',
    this.closing = '',
  });

  @HiveField(0)
  final String id;
  @HiveField(1)
  final String tenantId;
  @HiveField(2)
  final int version;
  @HiveField(3)
  final String title;
  @HiveField(4)
  final String intro;

  /// The clause list as a JSON string rather than a nested Hive type.
  ///
  /// A second adapter for a two-field value object would be one more thing to
  /// keep forward-compatible for no benefit; the disclaimer is written once per
  /// revision and read whole.
  @HiveField(5)
  final String clausesJson;

  @HiveField(6)
  final String closing;
  @HiveField(7)
  final DateTime publishedAt;
}

class AssetDisclaimerRecordAdapter extends TypeAdapter<AssetDisclaimerRecord> {
  @override
  final int typeId = kAssetDisclaimerTypeId;

  @override
  AssetDisclaimerRecord read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var index = 0, count = reader.readByte(); index < count; index++) {
      fields[reader.readByte()] = reader.read();
    }
    return AssetDisclaimerRecord(
      id: fields[0] as String,
      tenantId: fields[1] as String,
      version: fields[2] as int? ?? 1,
      title: fields[3] as String? ?? 'Asset Disclaimer',
      intro: fields[4] as String? ?? '',
      clausesJson: fields[5] as String? ?? '[]',
      closing: fields[6] as String? ?? '',
      publishedAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, AssetDisclaimerRecord value) {
    writer
      ..writeByte(8)
      ..writeByte(0)..write(value.id)
      ..writeByte(1)..write(value.tenantId)
      ..writeByte(2)..write(value.version)
      ..writeByte(3)..write(value.title)
      ..writeByte(4)..write(value.intro)
      ..writeByte(5)..write(value.clausesJson)
      ..writeByte(6)..write(value.closing)
      ..writeByte(7)..write(value.publishedAt);
  }
}

// ADDING A FIELD? Same rules as above.
@HiveType(typeId: kFleetDepotTypeId)
class FleetDepotRecord {
  const FleetDepotRecord({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.address = '',
    this.notes = '',
    this.isActive = true,
  });

  @HiveField(0)
  final String id;
  @HiveField(1)
  final String tenantId;
  @HiveField(2)
  final String name;
  @HiveField(3)
  final String address;
  @HiveField(4)
  final String notes;
  @HiveField(5)
  final bool isActive;
  @HiveField(6)
  final DateTime createdAt;
  @HiveField(7)
  final DateTime updatedAt;
}

class FleetDepotRecordAdapter extends TypeAdapter<FleetDepotRecord> {
  @override
  final int typeId = kFleetDepotTypeId;

  @override
  FleetDepotRecord read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    for (var index = 0, count = reader.readByte(); index < count; index++) {
      fields[reader.readByte()] = reader.read();
    }
    return FleetDepotRecord(
      id: fields[0] as String,
      tenantId: fields[1] as String,
      name: fields[2] as String? ?? '',
      address: fields[3] as String? ?? '',
      notes: fields[4] as String? ?? '',
      isActive: fields[5] as bool? ?? true,
      createdAt: fields[6] as DateTime,
      updatedAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, FleetDepotRecord value) {
    writer
      ..writeByte(8)
      ..writeByte(0)..write(value.id)
      ..writeByte(1)..write(value.tenantId)
      ..writeByte(2)..write(value.name)
      ..writeByte(3)..write(value.address)
      ..writeByte(4)..write(value.notes)
      ..writeByte(5)..write(value.isActive)
      ..writeByte(6)..write(value.createdAt)
      ..writeByte(7)..write(value.updatedAt);
  }
}
