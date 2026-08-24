import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_paths.dart';
import '../../../../shared/widgets/widgets.dart';
import '../../infra/services/tenant_retention_policy_service.dart';

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
            leading: const Icon(Icons.history_outlined),
            title: const Text('Data retention policy'),
            subtitle: const Text(
              'Set tenant retention targets for archived maintenance and reports.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showRetentionDialog(context),
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

  Future<void> _showRetentionDialog(BuildContext context) async {
    final service = TenantRetentionPolicyService();
    try {
      final policy = await service.load();
      if (!context.mounted) return;

      var maintenanceDays = policy.archivedMaintenanceDays;
      var reportDays = policy.generatedReportDays;
      var saving = false;

      await showDialog<void>(
        context: context,
        barrierDismissible: !saving,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Data Retention Policy'),
            content: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'These settings record the tenant retention policy. '
                    'Automatic destructive cleanup remains disabled while '
                    'storage-object and compliance-evidence deletion are '
                    'certified together.',
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int?>(
                    initialValue: maintenanceDays,
                    decoration: const InputDecoration(
                      labelText: 'Archived maintenance jobs',
                      border: OutlineInputBorder(),
                    ),
                    items: _retentionChoices(),
                    onChanged: saving
                        ? null
                        : (value) => setState(() => maintenanceDays = value),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    initialValue: reportDays,
                    decoration: const InputDecoration(
                      labelText: 'Generated reports',
                      border: OutlineInputBorder(),
                    ),
                    items: _retentionChoices(),
                    onChanged: saving
                        ? null
                        : (value) => setState(() => reportDays = value),
                  ),
                  const SizedBox(height: 16),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Existing records and files are not deleted when you '
                          'save this policy.',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        setState(() => saving = true);
                        try {
                          await service.save(
                            archivedMaintenanceDays: maintenanceDays,
                            generatedReportDays: reportDays,
                          );
                          if (!dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Retention policy saved.'),
                            ),
                          );
                        } catch (error) {
                          if (!dialogContext.mounted) return;
                          setState(() => saving = false);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Unable to save retention policy: $error',
                              ),
                            ),
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save Policy'),
              ),
            ],
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load retention policy: $error')),
      );
    }
  }

  List<DropdownMenuItem<int?>> _retentionChoices() {
    const choices = <(int?, String)>[
      (null, 'Retain indefinitely'),
      (365, '1 year'),
      (1095, '3 years'),
      (1825, '5 years'),
      (2555, '7 years'),
      (3650, '10 years'),
    ];
    return choices
        .map(
          (choice) => DropdownMenuItem<int?>(
            value: choice.$1,
            child: Text(choice.$2),
          ),
        )
        .toList();
  }
}
