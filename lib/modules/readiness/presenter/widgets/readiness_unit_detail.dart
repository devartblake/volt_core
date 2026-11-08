import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/feature_flags.dart';
import '../../../../core/constants/route_paths.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/action_runner.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../../auth/presenter/controllers/auth_controller.dart';
import '../../../inspections/presenter/controllers/inspection_list_controller.dart';
import '../../../materials/presenter/materials_section_card.dart'
    show showGeneratorPartsProfile;
import '../../../work_orders/presenter/inspection_maintenance_scheduler.dart';
import '../../domain/readiness_models.dart';
import '../../domain/readiness_rules.dart' show readinessDate;
import '../../domain/readiness_view.dart';
import '../readiness_providers.dart';
import '../readiness_services.dart';
import 'readiness_charts.dart' show GradeTrendStrip;
import 'readiness_unit_card.dart' show ReadinessFollowUpCard;
import 'readiness_visuals.dart';

/// Everything about one generator: why it has its status, key facts, its
/// inspection history and the actions. Shown in a bottom sheet on phones and
/// as the right-hand pane on wide screens.
class ReadinessUnitDetail extends ConsumerWidget {
  const ReadinessUnitDetail({
    super.key,
    required this.unit,
    required this.now,
    this.onClose,
  });

  /// As last seen; replaced by the live unit with the same key when there is one.
  final ReadinessUnit unit;
  final DateTime now;

  /// Called before navigating away (the sheet pops itself).
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final live = ref.watch(readinessUnitsProvider).value;
    final u = live == null
        ? unit
        : live.firstWhere((x) => x.key == unit.key, orElse: () => unit);
    final role = ref.watch(authStateProvider).currentRole;
    final canSchedule = canScheduleReadiness(role);
    final inputs = ref.watch(readinessInputsProvider).value;
    final history = inputs == null
        ? const <ReadinessInspectionRow>[]
        : [
            for (final i in inspectionHistoryFor(u, inputs.inspections))
              ReadinessInspectionRow(i.id, i.serviceDate, ReadinessGrade.parse(i.grade))
          ];
    final id = u.latestInspectionId;
    final makeModel = [u.make, u.model].where((e) => e.trim().isNotEmpty).join(' ');

    Future<void> go(String route) async {
      final router = GoRouter.of(context);
      onClose?.call();
      router.push(route);
    }

