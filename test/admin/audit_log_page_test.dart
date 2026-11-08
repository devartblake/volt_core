import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/modules/admin/domain/audit_log.dart';
import 'package:voltcore/modules/admin/infra/audit_repository.dart';
import 'package:voltcore/modules/admin/presenter/pages/audit_log_page.dart';
import 'package:voltcore/modules/inventory/presenter/movement_providers.dart';

class _FakeRepo implements AuditRepository {
  _FakeRepo(this.rows, {this.offline = false});
  final List<AuditEntry> rows;
  final bool offline;
  final limits = <int>[];

  @override
  Future<List<AuditEntry>> latest(int limit) async {
    limits.add(limit);
    if (offline) throw const AuditOfflineException();
    return rows.take(limit).toList();
  }
}

final _now = DateTime(2026, 6, 15, 12);

final _rows = [
  AuditEntry(
    id: 3,
    tableName: 'inspections',
    action: AuditAction.delete,
    changedAt: DateTime(2026, 6, 15, 10),
    actorUserId: 'u1',
    summary: 'Deleted inspection ACME-1',
    oldData: const {'site_code': 'ACME-1'},
  ),
  AuditEntry(
    id: 2,
    tableName: 'vendors',
    action: AuditAction.update,
    changedAt: DateTime(2026, 6, 14, 9),
    actorUserId: 'abcdef123',
    summary: 'Updated vendor Grainger',
    oldData: const {'phone': '111'},
    newData: const {'phone': '222'},
  ),
];

Widget _host(_FakeRepo repo, Widget child, {bool dark = false}) =>
    ProviderScope(
      overrides: [
        auditRepositoryProvider.overrideWithValue(repo),
        memberNamesProvider.overrideWith((ref) async => {'u1': 'Dana Tech'}),
      ],
      child: MaterialApp(
        theme: dark ? ThemeData.dark() : ThemeData.light(),
        home: child,
      ),
    );

Widget _scaled(Widget child) => MediaQuery(
      data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
      child: child,
    );

Future<void> _settle(WidgetTester t) async {
  for (var i = 0; i < 4; i++) {
    await t.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  for (final size in [const Size(390, 1800), const Size(1024, 1400)]) {
    for (final dark in [false, true]) {
      testWidgets(
          'lists rows grouped by day at 1.3x on ${size.width.toInt()}px, dark=$dark',
          (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(_host(_FakeRepo(_rows),
            _scaled(AuditLogPage(now: () => _now)),
            dark: dark));
        await _settle(t);

        expect(find.text('Deleted inspection ACME-1'), findsOneWidget);
        expect(find.text('Updated vendor Grainger'), findsOneWidget);
        expect(find.text('Dana Tech'), findsOneWidget);
        expect(find.text('abcdef'), findsOneWidget);
        expect(t.takeException(), isNull); // no overflow
      });
    }
  }

  testWidgets('group chips filter; tapping a row shows old to new', (t) async {
    t.view.physicalSize = const Size(900, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(_FakeRepo(_rows), AuditLogPage(now: () => _now)));
    await _settle(t);

    await t.tap(find.byKey(const Key('audit_group_pricesVendors')));
    await t.pump();
    expect(find.text('Deleted inspection ACME-1'), findsNothing);
    expect(find.text('Updated vendor Grainger'), findsOneWidget);

    await t.tap(find.byKey(const Key('audit_2')));
    await _settle(t);
    expect(find.text('111  →  222'), findsOneWidget);
    expect(find.text('Phone'), findsOneWidget);
  });

  testWidgets('shows the offline message', (t) async {
    await t.pumpWidget(_host(
        _FakeRepo(const [], offline: true), AuditLogPage(now: () => _now)));
    await _settle(t);
    expect(find.text('Connect to view the audit log'), findsOneWidget);
  });

  testWidgets('Show more asks for another page', (t) async {
    t.view.physicalSize = const Size(900, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final many = [
      for (var i = 0; i < kAuditPageSize; i++)
        AuditEntry(
          id: 1000 - i,
          tableName: 'vendors',
          action: AuditAction.update,
          changedAt: DateTime(2026, 6, 15, 11),
          summary: 'Updated vendor $i',
        ),
    ];
    final repo = _FakeRepo(many);
    await t.pumpWidget(_host(repo, AuditLogPage(now: () => _now)));
    await _settle(t);
    await t.scrollUntilVisible(find.byKey(const Key('audit_show_more')), 500,
        scrollable: find.byType(Scrollable).first);
    await t.tap(find.byKey(const Key('audit_show_more')));
    await _settle(t);
    expect(repo.limits, [kAuditPageSize, kAuditPageSize * 2]);
  });
}
