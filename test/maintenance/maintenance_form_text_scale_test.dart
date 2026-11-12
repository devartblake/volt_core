import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/theme/status_colors.dart';
import 'package:voltcore/modules/auth/domain/user_role.dart';
import 'package:voltcore/modules/auth/domain/usecases/login_usecase.dart';
import 'package:voltcore/modules/auth/domain/usecases/logout_usecase.dart';
import 'package:voltcore/modules/auth/presenter/controllers/auth_controller.dart';
import 'package:voltcore/modules/auth/state/auth_state.dart';
import 'package:voltcore/modules/inventory/domain/stock.dart';
import 'package:voltcore/modules/inventory/infra/inventory_repository.dart';
import 'package:voltcore/modules/materials/presenter/job_context_providers.dart';
import 'package:voltcore/modules/maintenance/infra/models/maintenance_record.dart';
import 'package:voltcore/modules/maintenance/infra/repositories/maintenance_hive_repository.dart';
import 'package:voltcore/modules/maintenance/presenter/controllers/maintenance_providers.dart';
import 'package:voltcore/modules/maintenance/presenter/pages/maintenance_form_page.dart';
import 'package:voltcore/modules/materials/domain/material_item.dart';
import 'package:voltcore/modules/materials/infra/materials_repository.dart';

class _MemRepo extends MaintenanceRepo {
  final Map<String, MaintenanceRecord> records = {};

  @override
  MaintenanceRecord createNew({String? inspectionId}) {
    final m = MaintenanceRecord(id: 'new-${records.length}');
    records[m.id] = m;
    return m;
  }

  @override
  MaintenanceRecord? getById(String id) => records[id];

  @override
  Future<void> saveDraft(MaintenanceRecord rec) async {}

  @override
  Future<void> save(MaintenanceRecord rec) async {}

  @override
  Future<void> delete(String id) async => records.remove(id);
}

class _FakeLogin extends Fake implements LoginUseCase {}

class _FakeLogout extends Fake implements LogoutUseCase {}

class _NoMaterials extends MaterialsRepository {
  @override
  Future<List<MaterialItem>> load(MaterialOwner owner) async => const [];
}

void main() {
  // The Signatures step's photo strip opens a Hive box. With Hive pointed at a
  // temp dir the open just never completes on the fake clock, instead of
  // throwing "initialize Hive" after the test has finished.
  setUpAll(() => Hive.init(
      Directory.systemTemp.createTempSync('voltcore_form_scale').path));

  const sizes = {
    'phone': Size(360, 800),
    'tablet portrait': Size(800, 1280),
    'tablet landscape': Size(1280, 800),
  };
  // Number of Next taps to reach each step.
  const steps = {'Site Information': 0, 'Parts & Materials': 5, 'Signatures': 7};

  for (final size in sizes.entries) {
    for (final step in steps.entries) {
      testWidgets('${step.key} has no overflow at 1.3x on ${size.key}',
          (tester) async {
        tester.view.physicalSize = size.value;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        final errors = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (d) {
          if (d.toString().contains('overflowed')) {
            errors.add(d.toString());
          } else {
            previous?.call(d); // recorded by the framework; drained below
          }
        };
        addTearDown(() => FlutterError.onError = previous);

        await tester.pumpWidget(ProviderScope(
          overrides: [
            maintenanceRepoProvider.overrideWithValue(_MemRepo()),
            maintenancePhotoCountProvider.overrideWith((ref, id) async => 0),
            maintenanceMaterialCountProvider
                .overrideWith((ref, id) async => 0),
            // The Parts step reads the role and stock; the real ones hit Hive.
            authStateProvider.overrideWith((ref) {
              final c = AuthController(ref, _FakeLogin(), _FakeLogout());
              c.state = const AuthState(
                isAuthenticated: true,
                currentRole: UserRole.tech,
                userId: 't1',
                displayName: 'Tess Tech',
              );
              return c;
            }),
            stockLevelsProvider.overrideWith((ref) async => const <StockLevel>[]),
            jobPartsListsProvider.overrideWith((ref) async => const []),
            materialItemsProvider.overrideWith((ref, owner) async => []),
            materialsRepositoryProvider.overrideWithValue(_NoMaterials()),
          ],
          child: MaterialApp(
            theme: ThemeData(extensions: const [StatusColors.light]),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(1.3)),
              child: child!,
            ),
            home: const MaintenanceFormPage(),
          ),
        ));
        Future<void> settle() async {
          for (var i = 0; i < 6; i++) {
            await tester.pump(const Duration(milliseconds: 150));
          }
        }

        await settle();
        for (var i = 0; i < step.value; i++) {
          await tester.tap(find.text('Next'));
          await settle();
        }

        // The Signatures step's photo strip reads the Hive-backed photo store,
        // which fails asynchronously here; that is not what this test checks.
        while (tester.takeException() != null) {}
        final overflows = errors.where((e) => e.contains('overflowed'));
        expect(overflows, isEmpty, reason: overflows.join('\n---\n'));
      });
    }
  }
}
