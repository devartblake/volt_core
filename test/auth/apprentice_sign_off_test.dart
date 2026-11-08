import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signature/signature.dart';
import 'package:voltcore/modules/auth/domain/usecases/login_usecase.dart';
import 'package:voltcore/modules/auth/domain/usecases/logout_usecase.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/auth/presenter/controllers/auth_controller.dart';
import 'package:voltcore/modules/auth/presenter/sign_off_access.dart';
import 'package:voltcore/modules/auth/state/auth_state.dart';
import 'package:voltcore/modules/inspections/domain/entities/inspection_entity.dart';
import 'package:voltcore/modules/inspections/presenter/widgets/section_signatures.dart';
import 'package:voltcore/modules/maintenance/infra/models/maintenance_record.dart';
import 'package:voltcore/modules/maintenance/presenter/widgets/section_maint_signatures.dart';

const _msg = 'A technician or supervisor needs to sign this off.';

class _FakeLogin extends Fake implements LoginUseCase {}

class _FakeLogout extends Fake implements LogoutUseCase {}

ProviderContainer _containerFor(UserRole? role) {
  final c = ProviderContainer(overrides: [
    authStateProvider.overrideWith((ref) {
      final ctl = AuthController(ref, _FakeLogin(), _FakeLogout());
      ctl.state = AuthState(
        isAuthenticated: role != null,
        currentRole: role,
        userId: 'u1',
        displayName: 'Test',
        grantedRoles: {if (role != null) role},
      );
      return ctl;
    }),
  ]);
  addTearDown(c.dispose);
  return c;
}

Widget _host(Widget child, {double scale = 1.3}) => MaterialApp(
      builder: (c, w) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: w!,
      ),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    );

/// Fails on overflow only; the maintenance card has an older, unrelated
/// ListTile-ink warning that is not what these tests are about.
void _noOverflow(WidgetTester t) {
  Object? e;
  while ((e = t.takeException()) != null) {
    if (e.toString().contains('overflowed')) fail(e.toString());
  }
}

void main() {
  group('canSignOffProvider', () {
    test('false only for apprentices', () {
      expect(_containerFor(UserRole.apprentice).read(canSignOffProvider),
          isFalse);
      for (final r in [
        UserRole.tech,
        UserRole.dispatcher,
        UserRole.supervisor,
        UserRole.admin,
      ]) {
        expect(_containerFor(r).read(canSignOffProvider), isTrue,
            reason: r.name);
      }
    });
  });

  for (final size in const [Size(360, 800), Size(1280, 800)]) {
    group('${size.width.toInt()}px at 1.3x', () {
      testWidgets('inspection signatures: apprentice sees the message, no pads',
          (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(_host(SectionSignatures(
          model: InspectionEntity.newDraft(),
          onChanged: (_) {},
          canSignOff: false,
        )));
        expect(find.text(_msg), findsOneWidget);
        expect(find.byType(Signature), findsNothing);
        expect(find.text('Save Signatures'), findsNothing);
        _noOverflow(t);
      });

      testWidgets('inspection signatures: a technician still gets the pads',
          (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(_host(SectionSignatures(
          model: InspectionEntity.newDraft(),
          onChanged: (_) {},
        )));
        expect(find.text(_msg), findsNothing);
        expect(find.byType(Signature), findsNWidgets(2));
      });

      testWidgets(
          'maintenance signatures: apprentice has no technician pad and cannot mark the job completed',
          (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        final record = MaintenanceRecord(id: 'm1');
        await t.pumpWidget(_host(SectionMaintSignatures(
          model: record,
          onChanged: (_) {},
          canSignOff: false,
        )));
        // The notice replaces the technician card; the job-completed row
        // explains itself with the same sentence.
        expect(find.text(_msg), findsNWidgets(2));
        expect(find.text('Technician Signature'), findsNothing);
        // Only the customer pad remains.
        expect(find.byType(Signature), findsOneWidget);
        final completed = t.widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Job Completed'));
        expect(completed.onChanged, isNull);
        expect(record.completed, isFalse);
        _noOverflow(t);
      });

      testWidgets('maintenance signatures: a technician can mark it completed',
          (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(_host(SectionMaintSignatures(
          model: MaintenanceRecord(id: 'm1'),
          onChanged: (_) {},
        )));
        expect(find.text(_msg), findsNothing);
        expect(find.text('Technician Signature'), findsOneWidget);
        final completed = t.widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Job Completed'));
        expect(completed.onChanged, isNotNull);
        _noOverflow(t);
      });
    });
  }

  testWidgets('SignOffRequiredNotice has no overflow at 1.3x on a phone',
      (t) async {
    t.view.physicalSize = const Size(360, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(const SignOffRequiredNotice()));
    expect(find.text(_msg), findsOneWidget);
    _noOverflow(t);
  });
}
