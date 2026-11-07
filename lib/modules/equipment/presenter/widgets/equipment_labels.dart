import 'package:flutter/material.dart';

import '../../../../core/theme/status_colors.dart';
import '../../../../providers/equipment_providers.dart';
import '../../domain/entities/equipment_entity.dart' show AssetType;

String equipmentAssetTypeLabel(AssetType assetType) {
  switch (assetType) {
    case AssetType.generator:
      return 'Generator';
    case AssetType.transferSwitch:
      return 'Transfer switch';
    case AssetType.switchgear:
      return 'Switchgear';
    case AssetType.panelboard:
      return 'Panelboard';
    case AssetType.transformer:
      return 'Transformer';
    case AssetType.emergencyLighting:
      return 'Emergency lighting';
    case AssetType.ups:
      return 'UPS';
    case AssetType.evCharger:
      return 'EV charger';
    case AssetType.batteryEnergyStorage:
      return 'Battery energy storage';
    case AssetType.other:
      return 'Other asset';
  }
}

IconData equipmentAssetTypeIcon(AssetType assetType) {
  switch (assetType) {
    case AssetType.generator:
      return Icons.settings_power_outlined;
    case AssetType.transferSwitch:
      return Icons.swap_horiz_outlined;
    case AssetType.switchgear:
      return Icons.electrical_services_outlined;
    case AssetType.panelboard:
      return Icons.grid_view_outlined;
    case AssetType.transformer:
      return Icons.power_outlined;
    case AssetType.emergencyLighting:
      return Icons.emergency_outlined;
    case AssetType.ups:
      return Icons.battery_charging_full_outlined;
    case AssetType.evCharger:
      return Icons.ev_station_outlined;
    case AssetType.batteryEnergyStorage:
      return Icons.battery_saver_outlined;
    case AssetType.other:
      return Icons.precision_manufacturing_outlined;
  }
}

String equipmentStatusLabel(EquipmentStatus status) {
  switch (status) {
    case EquipmentStatus.active:
      return 'Active';
    case EquipmentStatus.inactive:
      return 'Inactive';
    case EquipmentStatus.maintenance:
      return 'Maintenance';
    case EquipmentStatus.retired:
      return 'Retired';
  }
}

/// Outlined status icon, used on filter chips.
IconData equipmentStatusOutlineIcon(EquipmentStatus status) {
  switch (status) {
    case EquipmentStatus.active:
      return Icons.check_circle_outline;
    case EquipmentStatus.inactive:
      return Icons.pause_circle_outline;
    case EquipmentStatus.maintenance:
      return Icons.build_circle_outlined;
    case EquipmentStatus.retired:
      return Icons.cancel_outlined;
  }
}

/// Solid status icon, used on result cards and the detail pane.
IconData equipmentStatusIcon(EquipmentStatus status) {
  switch (status) {
    case EquipmentStatus.active:
      return Icons.check_circle;
    case EquipmentStatus.inactive:
      return Icons.pause_circle;
    case EquipmentStatus.maintenance:
      return Icons.build_circle;
    case EquipmentStatus.retired:
      return Icons.cancel;
  }
}

/// Colour for an equipment status, from the theme so dark mode follows.
Color equipmentStatusColor(EquipmentStatus status, ThemeData theme) {
  switch (status) {
    case EquipmentStatus.active:
      return theme.status.success;
    case EquipmentStatus.inactive:
      // Not a problem, just not in service: neutral rather than a status hue.
      return theme.colorScheme.outline;
    case EquipmentStatus.maintenance:
      return theme.status.warning;
    case EquipmentStatus.retired:
      return theme.colorScheme.error;
  }
}

/// "Today", "3 days ago", "2 months ago"...
String equipmentRelativeDate(DateTime date, {DateTime? now}) {
  final difference = (now ?? DateTime.now()).difference(date).inDays;

  if (difference == 0) return 'Today';
  if (difference == 1) return 'Yesterday';
  if (difference < 30) return '$difference days ago';
  if (difference < 365) return '${(difference / 30).floor()} months ago';
  return '${(difference / 365).floor()} years ago';
}
