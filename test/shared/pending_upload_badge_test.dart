import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/core/services/sync/pending_records.dart';
import 'package:voltcore/shared/widgets/pending_upload_badge.dart';

Widget _app(Set<String> keys, {double scale = 1}) => ProviderScope(
      overrides: [
        pendingRecordKeysProvider.overrideWith((ref) async => keys),
      ],
      child: MaterialApp(
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const Scaffold(
          body: Row(children: [
            Text('Site A'),
            PendingUploadBadge(table: 'maintenance_records', recordId: 'a'),
            PendingUploadBadge(table: 'maintenance_records', recordId: 'b'),
          ]),
        ),
      ),
    );

void main() {
  testWidgets('shows only for records that are queued', (tester) async {
    await tester.pumpWidget(_app({'maintenance_records/a'}));
    await tester.pump();
    await tester.pump();

    expect(find.byIcon(Icons.cloud_upload_outlined), findsOneWidget);
    expect(find.byTooltip('Not uploaded yet'), findsOneWidget);
    expect(find.bySemanticsLabel('Not uploaded yet'), findsOneWidget);
  });

  testWidgets('renders nothing when nothing is queued', (tester) async {
    await tester.pumpWidget(_app({}));
    await tester.pump();
    await tester.pump();
    expect(find.byIcon(Icons.cloud_upload_outlined), findsNothing);
  });

  testWidgets('fits next to text at 1.3x without overflow', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app({'maintenance_records/a'}, scale: 1.3));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
