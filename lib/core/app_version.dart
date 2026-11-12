import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// The app's own version, as set in `pubspec.yaml` (`version: 1.2.3+45`) and
/// baked into the build: [name] is `1.2.3` and [build] is `45`.
///
/// Change it with `python -I tool/bump_version.py` (see
/// docs/release_versioning.md), never by editing text in the UI.
class AppVersion {
  const AppVersion({required this.name, required this.build});

  /// `1.2.3`
  final String name;

  /// `45` (empty when unknown)
  final String build;

  /// Shown when the platform cannot tell us (for example in widget tests).
  static const unknown = AppVersion(name: 'unknown', build: '');

  /// `1.2.3 (45)`, or just `1.2.3` without a build number.
  String get full => build.isEmpty ? name : '$name ($build)';

  @override
  bool operator ==(Object other) =>
      other is AppVersion && other.name == name && other.build == build;

  @override
  int get hashCode => Object.hash(name, build);
}

/// Reads the installed version once. Overridable in tests.
final appVersionProvider = FutureProvider<AppVersion>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return AppVersion(name: info.version, build: info.buildNumber);
  } catch (_) {
    return AppVersion.unknown;
  }
});

/// `Version 1.2.3 (45)` as text, from [appVersionProvider]. Shows `Version …`
/// while it loads so the layout does not jump.
class AppVersionText extends ConsumerWidget {
  const AppVersionText({
    super.key,
    this.prefix = '',
    this.withBuild = true,
    this.style,
  });

  final String prefix;
  final bool withBuild;
  final TextStyle? style;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = ref.watch(appVersionProvider).value;
    final text = v == null
        ? '…'
        : (withBuild ? v.full : v.name);
    return Text('$prefix$text', style: style);
  }
}
