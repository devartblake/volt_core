import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/nav_config.dart';
import '../../../app/route_roles.dart';
import '../../../core/constants/feature_flags.dart';
import '../../../core/constants/route_paths.dart';
import '../../../providers/equipment_providers.dart';
import '../../schedule/presenter/controllers/schedule_controller.dart';
import '../../auth/presenter/controllers/auth_controller.dart';
import '../../customers/customer_site_repository.dart';
import '../../inventory/infra/inventory_repository.dart';
import '../../fleet/presenter/fleet_providers.dart';
import '../../inspections/presenter/controllers/inspection_list_controller.dart';
import '../../maintenance/presenter/controllers/maintenance_providers.dart';
import '../../work_orders/presenter/work_order_providers.dart';
import '../domain/search_index.dart';
import 'recent_searches_provider.dart';

String _clip(String s, [int max = 60]) =>
    s.length <= max ? s : '${s.substring(0, max - 1)}…';

String _dateLabel(DateTime d) {
  final l = d.toLocal();
  return '${l.month}/${l.day}/${l.year}';
}

/// Everything the signed-in role can search: the menu pages plus the records
/// on this device (inspections, maintenance, jobs, vehicles, customers).
///
/// Each source is best-effort and role-gated with the same [RouteRoles] rules
/// as the menu: a source that fails to load, or that the role may not open, is
/// left out rather than breaking the search.
final searchIndexProvider = FutureProvider.autoDispose<List<SearchEntry>>(
  (ref) async {
    final role = ref.watch(authStateProvider).currentRole;
    if (role == null) return const [];

    bool can(String routeName) =>
        RouteRoles.isAllowedByName(name: routeName, role: role);

    final entries = <SearchEntry>[];

    // Pages: one entry per menu page the role can open.
    for (final section in navSectionsForRole(role)) {
      for (final item in section.items) {
        entries.add(SearchEntry(
          kind: SearchKind.page,
          title: item.label,
          subtitle: item.description ?? section.title ?? '',
          keywords: section.title ?? '',
          route: item.route,
          icon: item.icon,
          isPage: true,
        ));
      }
    }

    Future<void> source(Future<void> Function() load) async {
      try {
        await load();
      } catch (_) {
        // Searching what did load is better than failing outright.
      }
    }

    if (can(RouteNames.inspections)) {
      await source(() async {
        final state = ref.read(inspectionListControllerProvider);
        for (final i in state.items) {
          final place = i.address.trim().isEmpty ? i.siteCode : i.address;
          entries.add(SearchEntry(
            kind: SearchKind.inspection,
            title: _clip(place.isEmpty ? 'Inspection' : place),
            subtitle: [
              _dateLabel(i.serviceDate),
              if (i.siteCode.isNotEmpty) i.siteCode,
              if (i.siteGrade.isNotEmpty) i.siteGrade,
            ].join('  ·  '),
            keywords:
                '${i.siteCode} ${i.technicianName} ${i.generatorSerial} ${i.city}',
            route: RoutePaths.inspectionDetail.replaceFirst(':id', i.id),
          ));
        }
      });
    }

    if (can(RouteNames.maintenance)) {
      await source(() async {
        for (final m in ref.read(maintenanceRepoProvider).getAll()) {
          entries.add(SearchEntry(
            kind: SearchKind.maintenance,
            title: _clip(m.address.trim().isEmpty ? m.siteCode : m.address),
            subtitle: [
              if (m.dateOfService != null) _dateLabel(m.dateOfService!),
              if (m.siteCode.isNotEmpty) m.siteCode,
              '${m.generatorMake} ${m.generatorModel}'.trim(),
            ].where((s) => s.isNotEmpty).join('  ·  '),
            keywords: '${m.technicianName} ${m.siteCode}',
            route: RoutePaths.maintenanceDetail.replaceFirst(':id', m.id),
          ));
        }
      });
    }

    if (can(RouteNames.workOrders)) {
      await source(() async {
        for (final o in await ref.read(workOrderListProvider.future)) {
          entries.add(SearchEntry(
            kind: SearchKind.job,
            title: _clip(o.title),
            subtitle: o.description.isEmpty ? '' : _clip(o.description, 70),
            route: RoutePaths.workOrderEdit.replaceFirst(':id', o.id),
          ));
        }
      });
    }

    if (can(RouteNames.fleet)) {
      await source(() async {
        for (final v in await ref.read(fleetVisibleVehiclesProvider.future)) {
          entries.add(SearchEntry(
            kind: SearchKind.vehicle,
            title: v.displayTitle,
            subtitle: [v.licensePlate, v.make, v.model]
                .where((s) => s.isNotEmpty)
                .join('  ·  '),
            keywords: '${v.vin ?? ''} ${v.licensePlate}',
            route: RoutePaths.fleetDetail.replaceFirst(':id', v.id),
          ));
        }
      });
    }

    if (can(RouteNames.customerSites)) {
      await source(() async {
        final dir = await ref.read(customerSiteDirectoryProvider.future);
        for (final c in dir.customers) {
          entries.add(SearchEntry(
            kind: SearchKind.customer,
            title: c.name,
            subtitle: [c.contactName, c.contactPhone]
                .where((s) => s.isNotEmpty)
                .join('  ·  '),
            keywords: '${c.legalName} ${c.contactEmail}',
            route: RoutePaths.customerSites,
            icon: Icons.business_outlined,
          ));
        }
        for (final s in dir.sites) {
          entries.add(SearchEntry(
            kind: SearchKind.customer,
            title: _clip(s.address.isEmpty ? s.siteCode : s.address),
            subtitle: [s.siteCode, dir.customerNameFor(s.customerId)]
                .where((x) => x.isNotEmpty)
                .join('  ·  '),
            keywords: s.siteCode,
            route: RoutePaths.customerSites,
            icon: Icons.place_outlined,
          ));
        }
      });
    }

    if (FeatureFlags.equipmentSearchEnabled &&
        can(RouteNames.equipmentHistory)) {
      await source(() async {
        for (final a in await ref.read(equipmentListProvider.future)) {
          entries.add(SearchEntry(
            kind: SearchKind.equipment,
            title: _clip(a.name.trim().isEmpty
                ? '${a.make} ${a.model}'.trim()
                : a.name),
            subtitle: [
              if (a.serialNumber.isNotEmpty) 'S/N ${a.serialNumber}',
              if (a.siteCode.isNotEmpty) a.siteCode,
              if (a.location.isNotEmpty) _clip(a.location, 40),
            ].join('  ·  '),
            keywords: '${a.make} ${a.model} ${a.serialNumber} ${a.siteCode} '
                '${a.location}',
            route: RoutePaths.equipmentHistory.replaceFirst(':id', a.id),
          ));
        }
      });
    }

    if (can(RouteNames.scheduleTaskDetail)) {
      await source(() async {
        final tasks = ref.read(scheduleControllerProvider).value ?? const [];
        for (final t in tasks) {
          final place = t.address.trim().isEmpty ? t.siteCode : t.address;
          entries.add(SearchEntry(
            kind: SearchKind.task,
            title: _clip(t.title.trim().isEmpty ? place : t.title),
            subtitle: [
              _dateLabel(t.scheduledAt),
              if (place.isNotEmpty && place != t.title) _clip(place, 40),
              t.status,
            ].join('  ·  '),
            keywords: '${t.siteCode} ${t.address} ${t.description}',
            route: '${RoutePaths.schedule}/detail/${t.id}',
          ));
        }
      });
    }

    if (can(RouteNames.inventory)) {
      await source(() async {
        final stock = await ref.read(stockLevelsProvider.future);
        for (final l in stock) {
          if (!l.part.isActive) continue;
          final p = l.part;
          entries.add(SearchEntry(
            kind: SearchKind.part,
            title: p.partNumber,
            subtitle: [
              if (p.name.isNotEmpty) p.name,
              if (p.manufacturer.isNotEmpty) p.manufacturer,
              '${l.onHand} on hand',
            ].join('  ·  '),
            keywords: p.altPartNumbers.join(' '),
            route: RoutePaths.inventory,
            icon: Icons.inventory_2_outlined,
          ));
        }
      });
    }

    return entries;
  },
);

