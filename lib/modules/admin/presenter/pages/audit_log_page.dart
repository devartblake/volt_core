import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/app_page.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/lazy_head_list.dart';
import '../../../../shared/widgets/status_chip.dart';
import '../../../inventory/presenter/movement_providers.dart';
import '../../domain/audit_log.dart';
import '../../infra/audit_repository.dart';

StatusTone auditTone(AuditAction a) => switch (a) {
      AuditAction.insert => StatusTone.success,
      AuditAction.update => StatusTone.info,
      AuditAction.delete => StatusTone.danger,
    };

/// Who changed or deleted what, newest first. Admins only; read-only. The log
/// is read from the cloud, never kept on the device.
class AuditLogPage extends ConsumerStatefulWidget {
  const AuditLogPage({super.key, this.now});

  /// For tests; defaults to the current time.
  final DateTime Function()? now;

  @override
  ConsumerState<AuditLogPage> createState() => _AuditLogPageState();
}

class _AuditLogPageState extends ConsumerState<AuditLogPage> {
  final Set<AuditGroup> _groups = {};
  AuditPeriod _period = AuditPeriod.week;
  String _query = '';
  int _limit = kAuditPageSize;
  List<AuditEntry>? _last;

  DateTime _now() => (widget.now ?? DateTime.now)();

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(auditEntriesProvider(_limit));
    final names = ref.watch(memberNamesProvider).value ?? const {};

    return AppPage(
      title: 'Audit log',
      body: entries.when(
        // Keep the list on screen while "Show more" loads.
        loading: () => _last == null
            ? const Center(child: CircularProgressIndicator())
            : _body(context, _last!, names),
        error: (e, _) => e is AuditOfflineException
            ? EmptyState.offline(
                title: 'Connect to view the audit log',
                message: 'The audit log is read from the cloud and is not '
                    'kept on this device.',
                action: TextButton(
                  onPressed: () => ref.invalidate(auditEntriesProvider),
                  child: const Text('Retry'),
                ),
              )
            : EmptyState.error(
                message: 'The audit log could not be loaded.',
                action: TextButton(
                  onPressed: () => ref.invalidate(auditEntriesProvider),
                  child: const Text('Retry'),
                ),
              ),
        data: (all) {
          _last = all;
          return _body(context, all, names);
        },
      ),
    );
  }

  Widget _body(
    BuildContext context,
    List<AuditEntry> all,
    Map<String, String> names,
  ) {
    final shown = filterAudit(
      all,
      groups: _groups,
      period: _period,
      query: _query,
      names: names,
      now: _now(),
    );
    final days = groupAuditByDay(shown);
    // The cloud may hold more than we asked for when a page came back full.
    final mayHaveMore = all.length >= _limit;
    final rows = <Object>[
      for (final d in days) ...[d, ...d.entries],
      if (mayHaveMore) 'more',
    ];

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(auditEntriesProvider),
      child: LazyHeadList(
        padding: const EdgeInsets.all(AppSpacing.lg),
        rowCount: rows.length,
        rowBuilder: (context, i) {
          final r = rows[i];
          if (r is AuditDay) return _DayHeader(day: r.day, count: r.entries.length);
          if (r is String) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Center(
                child: OutlinedButton(
                  key: const Key('audit_show_more'),
                  onPressed: () => setState(() => _limit += kAuditPageSize),
                  child: const Text('Show more'),
                ),
              ),
            );
          }
          final e = r as AuditEntry;
          return _EntryTile(
            entry: e,
            who: auditActorLabel(e.actorUserId, names),
            onTap: () => _showDetail(context, e, names),
          );
        },
        head: [
          TextField(
            key: const Key('audit_search'),
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search the summary',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final p in AuditPeriod.values)
                ChoiceChip(
                  key: Key('audit_period_${p.name}'),
                  label: Text(p.label),
                  selected: _period == p,
                  onSelected: (_) => setState(() => _period = p),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              for (final g in AuditGroup.values)
                FilterChip(
                  key: Key('audit_group_${g.name}'),
                  label: Text(g.label),
                  selected: _groups.contains(g),
                  onSelected: (on) => setState(() {
                    on ? _groups.add(g) : _groups.remove(g);
                  }),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (days.isEmpty)
            EmptyState(
              icon: Icons.history,
              title: all.isEmpty ? 'Nothing recorded yet' : 'Nothing matches',
              message: all.isEmpty
                  ? 'Deletions, price and vendor changes, role changes and '
                      'stock adjustments appear here.'
                  : 'Try a longer period or clear the filters.',
              compact: true,
            ),
        ],
      ),
    );
  }

  void _showDetail(
      BuildContext context, AuditEntry e, Map<String, String> names) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AuditDetailSheet(
        entry: e,
        who: auditActorLabel(e.actorUserId, names),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.day, required this.count});

  final DateTime day;
  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      child: Text(
        '${DateFormat.yMMMEd().format(day)}  ·  $count',
        style: theme.textTheme.titleSmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({
    required this.entry,
    required this.who,
    required this.onTap,
  });

  final AuditEntry entry;
  final String who;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.cardAll,
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        key: Key('audit_${entry.id}'),
        borderRadius: AppRadius.cardAll,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  StatusChip(
                      label: entry.action.label, tone: auditTone(entry.action)),
                  Text(auditTableLabel(entry.tableName),
                      style: theme.textTheme.labelLarge),
                  Text(DateFormat.jm().format(entry.changedAt), style: muted),
                  Text(who, style: muted),
                ],
              ),
              if (entry.summary.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(entry.summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The changed fields of one entry, old to new.
class AuditDetailSheet extends StatelessWidget {
  const AuditDetailSheet({super.key, required this.entry, required this.who});

  final AuditEntry entry;
  final String who;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final changes = auditFieldChanges(entry);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.lg),
          shrinkWrap: true,
          children: [
            Text(
                '${entry.action.label} · ${auditTableLabel(entry.tableName)}',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '$who · ${DateFormat.yMMMd().add_jm().format(entry.changedAt)}',
              style: muted,
            ),
            if (entry.summary.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(entry.summary),
            ],
            const Divider(height: AppSpacing.xl),
            if (changes.isEmpty)
              Text('No field details were recorded.', style: muted)
            else
              for (final c in changes)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.field, style: theme.textTheme.labelLarge),
                      Text(
                        entry.action == AuditAction.update
                            ? '${c.before ?? '(none)'}  →  ${c.after ?? '(none)'}'
                            : (c.after ?? c.before ?? '(none)'),
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
