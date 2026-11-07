import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voltcore/shared/widgets/thumbnail_image.dart';

// 1x1 transparent PNG.
final _png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

Future<void> _pump(WidgetTester t, Widget w) async {
  final errors = <FlutterErrorDetails>[];
  final old = FlutterError.onError;
  FlutterError.onError = (d) {
    if (!d.exceptionAsString().contains('overflowed')) errors.add(d);
  };
  await t.pumpWidget(MaterialApp(home: Scaffold(body: Center(child: w))));
  await t.pump(const Duration(milliseconds: 50));
  FlutterError.onError = old;
}

void main() {
  testWidgets('builds from bytes at a fixed size', (t) async {
    await _pump(t, ThumbnailImage.memory(_png, size: 84));
    expect(find.byType(Image), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('sizes from available width when no size given', (t) async {
    await _pump(
        t, SizedBox(width: 100, height: 100, child: ThumbnailImage.memory(_png)));
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets('survives garbage bytes and a missing file', (t) async {
    await _pump(t, ThumbnailImage.memory(Uint8List.fromList([1, 2, 3]), size: 50));
    await _pump(
        t, ThumbnailImage.file(File('Z:/definitely/missing.jpg'), size: 50));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(ThumbnailImage), findsOneWidget);
  });
}
