import 'package:flutter/material.dart';

/// Colours for signature pads and previews.
///
/// A signature is a document artifact: it is exported as a PNG and printed on
/// PDFs, so it is always dark ink on a light "paper" surface whatever the app
/// theme is. These values are deliberately NOT theme-dependent. The paper and
/// ink match what the pads exported before (white background, black pen), so
/// stored bytes do not change.
///
/// Contrast (checked in test/shared/signature_surface_test.dart):
/// ink on paper >= 7:1, [outline] against both the light and dark app
/// surfaces >= 3:1, [hint] on paper >= 4.5:1.
class SignaturePalette {
  const SignaturePalette._();

  /// The light sheet the signature is drawn on.
  static const Color paper = Color(0xFFFFFFFF);

  /// Pen colour and PNG export ink.
  static const Color ink = Color(0xFF000000);

  /// Pad border; mid-grey that stands out on white and on dark surfaces.
  static const Color outline = Color(0xFF7F7F7F);

  /// "Sign here" text and baseline, readable on [paper].
  static const Color hint = Color(0xFF5F6368);
}
