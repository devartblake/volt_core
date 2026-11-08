import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:voltcore/core/app_version.dart';

void main() {
  test('full shows the build number only when there is one', () {
    expect(const AppVersion(name: '0.9.0', build: '12').full, '0.9.0 (12)');
    expect(const AppVersion(name: '0.9.0', build: '').full, '0.9.0');
  });

  test('the provider reads the installed version', () async {
    PackageInfo.setMockInitialValues(
      appName: 'Volt Core',
      packageName: 'com.example.voltcore',
      version: '0.9.0',
      buildNumber: '7',
      buildSignature: '',
    );
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final v = await c.read(appVersionProvider.future);
    expect(v, const AppVersion(name: '0.9.0', build: '7'));
  });

  testWidgets('AppVersionText shows the prefix and the version', (t) async {
    await t.pumpWidget(ProviderScope(
      overrides: [
        appVersionProvider.overrideWith(
            (ref) async => const AppVersion(name: '1.2.3', build: '45')),
      ],
      child: const MaterialApp(
        home: Scaffold(body: AppVersionText(prefix: 'Version ')),
      ),
    ));
    await t.pump();
    await t.pump();
    expect(find.text('Version 1.2.3 (45)'), findsOneWidget);
  });
}
