import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/inspection_entity.dart';
import 'inspection_list_controller.dart';

/// Model for badge infra across the app
class AppBadges {
  final int totalInspections;
  final int pendingInspections;
  final int redGradeInspections;
  final int amberGradeInspections;

  const AppBadges({
    required this.totalInspections,
    required this.pendingInspections,
    required this.redGradeInspections,
    required this.amberGradeInspections,
  });

  /// Convert to the format expected by ResponsiveScaffold/AppDrawer
  Map<String, int> toRouteMap() {
    return {
      '/': totalInspections,
      '/inspections': totalInspections,
      '/inspection/new': 0, // No badge for new inspection route
      '/options': 0,
      '/nameplate-list': 0,
      '/settings': 0,
    };
  }
}

/// Provider that calculates badge counts from inspections.
///
/// Uses the InspectionListController (which, in turn, uses the
/// domain repository + usecases).
final appBadgesProvider = Provider<AppBadges>((ref) {
  final state = ref.watch(inspectionListControllerProvider);
  final inspections = state.items; // List<InspectionEntity>

  // Lazy auto-load if nothing is loaded yet
  if (!state.isLoading && inspections.isEmpty) {
    Future.microtask(() {
      ref
          .read(inspectionListControllerProvider.notifier)
          .loadInspections();
    });
  }

  final now = DateTime.now();

  int _daysSince(InspectionEntity ins) {
    final date = ins.serviceDate ?? ins.createdAt ?? now;
    return now.difference(date).inDays;
  }

  final total = inspections.length;

  // "Pending" definition: last 7 days
  final pending = inspections
      .where((ins) => _daysSince(ins) <= 7)
      .length;

  final redGrade = inspections
      .where((ins) =>
  (ins.siteGrade ?? '').toLowerCase() == 'red')
      .length;

  final amberGrade = inspections
      .where((ins) =>
  (ins.siteGrade ?? '').toLowerCase() == 'amber')
      .length;

  return AppBadges(
    totalInspections: total,
    pendingInspections: pending,
    redGradeInspections: redGrade,
    amberGradeInspections: amberGrade,
  );
});

/// Individual badge providers for specific use cases
final pendingCountProvider = Provider<int>((ref) {
  return ref.watch(appBadgesProvider).pendingInspections;
});

final criticalCountProvider = Provider<int>((ref) {
  return ref.watch(appBadgesProvider).redGradeInspections;
});

final warningCountProvider = Provider<int>((ref) {
  return ref.watch(appBadgesProvider).amberGradeInspections;
});
