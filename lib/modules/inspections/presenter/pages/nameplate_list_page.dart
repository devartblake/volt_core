import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../infra/models/inspection.dart';
import '../../infra/repositories/inspection_repo.dart';
import '../../../../core/presenter/responsive_scaffold.dart';
import '../../providers/user_profile_provider.dart';
import '../../providers/app_badges_provider.dart';

/// Page that lists all inspections with quick access to their nameplate infra
class NameplateListPage extends ConsumerWidget {
  const NameplateListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(inspectionRepoProvider).listAll();
    final theme = Theme.of(context);
    final badges = ref.watch(appBadgesProvider);
    final userProfile = ref.watch(userProfileProvider);
    final currentTenant = ref.watch(currentTenantProvider);

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Nameplate Data'),
        leading: Navigator.of(context).canPop()
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        )
            : null,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Nameplate Data'),
                  content: const Text(
                    'View and edit nameplate information and test interval '
                        'infra for each inspection. Tap any inspection to manage '
                        'its nameplate details.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Got it'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: items.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.badge_outlined,
              size: 80,
              color: theme.colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'No inspections yet',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create an inspection to add nameplate infra',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/inspection/new'),
              icon: const Icon(Icons.add),
              label: const Text('Create Inspection'),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        itemBuilder: (_, i) => _NameplateCard(
          inspection: items[i],
          theme: theme,
        ),
      ),
      badges: badges.toRouteMap(),
      userProfile: userProfile,
      onSwitchTenant: (tenant) {
        ref.read(currentTenantProvider.notifier).switchTenant(tenant);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Switched to $tenant')),
        );
      },
    );
  }
}

class _NameplateCard extends StatelessWidget {
  final Inspection inspection;
  final ThemeData theme;

  const _NameplateCard({
    required this.inspection,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = inspection.serviceDate.toIso8601String().split("T").first;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => context.push('/nameplate/${inspection.id}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.badge,
                  color: theme.colorScheme.onPrimaryContainer,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inspection.address.isEmpty
                          ? '(No address)'
                          : inspection.address,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dateStr,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (inspection.siteCode.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            inspection.siteCode,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // Arrow indicator
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Edit Data',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}