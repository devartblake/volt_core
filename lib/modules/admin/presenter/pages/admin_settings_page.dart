import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../shared/widgets/widgets.dart';

class AdminSettingsPage extends StatelessWidget {
  const AdminSettingsPage({super.key});

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — coming soon'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AppPage(
      title: 'Admin Settings',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Admin Configuration',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Use this section for tenant-wide roles, retention policy, and '
            'operational troubleshooting controls.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Enable advanced logging'),
            subtitle: const Text(
              'Collect more detailed logs for troubleshooting.',
            ),
            value: true,
            onChanged: (_) {
              _showComingSoon(context, 'Advanced logging toggle');
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Data retention policy'),
            subtitle: const Text('Configure how long archives are kept.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              _showComingSoon(context, 'Data retention settings');
            },
          ),
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: const Text('Team roles & permissions'),
            subtitle: const Text(
              'Manage tenant-member roles used by authentication and routing.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(RoutePaths.adminTechnicians),
          ),
        ],
      ),
    );
  }
}
