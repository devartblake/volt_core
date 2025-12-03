import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/presenter/responsive_scaffold.dart';
import '../../../inspections/providers/user_profile_provider.dart';
import '../../../inspections/providers/app_badges_provider.dart';

/// About page showing app information and credits
class AboutPage extends ConsumerWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final badges = ref.watch(appBadgesProvider);
    final userProfile = ref.watch(userProfileProvider);

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App Logo and Name
          Center(
            child: Column(
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(
                    Icons.bolt,
                    size: 64,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Voltcore',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Generator Inspection System',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Version 1.0.0',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Description Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About Voltcore',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Voltcore is a comprehensive generator inspection and maintenance '
                        'tracking system. It helps technicians efficiently document '
                        'inspections, record nameplate infra, track test intervals, and '
                        'maintain detailed records of generator performance.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Features Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Key Features',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _FeatureItem(
                    icon: Icons.description_outlined,
                    title: 'Inspection Management',
                    description: 'Create and manage detailed generator inspections',
                    theme: theme,
                  ),
                  const SizedBox(height: 12),
                  _FeatureItem(
                    icon: Icons.badge_outlined,
                    title: 'Nameplate Data',
                    description: 'Record comprehensive generator specifications',
                    theme: theme,
                  ),
                  const SizedBox(height: 12),
                  _FeatureItem(
                    icon: Icons.timeline,
                    title: 'Test Intervals',
                    description: 'Track performance metrics over time',
                    theme: theme,
                  ),
                  const SizedBox(height: 12),
                  _FeatureItem(
                    icon: Icons.devices,
                    title: 'Cross-Platform',
                    description: 'Works on mobile, tablet, and desktop',
                    theme: theme,
                  ),
                  const SizedBox(height: 12),
                  _FeatureItem(
                    icon: Icons.cloud_outlined,
                    title: 'Data Sync',
                    description: 'Keep your infra synced across devices',
                    theme: theme,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Links Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(
                    Icons.language,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text('Website'),
                  subtitle: const Text('www.voltcore.app'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Opening website...'),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.support_agent,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text('Support'),
                  subtitle: const Text('support@voltcore.app'),
                  trailing: const Icon(Icons.email_outlined),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Opening email...'),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.policy_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Opening privacy policy...'),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(
                    Icons.article_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Opening terms of service...'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Credits Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Credits',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Built with Flutter and Material Design 3',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '© 2024 Voltcore. All rights reserved.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // System Info Card (Developer)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 1,
              ),
            ),
            child: ExpansionTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('System Information'),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _InfoRow('App Version', '1.0.0'),
                      _InfoRow('Build Number', '1'),
                      _InfoRow('Flutter Version', '3.x'),
                      _InfoRow('Platform', 'Multi-platform'),
                      _InfoRow('Last Updated', '2024'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
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

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final ThemeData theme;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}