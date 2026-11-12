import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signature/signature.dart';
import 'package:voltcore/core/theme/app_theme.dart';
import 'package:voltcore/core/theme/signature_palette.dart';
import 'package:voltcore/modules/inspections/domain/entities/inspection_entity.dart';
import 'package:voltcore/modules/inspections/presenter/widgets/section_signatures.dart';
import 'package:voltcore/shared/widgets/signature_surface.dart';

double _lum(Color c) => c.computeLuminance();
double contrast(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

const _sizes = <String, Size>{
  'phone 360x800': Size(360, 800),
  'tablet portrait 800x1280': Size(800, 1280),
  'tablet landscape 1280x800': Size(1280, 800),
};

final _themes = <String, ThemeData>{
  'light': AppTheme.lightTheme,
  'dark': AppTheme.darkTheme,
};

/// Valid 1x1 PNG (a saved signature stand-in).
final Uint8List _tinyPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x60, 0x60, 0x60, 0x60,
  0x00, 0x00, 0x00, 0x05, 0x00, 0x01, 0x5A, 0x2D, 0x1E, 0xA4, 0x00, 0x00,
  0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Widget _host(ThemeData theme, Widget body, {double textScale = 1}) {
  return MaterialApp(
    theme: theme,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(textScale),
      ),
      child: child!,
    ),
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: body,
      ),
    ),
  );
}

Widget _padAndPreview(SignatureController c, {Uint8List? saved}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Technician Signature'),
        SignaturePaper(
          key: const Key('pad'),
          hint: 'Sign here',
          semanticLabel: 'pad',
          child: Signature(
            controller: c,
            backgroundColor: Colors.transparent,
          ),
        ),
        const SizedBox(height: 12),
        SignatureImagePreview(key: const Key('saved'), bytes: saved),
        const SizedBox(height: 12),
        const SignatureImagePreview(key: Key('none'), bytes: null),
      ],
    );

Color? _paperColor(WidgetTester t, Finder within) {
  final deco = t
      .widgetList<DecoratedBox>(
        find.descendant(of: within, matching: find.byType(DecoratedBox)),
      )
      .map((d) => d.decoration)
      .whereType<BoxDecoration>()
      .firstWhere((d) => d.border != null);
  return deco.color;
}

Size _paperSize(WidgetTester t, Finder within) {
  final box = find
      .descendant(of: within, matching: find.byType(DecoratedBox))
      .evaluate()
      .map((e) => e.widget as DecoratedBox)
      .toList();
  final withBorder = find
      .descendant(of: within, matching: find.byType(DecoratedBox))
      .evaluate()
      .firstWhere((e) {
    final d = (e.widget as DecoratedBox).decoration;
    return d is BoxDecoration && d.border != null;
  });
  expect(box, isNotEmpty);
  return (withBorder.renderObject! as RenderBox).size;
}