    final actions = <Widget>[
      if (id != null)
        FilledButton.icon(
          onPressed: () => go(RoutePaths.inspectionDetail.replaceFirst(':id', id)),
          icon: const Icon(Icons.assignment_outlined),
          label: const Text('Open latest inspection'),
        ),
      if (id != null && FeatureFlags.equipmentSearchEnabled)
        OutlinedButton.icon(
          onPressed: () => go(RoutePaths.equipmentHistory.replaceFirst(':id', id)),
          icon: const Icon(Icons.history),
          label: const Text('Open full history'),
        ),
      if (u.profileKey.isNotEmpty)
        OutlinedButton.icon(
          onPressed: () => showGeneratorPartsProfile(context,
              make: u.make, model: u.model, serial: u.serial),
          icon: const Icon(Icons.inventory_2_outlined),
          label: const Text('Parts profile'),
        ),
      if (canSchedule)
        OutlinedButton.icon(
          key: const Key('schedule-inspection'),
          onPressed: () => _schedule(context, ref, u),
          icon: const Icon(Icons.event_available_outlined),
          label: const Text('Schedule inspection'),
        ),
      if (canSchedule && id != null)
        OutlinedButton.icon(
          key: const Key('create-maintenance-job'),
          onPressed: () => _maintenanceJob(context, ref, id),
          icon: const Icon(Icons.build_circle_outlined),
          label: const Text('Create maintenance job'),
        ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.huge),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(ReadinessVisuals.statusIcon(u.status),
                  size: 32, color: ReadinessVisuals.statusColor(theme, u.status)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(u.title,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700)),
                    ),
                    if (u.customer.isNotEmpty || u.address.isNotEmpty)
                      Text([u.customer, u.address].where((e) => e.isNotEmpty).join('  ·  '),
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              StatusChip(
                label: u.status.label,
                tone: ReadinessVisuals.statusTone(u.status),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (actions.isNotEmpty)
            Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.sm, children: actions),
          const SizedBox(height: AppSpacing.xl),
          _Title('Why ${u.status.label.toLowerCase()}'),
          if (u.reasons.isEmpty)
            Text('Nothing is outstanding.', style: theme.textTheme.bodyMedium)
          else
            for (final r in u.reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ExcludeSemantics(
                      child: Icon(ReadinessVisuals.reasonIcon(r.kind),
                          size: 20,
                          color: ReadinessVisuals.severityColor(theme, r.severity)),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: Text(r.text, style: theme.textTheme.bodyMedium)),
                  ],
                ),
              ),
          const SizedBox(height: AppSpacing.lg),
          _Title('Key facts'),
          _Fact('Site', [u.siteCode, u.address].where((e) => e.isNotEmpty).join('  ·  ')),
          _Fact('Make / model', makeModel),
          _Fact('Serial', u.serial),
          _Fact('Fuel', u.fuelType),
          _Fact('Last inspection', _date(u.lastInspectionAt)),
          _Fact('Last grade',
              u.lastGrade == ReadinessGrade.none ? '' : '${u.lastGrade.label}${u.lastGradeAt == null ? '' : ' (${readinessDate(u.lastGradeAt!, now)})'}'),
          _Fact('Last load test', _date(u.lastLoadTestAt)),
          _Fact('Next load test (estimated)', _date(u.nextLoadTestDueAt)),
          _Fact('Next inspection due',
              u.nextDueAt == null ? '' : '${readinessDate(u.nextDueAt!, now)}  -  ${readinessDueText(u)}'),
          _Fact('Next scheduled visit', _date(u.scheduledTaskNext)),
          const SizedBox(height: AppSpacing.lg),
          Row(children: [
            Expanded(child: _Title('Inspection history')),
            GradeTrendStrip(grades: [for (final h in history.reversed) h.grade]),
          ]),
          if (history.isEmpty)
            Text('No inspections on record.', style: theme.textTheme.bodyMedium)
          else
            for (final h in history.take(6))
              InkWell(
                onTap: () => go(RoutePaths.inspectionDetail.replaceFirst(':id', h.id)),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(children: [
                    Expanded(child: Text(readinessDate(h.date, now))),
                    h.grade == ReadinessGrade.none
                        ? Text('Ungraded',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant))
                        : GradeChip(grade: h.grade),
                    const Icon(Icons.chevron_right),
                  ]),
                ),
              ),
          if (u.openFollowUps.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _Title('Open follow-ups'),
            for (final f in ReadinessFollowUpCard.newestFirst(u))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  [
                    if (f.date != null) readinessDate(f.date!, now),
                    f.note.isEmpty ? 'Follow-up needed (no note)' : f.note,
                  ].join('  -  '),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
          ],
          if (u.partsShortCount > 0) ...[
            const SizedBox(height: AppSpacing.lg),
            _Title('Parts'),
            Text(
              u.partsShortCount == 1
                  ? '1 part is short for the next job.'
                  : '${u.partsShortCount} parts are short for the next job.',
              style: theme.textTheme.bodyMedium,
            ),
            TextButton.icon(
              onPressed: () => go(RoutePaths.inventoryShortages),
              icon: const Icon(Icons.shopping_cart_outlined),
              label: const Text('Open Shortages'),
            ),
          ],
        ],
      ),
    );
  }

  String _date(DateTime? d) => d == null ? '' : readinessDate(d, now);

  Future<void> _schedule(BuildContext context, WidgetRef ref, ReadinessUnit u) async {
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: u.nextDueAt != null && !u.nextDueAt!.isBefore(today) ? u.nextDueAt! : today,
      firstDate: today,
      lastDate: DateTime(today.year + 5),
      helpText: 'Schedule inspection',
    );
    if (picked == null || !context.mounted) return;
    final scheduler = ref.read(readinessSchedulerProvider);
    await runUserAction(
      context,
      label: 'schedule the inspection',
      successMessage: 'Inspection scheduled for ${readinessDate(picked, now)}',
      action: () async {
        await scheduler.scheduleInspection(u, picked);
        await scheduler.reload();
        ref.invalidate(readinessInputsProvider);
        return true;
      },
    );
  }

  Future<void> _maintenanceJob(BuildContext context, WidgetRef ref, String inspectionId) async {
    final matches = ref
        .read(inspectionListControllerProvider)
        .items
        .where((i) => i.id == inspectionId);
    if (matches.isEmpty) {
      AppSnackBar.info(context, 'Open the inspection first; it is not on this device yet.');
      return;
    }
    onClose?.call();
    await scheduleMaintenanceFromInspection(context, ref, matches.first);
  }
}

/// One line of the history list.
class ReadinessInspectionRow {
  const ReadinessInspectionRow(this.id, this.date, this.grade);
  final String id;
  final DateTime date;
  final ReadinessGrade grade;
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w700)),
      );
}

class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: theme.textTheme.labelMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          Text(value.isEmpty ? '-' : value,
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
