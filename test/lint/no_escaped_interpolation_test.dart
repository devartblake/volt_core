import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Catches `'\$value'` and `'\${expr}'` in Dart source.
///
/// Both are valid Dart — they mean a literal dollar sign followed by text — so
/// the analyzer says nothing, the app builds, and the screen shows
/// `${check.odometer} mi` where a reading should be. That shipped once already
/// in the vehicle detail page's maintenance history, and the only reason it was
/// found is that somebody happened to read the source.
///
/// It gets written by accident whenever source is generated or edited through a
/// shell heredoc, where `$` has to be escaped for the shell and the escape ends
/// up in the file.
///
/// A literal dollar sign before a digit or a space (`'\$5.00'`, `'\$ per unit'`)
/// is left alone: that is the case the escape actually exists for.
void main() {
  test('no escaped interpolation in lib/ or test/', () {
    // `\$` immediately followed by an identifier start or a brace. Anything
    // else — a price, a lone symbol — is a real literal dollar.
    final suspicious = RegExp(r'\\\$[A-Za-z_{]');

    final offenders = <String>[];

    for (final root in ['lib', 'test']) {
      for (final entity in Directory(root).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        // This file necessarily contains the pattern it looks for.
        if (entity.path.endsWith('no_escaped_interpolation_test.dart')) continue;

        final lines = entity.readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (suspicious.hasMatch(lines[i])) {
            offenders.add('${entity.path}:${i + 1}: ${lines[i].trim()}');
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'These lines escape a string interpolation, so the literal text '
          r'"${...}" is what renders. Drop the backslash:'
          '\n${offenders.join('\n')}',
    );
  });
}