void main() {
  group('contrast', () {
    test('ink on paper >= 7:1', () {
      expect(contrast(SignaturePalette.ink, SignaturePalette.paper),
          greaterThanOrEqualTo(7));
    });

    for (final e in _themes.entries) {
      test('${e.key}: pad outline vs surface >= 3:1', () {
        final s = e.value.colorScheme;
        for (final surface in {
          'surface': s.surface,
          'surfaceContainerHighest': s.surfaceContainerHighest,
          'scaffold': e.value.scaffoldBackgroundColor,
        }.entries) {
          expect(contrast(SignaturePalette.outline, surface.value),
              greaterThanOrEqualTo(3),
              reason: '${e.key} ${surface.key}');
        }
      });
    }

    test('outline vs the paper itself >= 3:1', () {
      expect(contrast(SignaturePalette.outline, SignaturePalette.paper),
          greaterThanOrEqualTo(3));
    });

    test('hint text and baseline vs paper >= 4.5:1', () {
      expect(contrast(SignaturePalette.hint, SignaturePalette.paper),
          greaterThanOrEqualTo(4.5));
    });

    test('paper is light and ink is dark', () {
      expect(SignaturePalette.paper.computeLuminance(), greaterThan(0.8));
      expect(SignaturePalette.ink.computeLuminance(), lessThan(0.05));
    });
  });

  group('layout', () {
    for (final size in _sizes.entries) {
      for (final theme in _themes.entries) {
        for (final scale in [1.0, 1.3]) {
          testWidgets(
              '${theme.key} ${size.key} x$scale: no overflow, light paper, usable size',
              (tester) async {
            tester.view.physicalSize = size.value;
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);

            final overflows = <String>[];
            final prev = FlutterError.onError;
            FlutterError.onError = (d) {
              if (d.toString().contains('overflowed')) {
                overflows.add(d.exceptionAsString());
              } else {
                prev?.call(d);
              }
            };
            addTearDown(() => FlutterError.onError = prev);

            final c = SignatureController();
            addTearDown(c.dispose);
            await tester.pumpWidget(_host(
              theme.value,
              _padAndPreview(c, saved: _tinyPng),
              textScale: scale,
            ));
            await tester.pump();

            expect(overflows, isEmpty);
            expect(tester.takeException(), isNull);

            for (final k in ['pad', 'saved', 'none']) {
              expect(_paperColor(tester, find.byKey(Key(k))),
                  SignaturePalette.paper,
                  reason: k);
            }

            final pad = _paperSize(tester, find.byKey(const Key('pad')));
            expect(pad.height, greaterThanOrEqualTo(120));
            expect(pad.height, lessThanOrEqualTo(240));
            final avail = size.value.width - 32;
            expect(pad.width, closeTo(avail < 560 ? avail : 560, 0.01),
                reason: 'fills width up to 560');
            final sig = tester.getSize(find.byType(Signature));
            expect(sig.height, greaterThanOrEqualTo(120));
            expect(sig.width, greaterThan(pad.width - 8));
          });
        }
      }
    }

    testWidgets('"Not signed" label is readable on the paper in dark mode',
        (tester) async {
      await tester.pumpWidget(_host(
          AppTheme.darkTheme, const SignatureImagePreview(bytes: null)));
      final text = tester.widget<Text>(find.text('Not signed'));
      expect(contrast(text.style!.color!, SignaturePalette.paper),
          greaterThanOrEqualTo(4.5));
    });

    testWidgets('corrupt bytes fall back to a label, no throw', (tester) async {
      await tester.pumpWidget(_host(AppTheme.darkTheme,
          SignatureImagePreview(bytes: Uint8List.fromList([1, 2, 3]))));
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Signature unavailable'), findsOneWidget);
    });

    for (final theme in _themes.entries) {
      testWidgets('${theme.key}: rotating phone <-> tablet is safe',
          (tester) async {
        addTearDown(tester.view.reset);
        tester.view.devicePixelRatio = 1;
        final c = SignatureController();
        addTearDown(c.dispose);
        tester.view.physicalSize = const Size(360, 800);
        await tester.pumpWidget(_host(theme.value, _padAndPreview(c)));
        final portrait = _paperSize(tester, find.byKey(const Key('pad')));
        tester.view.physicalSize = const Size(800, 360);
        await tester.pump();
        expect(tester.takeException(), isNull);
        final landscape = _paperSize(tester, find.byKey(const Key('pad')));
        expect(landscape.width, greaterThan(portrait.width));
        expect(landscape.height, greaterThanOrEqualTo(120));
        tester.view.physicalSize = const Size(1280, 800);
        await tester.pump();
        tester.view.physicalSize = const Size(360, 800);
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }

    for (final size in _sizes.entries) {
      for (final theme in _themes.entries) {
        testWidgets(
            'inspection SectionSignatures ${theme.key} ${size.key}: no overflow',
            (tester) async {
          tester.view.physicalSize = size.value;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(MaterialApp(
            theme: theme.value,
            home: Scaffold(
              body: SingleChildScrollView(
                child: SectionSignatures(
                  model: InspectionEntity.newDraft(),
                  onChanged: (_) {},
                ),
              ),
            ),
          ));
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(find.byType(SignaturePaper), findsNWidgets(2));
          expect(find.text('Sign here'), findsNWidgets(2));
          expect(
              _paperSize(tester, find.byType(SignaturePaper).first).height,
              greaterThanOrEqualTo(120));
        });
      }
    }
  });

  group('export', () {
    Future<(Uint8List, int, int, List<Color>)> drawAndExport(
      WidgetTester tester,
      ThemeData theme,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      // Same settings the app uses for the maintenance / vehicle pads.
      final c = SignatureController(
        penStrokeWidth: 4,
        penColor: SignaturePalette.ink,
        exportBackgroundColor: SignaturePalette.paper,
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(theme, _padAndPreview(c)));
      final box = tester.getRect(find.byType(Signature));
      final g = await tester.startGesture(box.center - const Offset(80, 0));
      for (var i = 1; i <= 16; i++) {
        await g.moveTo(
            box.center + Offset(-80 + i * 10.0, (i.isEven ? 12 : -12)));
      }
      await g.up();
      await tester.pump();
      expect(c.isNotEmpty, isTrue);

      late Uint8List png;
      late List<Color> px;
      late int w, h;
      await tester.runAsync(() async {
        png = (await c.toPngBytes())!;
        final codec = await ui.instantiateImageCodec(png);
        final img = (await codec.getNextFrame()).image;
        w = img.width;
        h = img.height;
        final data = (await img.toByteData())!;
        px = [
          for (var i = 0; i < w * h; i++)
            Color.fromARGB(
              data.getUint8(i * 4 + 3),
              data.getUint8(i * 4),
              data.getUint8(i * 4 + 1),
              data.getUint8(i * 4 + 2),
            )
        ];
      });
      return (png, w, h, px);
    }

    testWidgets(
        'exported PNG is dark ink on light paper, identical in both themes',
        (tester) async {
      final light = await drawAndExport(tester, AppTheme.lightTheme);
      final dark = await drawAndExport(tester, AppTheme.darkTheme);

      for (final r in [light, dark]) {
        final px = r.$4;
        expect(px, isNotEmpty);
        final inkPx = px.where((p) => p.a > 0.9 && p.computeLuminance() < 0.1);
        final paperPx =
            px.where((p) => p.a > 0.9 && p.computeLuminance() > 0.9);
        expect(inkPx.length, greaterThan(20), reason: 'strokes are dark');
        expect(paperPx.length, greaterThan(inkPx.length ~/ 2),
            reason: 'background is light');
        expect(px.first.computeLuminance(), greaterThan(0.9));
        expect(px.first.a, greaterThan(0.99));
      }
      expect(light.$2, dark.$2);
      expect(light.$3, dark.$3);
      expect(light.$1, dark.$1, reason: 'bytes do not depend on app theme');
    });

    testWidgets('pad without export background (inspection) stays transparent',
        (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = SignatureController(
        penStrokeWidth: 2,
        penColor: SignaturePalette.ink,
      );
      addTearDown(c.dispose);
      await tester.pumpWidget(_host(AppTheme.darkTheme, _padAndPreview(c)));
      final box = tester.getRect(find.byType(Signature));
      final g = await tester.startGesture(box.center);
      await g.moveBy(const Offset(60, 20));
      await g.moveBy(const Offset(40, -20));
      await g.up();
      await tester.pump();
      var opaque = 0, transparent = 0, lightVisible = 0;
      await tester.runAsync(() async {
        final png = (await c.toPngBytes())!;
        final img =
            (await (await ui.instantiateImageCodec(png)).getNextFrame()).image;
        final d = (await img.toByteData())!;
        for (var i = 0; i < img.width * img.height; i++) {
          if (d.getUint8(i * 4 + 3) == 0) {
            transparent++;
          } else {
            opaque++;
            if (d.getUint8(i * 4) > 40) lightVisible++;
          }
        }
      });
      expect(opaque, greaterThan(0));
      expect(transparent, greaterThan(0));
      expect(lightVisible, 0, reason: 'only black ink is ever visible');
    });
  });
}
