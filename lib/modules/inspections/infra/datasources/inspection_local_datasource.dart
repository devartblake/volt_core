import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:voltcore/core/services/hive/hive_boxes.dart';
import '../models/inspection.dart';
import '../models/nameplate_data.dart';
import '../../domain/entities/inspection_entity.dart';
import '../../domain/entities/nameplate_entity.dart';

/// Riverpod provider for the local datasource
final inspectionLocalDatasourceProvider =
Provider<InspectionLocalDatasource>((ref) {
  return InspectionLocalDatasource();
});

/// Local Hive-based datasource for inspections & nameplates.
class InspectionLocalDatasource {
  InspectionLocalDatasource();

  Future<List<InspectionEntity>> getAllInspections() async {
    final box = HiveBoxes.inspections;
    return box.values.map((m) => m.toEntity()).toList();
  }

  Future<InspectionEntity?> getInspectionById(String id) async {
    final box = HiveBoxes.inspections;
    for (final key in box.keys) {
      final item = box.get(key);
      if (item != null && item.id == id) {
        return item.toEntity();
      }
    }
    return null;
  }

  Future<InspectionEntity> saveInspection(InspectionEntity entity) async {
    final box = HiveBoxes.inspections;
    final model = inspectionFromEntity(entity);

    dynamic existingKey;
    for (final key in box.keys) {
      final item = box.get(key);
      if (item != null && item.id == entity.id) {
        existingKey = key;
        break;
      }
    }

    if (existingKey != null) {
      await box.put(existingKey, model);
    } else {
      await box.add(model);
    }

    return model.toEntity();
  }

  Future<void> deleteInspection(String id) async {
    final box = HiveBoxes.inspections;
    dynamic existingKey;
    for (final key in box.keys) {
      final item = box.get(key);
      if (item != null && item.id == id) {
        existingKey = key;
        break;
      }
    }
    if (existingKey != null) {
      await box.delete(existingKey);
    }
  }

  Future<List<NameplateEntity>> getNameplatesForInspection(
      String inspectionId) async {
    final box = HiveBoxes.nameplates;
    return box.values
        .where((n) => n.inspectionId == inspectionId)
        .map((n) => n.toEntity())
        .toList();
  }

  Future<NameplateEntity> saveNameplate(NameplateEntity entity) async {
    final box = HiveBoxes.nameplates;
    final model = nameplateFromEntity(entity);

    dynamic existingKey;
    for (final key in box.keys) {
      final item = box.get(key);
      if (item != null && item.id == entity.id) {
        existingKey = key;
        break;
      }
    }

    if (existingKey != null) {
      await box.put(existingKey, model);
    } else {
      await box.add(model);
    }

    return model.toEntity();
  }
}