/// Opens search as a bottom sheet over the current page, so the page stays in
/// view behind it. On a tablet the sheet is a centred panel, not edge to edge.
/// Wired in by the shell so every page's app bar and the dashboard can reach it.
Future<void> showGlobalSearch(BuildContext context) {
  // Resolve before the sheet opens: the caller's context outlives it, the
  // sheet's does not.
  final router = GoRouter.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 680),
    builder: (_) => GlobalSearchSheet(router: router),
  );
}

/// The search sheet: a field, filter chips for the kinds of result, and the
/// results grouped underneath.
class GlobalSearchSheet extends ConsumerStatefulWidget {
  const GlobalSearchSheet({super.key, required this.router});

  final GoRouter router;

  @override
  ConsumerState<GlobalSearchSheet> createState() => _GlobalSearchSheetState();
}

class _GlobalSearchSheetState extends ConsumerState<GlobalSearchSheet> {
  final _controller = TextEditingController();
  String _query = '';

  /// null = every kind.
  SearchKind? _only;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _open(SearchEntry entry) {
    final router = widget.router;
    ref.read(recentSearchesProvider.notifier).add(_query);
    Navigator.of(context).pop();
    if (entry.isPage) {
      router.go(entry.route);
    } else {
      router.push(entry.route);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final index = ref.watch(searchIndexProvider);
    final height = MediaQuery.sizeOf(context).height;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height: height * 0.85,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                key: const Key('search_field'),
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search pages, jobs, equipment, vehicles, parts',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear',
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _query = '';
                              _only = null;
                            });
                          },
                        ),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Expanded(
              child: index.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) =>
                    const Center(child: Text('Search is unavailable.')),
                data: (entries) {
                  if (_query.trim().isEmpty) {
                    return _Suggestions(
                      pages: entries.where((e) => e.isPage).take(8).toList(),
                      recent: ref.watch(recentSearchesProvider),
                      onTap: _open,
                      onRecent: (q) => setState(() {
                        _controller.text = q;
                        _controller.selection =
                            TextSelection.collapsed(offset: q.length);
                        _query = q;
                      }),
                      onClearRecent: () =>
                          ref.read(recentSearchesProvider.notifier).clear(),
                    );
                  }
                  final all = searchEntries(entries, _query);
                  if (all.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Nothing matches "${_query.trim()}".',
                          style: theme.textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  final byKind = groupByKind(all);
                  // A filter whose results vanished as the text changed.
                  final only = byKind.containsKey(_only) ? _only : null;
                  final groups =
                      only == null ? byKind : {only: byKind[only]!};
                  return Column(
                    children: [
                      SizedBox(
                        height: 48,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text('All (${all.length})'),
                                selected: only == null,
                                onSelected: (_) =>
                                    setState(() => _only = null),
                              ),
                            ),
                            for (final k in byKind.entries)
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  key: Key('filter_${k.key.name}'),
                                  label: Text(
                                      '${k.key.label} (${k.value.length})'),
                                  selected: only == k.key,
                                  onSelected: (_) =>
                                      setState(() => _only = k.key),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.only(bottom: 24),
                          children: [
                            for (final group in groups.entries) ...[
                              if (only == null) _GroupHeader(group.key),
                              for (final e in group.value)
                                ListTile(
                                  leading: CircleAvatar(
                                    radius: 18,
                                    backgroundColor:
                                        scheme.primary.withValues(alpha: 0.10),
                                    foregroundColor: scheme.primary,
                                    child:
                                        Icon(e.icon ?? e.kind.icon, size: 20),
                                  ),
                                  title: Text(e.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                  subtitle: e.subtitle.isEmpty
                                      ? null
                                      : Text(e.subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis),
                                  onTap: () => _open(e),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.kind);

  final SearchKind kind;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: _GroupHeaderText(kind.label),
    );
  }
}

class _GroupHeaderText extends StatelessWidget {
  const _GroupHeaderText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({
    required this.pages,
    required this.recent,
    required this.onTap,
    required this.onRecent,
    required this.onClearRecent,
  });

  final List<SearchEntry> pages;
  final List<String> recent;
  final ValueChanged<SearchEntry> onTap;
  final ValueChanged<String> onRecent;
  final VoidCallback onClearRecent;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        if (recent.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: Row(
              children: [
                const Expanded(child: _GroupHeaderText('Recent searches')),
                TextButton(
                  key: const Key('clear_recent_searches'),
                  onPressed: onClearRecent,
                  child: const Text('Clear'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final q in recent)
                  ActionChip(
                    avatar: const Icon(Icons.history, size: 18),
                    label: Text(q, maxLines: 1, overflow: TextOverflow.ellipsis),
                    onPressed: () => onRecent(q),
                  ),
              ],
            ),
          ),
        ],
        const _GroupHeader(SearchKind.page),
        for (final p in pages)
          ListTile(
            leading: Icon(p.icon ?? p.kind.icon),
            title: Text(p.title),
            subtitle: p.subtitle.isEmpty ? null : Text(p.subtitle),
            onTap: () => onTap(p),
          ),
      ],
    );
  }
}
