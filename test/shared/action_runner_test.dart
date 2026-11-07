import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/shared/widgets/action_runner.dart';

void main() {
  late BuildContext ctx;
  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (c) {
        ctx = c;
        return const SizedBox();
      })),
    ));
  }

  testWidgets('failure shows a plain error snackbar and nothing escapes',
      (tester) async {
    await pump(tester);
    late bool result;
    result = await runUserAction(ctx,
        label: 'export the report',
        action: () async => throw StateError('secret internals'));
    await tester.pump();
    expect(result, isFalse);
    expect(find.text('Could not export the report. Please try again.'),
        findsOneWidget);
    expect(find.textContaining('secret internals'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('success shows the success message', (tester) async {
    await pump(tester);
    final ok = await runUserAction(ctx,
        label: 'save', action: () async => true, successMessage: 'Saved it');
    await tester.pump();
    expect(ok, isTrue);
    expect(find.text('Saved it'), findsOneWidget);
  });

  testWidgets('cancelled (false) is not an error and shows nothing',
      (tester) async {
    await pump(tester);
    final ok = await runUserAction(ctx,
        label: 'save', action: () async => false, successMessage: 'Saved it');
    await tester.pump();
    expect(ok, isFalse);
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('busy message shows while running and is replaced after',
      (tester) async {
    await pump(tester);
    final gate = Completer<bool>();
    final f = runUserAction(ctx,
        label: 'email',
        busyMessage: 'Sending…',
        successMessage: 'Sent',
        action: () => gate.future);
    await tester.pump();
    expect(find.text('Sending…'), findsOneWidget);
    gate.complete(true);
    await f;
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Sent'), findsOneWidget);
  });
}
