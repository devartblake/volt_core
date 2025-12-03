import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../infra/repositories/inspection_repo.dart';

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

/// Provider that calculates badge counts from inspection infra
final appBadgesProvider = Provider<AppBadges>((ref) {
  final inspections = ref.watch(inspectionRepoProvider).listAll();

  // Calculate various counts
  final total = inspections.length;

  // Count pending inspections (you can define your own controllers)
  // For example, inspections without nameplate infra or recent ones
  final pending = inspections.where((ins) {
    // TODO: Define your pending controllers
    // For now, counting inspections from the last 7 days as "pending review"
    final daysSince = DateTime.now().difference(ins.serviceDate).inDays;
    return daysSince <= 7;
  }).length;

  // Count by grade
  final redGrade = inspections.where((ins) =>
  ins.siteGrade.toLowerCase() == 'red'
  ).length;

  final amberGrade = inspections.where((ins) =>
  ins.siteGrade.toLowerCase() == 'amber'
  ).length;

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