import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/services/sync/sync_operation.dart';
import 'package:voltcore/core/services/sync/sync_service.dart';
import 'package:voltcore/shared/presenter/widgets/offline_banner.dart';
import 'package:voltcore/shared/presenter/widgets/sync_centre_sheet.dart';

SyncOperation _op(String id, String table, {bool failed = false}) =>
    SyncOperation(
      id: id,
      type: SyncOpType.upsert,
      entityId: '$table/$id',
      payload: {'table': table, 'row': {}},
      status: failed ? SyncOpStatus.failed : SyncOpStatus.pending,
      lastError: failed ? 'PostgrestException 42501 denied' : null,
    );

void main() {
  testWidgets('sheet lists groups, failures, and wires buttons', (tester) async {
    final status = ValueNotifier(const SyncStatus(
        state: SyncState.idle, pending: 3, failed: 1));
    final calls = <String>[];
    final ops = [
      _op('1', 'parts_catalog'),
      _op('2', 'parts_catalog'),
      _op('3', 'inventory_movements'),
      _op('4', 'asset_parts', failed: true),
    ];
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showSyncCentre(
              context,
              status: status,
              loadQueue: () async => ops,
              actions: SyncCentreActions(
                syncNow: () async => calls.add('sync'),
                retryAll: () async => calls.add('all'),
                retryOne: (id) async => calls.add('one:$id'),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Parts'), findsOneWidget);
    expect(find.text('Stock movements'), findsOneWidget);
    expect(find.text('Generator parts'), findsOneWidget);
    expect(find.textContaining('42501'), findsOneWidget);

    await tester.tap(find.text('Sync now'));
    await tester.pump();
    await tester.tap(find.text('Retry all'));
    await tester.pump();
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(calls, ['sync', 'all', 'one:4']);
  });

  testWidgets('offline banner only when offline with pending work',
      (tester) async {
    final status = ValueNotifier(const SyncStatus(
        state: SyncState.offline, pending: 2, failed: 0));
    await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: OfflineBanner(status: status))));
    expect(find.text(OfflineBanner.message), findsOneWidget);

    status.value =
        const SyncStatus(state: SyncState.offline, pending: 0, failed: 0);
    await tester.pump();
    expect(find.text(OfflineBanner.message), findsNothing);

    status.value =
        const SyncStatus(state: SyncState.idle, pending: 2, failed: 0);
    await tester.pump();
    expect(find.text(OfflineBanner.message), findsNothing);
  });
}
