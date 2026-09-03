import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/app/route_roles.dart';
import 'package:voltcore/core/constants/feature_flags.dart';
import 'package:voltcore/core/constants/route_paths.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/templates/presenter/widgets/generator_pilot_launch_panel.dart';

void main() {
  test('pilot execution route stays available to operational roles', () {
    for (final role in const {
      UserRole.tech,
      UserRole.supervisor,
      UserRole.dispatcher,
      UserRole.admin,
    }) {
      expect(
        RouteRoles.isAllowedByName(
          name: RouteNames.templateResponse,
          role: role,
        ),
        isTrue,
        reason: '${role.name} must be able to execute the controlled pilot',
      );
    }

    expect(
      RoutePaths.generatorInspectionPilot,
      '/field-forms/generator-inspection',
    );
    expect(
      RoutePaths.generatorMaintenancePilot,
      '/field-forms/generator-maintenance',
    );
  });

  testWidgets('technician launch panel follows the compile-time pilot flag',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: GeneratorPilotLaunchPanel()),
      ),
    );

    if (FeatureFlags.generatorTemplatePilotEnabled) {
      expect(find.text('Generator Template Pilot'), findsOneWidget);
      expect(find.text('Start inspection pilot'), findsOneWidget);
      expect(find.text('Start maintenance pilot'), findsOneWidget);
    } else {
      expect(find.text('Generator Template Pilot'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(OutlinedButton), findsNothing);
    }
  });
}
