import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/presenter/controllers/auth_controller.dart';
import '../../domain/readiness_models.dart';
import '../../domain/readiness_rules.dart';
import '../readiness_providers.dart';

/// Admin-only: how many days count as "due soon" and how far overdue is "not
/// ready", with a live count of what the change would do.
Future<void> showReadinessSettingsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 640),
    builder: (_) => const ReadinessSettingsSheet(),
  );
}

class ReadinessSettingsSheet extends ConsumerStatefulWidget {
  const ReadinessSettingsSheet({super.key});

  @override
  ConsumerState<ReadinessSettingsSheet> createState() => _SettingsState();
}

class _SettingsState extends ConsumerState<ReadinessSettingsSheet> {
  late ReadinessConfig _draft = ref.read(readinessConfigProvider);
  bool _saving = false;

  Future<void> _save() async {
    final role = ref.read(authStateProvider).currentRole;
    setState(() => _saving = true);
    final ok = await ref
        .read(readinessConfigProvider.notifier)
        .update(_draft, role: role);
    if (!mounted) return;
    Navigator.of(context).pop();
    if (ok) {
      AppSnackBar.success(context, 'Readiness thresholds saved');
    } else {
      AppSnackBar.error(context, 'Only an admin can change the thresholds');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final saved = ref.watch(readinessConfigProvider);
    final inputs = ref.watch(readinessInputsProvider).value;
    final now = ref.read(readinessClockProvider)();

    int dueSoon = 0, notReady = 0;
    if (inputs != null) {
      final r = computeReadiness(inputs, _draft, now);
      for (final u in r.units) {
        if (u.status == ReadinessStatus.dueSoon) dueSoon++;
        if (u.status == ReadinessStatus.notReady) notReady++;
      }
    }

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg,
          AppSpacing.lg + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Readiness settings',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: AppSpacing.lg),
          _Setting(
            keyPrefix: 'due-soon',
            title: 'Due soon window',
            help: 'A generator whose next inspection is due within this many '
                'days shows as Due soon.',
            value: _draft.dueSoonDays,
            max: 120,
            onChanged: (v) => setState(() => _draft = _draft.copyWith(dueSoonDays: v)),
            preview: inputs == null
                ? null
                : 'At ${_draft.dueSoonDays} days, $dueSoon '
                    '${dueSoon == 1 ? 'unit would be' : 'units would be'} Due soon',
          ),
          const SizedBox(height: AppSpacing.lg),
          _Setting(
            keyPrefix: 'critical',
            title: 'Not ready when overdue by more than',
            help: 'Overdue by up to this many days needs attention. Past it, '
                'the generator is Not ready.',
            value: _draft.criticalOverdueDays,
            max: 180,
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(criticalOverdueDays: v)),
            preview: inputs == null
                ? null
                : 'At ${_draft.criticalOverdueDays} days, $notReady '
                    '${notReady == 1 ? 'unit would be' : 'units would be'} Not ready',
          ),
          const SizedBox(height: AppSpacing.xl),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: AppSpacing.xs,
            children: [
              TextButton(
                onPressed: () => setState(() => _draft = const ReadinessConfig()),
                child: const Text('Reset to defaults'),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton(
                    key: const Key('settings-save'),
                    onPressed: _saving || _draft == saved ? null : _save,
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Setting extends StatelessWidget {
  const _Setting({
    required this.keyPrefix,
    required this.title,
    required this.help,
    required this.value,
    required this.max,
    required this.onChanged,
    required this.preview,
  });

  final String keyPrefix;
  final String title;
  final String help;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;
  final String? preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
            ),
            IconButton(
              key: Key('$keyPrefix-minus'),
              tooltip: 'One day fewer',
              onPressed: value > 0 ? () => onChanged(value - 1) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('$value days',
                key: Key('$keyPrefix-value'), style: theme.textTheme.titleSmall),
            IconButton(
              key: Key('$keyPrefix-plus'),
              tooltip: 'One day more',
              onPressed: value < max ? () => onChanged(value + 1) : null,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        Slider(
          value: value.clamp(0, max).toDouble(),
          min: 0,
          max: max.toDouble(),
          divisions: max,
          semanticFormatterCallback: (v) => '${v.round()} days',
          onChanged: (v) => onChanged(v.round()),
        ),
        Text(help,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        if (preview != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(preview!,
                key: Key('$keyPrefix-preview'),
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }
}
