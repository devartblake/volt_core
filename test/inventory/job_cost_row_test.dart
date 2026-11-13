import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/auth/domain/usecases/login_usecase.dart';
import 'package:voltcore/modules/auth/domain/usecases/logout_usecase.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/auth/presenter/controllers/auth_controller.dart';
import 'package:voltcore/modules/auth/state/auth_state.dart';
import 'package:voltcore/modules/inventory/domain/catalog_part.dart';
import 'package:voltcore/modules/inventory/domain/job_cost.dart';
import 'package:voltcore/modules/inventory/infra/inventory_repository.dart';
import 'package:voltcore/modules/inventory/presenter/inventory_access.dart';
import 'package:voltcore/modules/inventory/presenter/movement_providers.dart';
import 'package:voltcore/modules/inventory/presenter/widgets/job_cost_row.dart';
import 'package:voltcore/modules/permissions/domain/permission.dart';
import 'package:voltcore/modules/permissions/infra/permission_overrides_repository.dart';

import '../permissions/permission_test.dart' show FakeCache, FakeOverridesRepo;

class _FakeLogin extends Fake implements LoginUseCase {}

class _FakeLogout extends Fake implements LogoutUseCase {}

final _t = DateTime.utc(2026);
final _part = CatalogPart(
    id: 'p1',
    partNumber: 'LF3000',
    name: 'Oil filter',
    createdAt: _t,
    updatedAt: _t);

const _cost = JobCost([
  JobPartCost(partId: 'p1', qty: 2, unitCents: 61725),
  JobPartCost(partId: 'p2', qty: 1),
]);

List<Override> _overrides(UserRole role, FakeOverridesRepo repo) => [
      authStateProvider.overrideWith((ref) {
        final ctl = AuthController(ref, _FakeLogin(), _FakeLogout());
        ctl.state = AuthState(
          isAuthenticated: true,
          currentRole: role,
          userId: 'u1',
          displayName: 'Test',
          grantedRoles: {role},
        );
        return ctl;
      }),
      permissionOverridesRepositoryProvider.overrideWithValue(repo),
      permissionOverridesCacheProvider.overrideWithValue(FakeCache()),
      jobCostsProvider
          .overrideWith((ref) async => {'maintenance:m1': _cost}),
      catalogPartsProvider.overrideWith((ref) async => [_part]),
    ];

Widget _host(UserRole role, {FakeOverridesRepo? repo, String ref = 'maintenance:m1'}) =>
    ProviderScope(
      overrides: _overrides(role, repo ?? FakeOverridesRepo()),
      child: MaterialApp(
        home: Scaffold(body: JobCostRow(jobRef: ref)),
      ),
    );

void main() {
  testWidgets('an admin sees the parts cost row, expandable to lines',
      (t) async {
    await t.pumpWidget(_host(UserRole.admin));
    await t.pump();
    await t.pump();
    expect(find.text('Parts cost \$1,234.50'), findsOneWidget);
    expect(find.text('2 parts · 1 not priced'), findsOneWidget);
    await t.tap(find.byKey(const Key('job_cost_row_maintenance:m1')));
    await t.pumpAndSettle();
    expect(find.text('LF3000'), findsOneWidget);
    expect(find.textContaining('2 × \$617.25 = \$1,234.50'), findsOneWidget);
    expect(find.textContaining('1 × not priced'), findsOneWidget);
  });

  testWidgets('nothing for a job with no issued parts', (t) async {
    await t.pumpWidget(_host(UserRole.admin, ref: 'maintenance:other'));
    await t.pump();
    await t.pump();
    expect(find.textContaining('Parts cost'), findsNothing);
  });

  for (final role in UserRole.values.where((r) => r != UserRole.admin)) {
    testWidgets('${role.name} never sees a cost', (t) async {
      await t.pumpWidget(_host(role));
      await t.pump();
      await t.pump();
      expect(find.textContaining('Parts cost'), findsNothing);
      expect(find.textContaining('\$'), findsNothing);
    });
  }

  testWidgets('an Allow override for manage_inventory does not grant it',
      (t) async {
    final repo = FakeOverridesRepo(
        mine: {Permission.manageInventory: PermissionEffect.allow});
    await t.pumpWidget(_host(UserRole.tech, repo: repo));
    await t.pump();
    await t.pump();
    expect(find.textContaining('Parts cost'), findsNothing);
  });

  testWidgets('a Deny override on every permission does not hide it from an admin',
      (t) async {
    final repo = FakeOverridesRepo(mine: {
      for (final p in Permission.values) p: PermissionEffect.deny,
    });
    await t.pumpWidget(_host(UserRole.admin, repo: repo));
    await t.pump();
    await t.pump();
    expect(find.text('Parts cost \$1,234.50'), findsOneWidget);
  });

  test('the cost gate is a role check, not a catalogued permission', () {
    for (final r in UserRole.values) {
      expect(canSeeJobCost(r), r == UserRole.admin);
    }
    expect(canSeeJobCost(null), isFalse);
    expect(Permission.values.map((p) => p.key),
        isNot(contains('view_job_cost')));
  });

  for (final size in const [Size(360, 800), Size(1280, 800)]) {
    testWidgets('no overflow at 1.3x text on ${size.width.toInt()}x800',
        (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
              size: size, textScaler: const TextScaler.linear(1.3)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: JobCostView(
                jobRef: 'maintenance:m1',
                cost: _cost,
                partsById: {'p1': _part},
              ),
            ),
          ),
        ),
      ));
      await t.tap(find.byKey(const Key('job_cost_row_maintenance:m1')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    });
  }
}
