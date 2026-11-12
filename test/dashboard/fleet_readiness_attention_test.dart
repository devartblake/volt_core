import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/dashboard/domain/dashboard_summary.dart';

AttentionInputs _in(
  DashboardAudience a, {
  int notReady = 0,
  String route = '/readiness?status=notReady',
}) =>
    AttentionInputs(
      audience: a,
      summary: DashboardSummary.empty,
      workload: null,
      redGradeSites: 0,
      vehiclesNeedingDailyCheck: null,
      generatorsNotReady: notReady,
      routes: AttentionRoutes(
        schedule: '/s',
        jobs: '/j',
        inspections: '/i',
        fleetLog: '/f',
        readinessNotReady: route,
      ),
    );

void main() {
  test('dispatch, review and admin are told how many generators are not ready',
      () {
    for (final a in [
      DashboardAudience.dispatch,
      DashboardAudience.review,
      DashboardAudience.admin
    ]) {
      final items = buildAttention(_in(a, notReady: 3));
      expect(items.single.label, '3 generators not ready', reason: '$a');
      expect(items.single.route, '/readiness?status=notReady');
      expect(items.single.severity, AttentionSeverity.critical);
    }
  });

  test('singular, and nothing when none are not ready', () {
    expect(buildAttention(_in(DashboardAudience.admin, notReady: 1)).single.label,
        '1 generator not ready');
    expect(buildAttention(_in(DashboardAudience.admin)), isEmpty);
  });

  test('technicians are never told, and no line without a route', () {
    expect(buildAttention(_in(DashboardAudience.field, notReady: 5)), isEmpty);
    expect(DashboardAudience.of(UserRole.tech), DashboardAudience.field);
    expect(
        buildAttention(_in(DashboardAudience.admin, notReady: 3, route: '')),
        isEmpty);
  });

  test('not-ready generators outrank warnings in the list', () {
    final items = buildAttention(const AttentionInputs(
      audience: DashboardAudience.admin,
      summary: DashboardSummary.empty,
      workload: null,
      redGradeSites: 2,
      vehiclesNeedingDailyCheck: null,
      generatorsNotReady: 4,
      routes: AttentionRoutes(
        schedule: '/s',
        jobs: '/j',
        inspections: '/i',
        fleetLog: '/f',
        readinessNotReady: '/readiness?status=notReady',
      ),
    ));
    expect(items.first.label, '4 generators not ready');
  });

  test('the fleet readiness tile reads "87% ready"; an empty fleet is not 100%',
      () {
    expect(fleetReadinessValue(86.6, 12), '87% ready');
    expect(fleetReadinessValue(0, 0), '-');
    expect(fleetReadinessLabel(86.6, 12), 'Generator fleet readiness 87% ready');
    expect(fleetReadinessLabel(0, 0), 'Generator fleet readiness: no generators yet');
  });
}
