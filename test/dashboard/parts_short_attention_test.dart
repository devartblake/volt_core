import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/dashboard/domain/dashboard_summary.dart';

AttentionInputs _in(DashboardAudience a, {int short = 0, String route = '/inventory/shortages'}) =>
    AttentionInputs(
      audience: a,
      summary: DashboardSummary.empty,
      workload: null,
      redGradeSites: 0,
      vehiclesNeedingDailyCheck: null,
      jobsShortOfParts: short,
      routes: AttentionRoutes(
        schedule: '/s', jobs: '/j', inspections: '/i', fleetLog: '/f', shortages: route),
    );

void main() {
  test('dispatch, review and admin are told how many jobs are short', () {
    for (final a in [DashboardAudience.dispatch, DashboardAudience.review, DashboardAudience.admin]) {
      final items = buildAttention(_in(a, short: 2));
      expect(items.single.label, 'Parts short for 2 jobs', reason: '$a');
      expect(items.single.route, '/inventory/shortages');
      expect(items.single.severity, AttentionSeverity.warning);
    }
  });

  test('singular, and nothing when none are short', () {
    expect(buildAttention(_in(DashboardAudience.admin, short: 1)).single.label,
        'Parts short for 1 job');
    expect(buildAttention(_in(DashboardAudience.admin)), isEmpty);
  });

  test('technicians are never told', () {
    expect(buildAttention(_in(DashboardAudience.field, short: 5)), isEmpty);
    expect(DashboardAudience.of(UserRole.tech), DashboardAudience.field);
  });

  test('no line without a Shortages route', () {
    expect(buildAttention(_in(DashboardAudience.admin, short: 3, route: '')), isEmpty);
  });
}
