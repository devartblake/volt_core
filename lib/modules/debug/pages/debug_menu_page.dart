import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/storage/file_storage_service.dart';
import '../../../shared/widgets/widgets.dart';

/// Debug menu page for development utilities.
///
/// Only available in debug builds.
/// Provides access to:
/// - Hive debugging tools
/// - API testing (future)
/// - Feature flags (future)
/// - Quick navigation back to main page
class DebugMenuPage extends StatelessWidget {
  const DebugMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return AppPage(
      title: 'Debug Menu',
      actions: [
          // Quick return to main page
          IconButton(
            onPressed: () => context.goNamed('dashboard'),
            icon: const Icon(Icons.home),
            tooltip: 'Back to Dashboard',
          ),
        ],
      body: ListView(
        children: [
          // Warning banner
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colors.error.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.bug_report,
                  color: colors.onErrorContainer,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Debug Mode Active',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: colors.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'These tools are only available in debug builds',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Quick Actions Section
          _buildSectionHeader(context, 'Quick Actions'),

          // Back to Main Page
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: colors.primaryContainer,
                child: Icon(
                  Icons.home,
                  color: colors.onPrimaryContainer,
                ),
              ),
              title: const Text('Back to Dashboard'),
              subtitle: const Text('Return to main page'),
              trailing: Icon(
                Icons.arrow_forward,
                color: colors.primary,
              ),
              onTap: () => context.goNamed('dashboard'),
            ),
          ),

          const SizedBox(height: 24),

          // Data Management Section
          _buildSectionHeader(context, 'Data Management'),

          // Hive Debug
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: colors.tertiaryContainer,
                child: Icon(
                  Icons.storage,
                  color: colors.onTertiaryContainer,
                ),
              ),
              title: const Text('Hive Debug'),
              subtitle: const Text('Inspect and manage local data'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.goNamed('hive_debug'),
            ),
          ),

          const SizedBox(height: 24),

          _buildSectionHeader(context, 'Network Management'),

          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: colors.tertiaryContainer,
                child: Icon(
                  Icons.network_check,
                  color: colors.onTertiaryContainer,
                ),
              ),
              title: const Text('Network Monitor'),
              subtitle: const Text('Monitor API requests & responses'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.goNamed('network_debug'),
            ),
          ),

          const SizedBox(height: 24),

          // Storage Debug
          _buildSectionHeader(context, 'Storage'),

          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: colors.primaryContainer,
                child: Icon(Icons.storage),
              ),
              title: const Text('Storage Info'),
              subtitle: FutureBuilder<int>(
                future: FileStorageService.instance.getTotalStorageSize(),
                builder: (context, snapshot) {
                  if (snapshot.hasData) {
                    return Text(FileStorageService.formatBytes(snapshot.data!));
                  }
                  return const Text('Calculating...');
                },
              ),
              onTap: () async {
                await FileStorageService.instance.printDebugInfo();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Storage info printed to console')),
                );
              },
            ),
          ),

          const SizedBox(height: 24),

          // Future Features Section
          _buildSectionHeader(context, 'Coming Soon'),

          // API Debug (future)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              enabled: false,
              leading: CircleAvatar(
                backgroundColor: colors.surfaceVariant,
                child: Icon(
                  Icons.cloud,
                  color: colors.onSurfaceVariant,
                ),
              ),
              title: const Text('API Debug'),
              subtitle: const Text('Test API endpoints'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),

          // Feature Flags (future)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              enabled: false,
              leading: CircleAvatar(
                backgroundColor: colors.surfaceVariant,
                child: Icon(
                  Icons.flag,
                  color: colors.onSurfaceVariant,
                ),
              ),
              title: const Text('Feature Flags'),
              subtitle: const Text('Toggle experimental features'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),

          // Performance Monitor (future)
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              enabled: false,
              leading: CircleAvatar(
                backgroundColor: colors.surfaceVariant,
                child: Icon(
                  Icons.speed,
                  color: colors.onSurfaceVariant,
                ),
              ),
              title: const Text('Performance Monitor'),
              subtitle: const Text('Track app performance metrics'),
              trailing: const Icon(Icons.chevron_right),
            ),
          ),

          const SizedBox(height: 24),

          // App Info Section
          _buildSectionHeader(context, 'App Information'),

          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Build Mode'),
                  trailing: Chip(
                    label: Text(kDebugMode ? 'Debug' : 'Release'),
                    backgroundColor: kDebugMode
                        ? colors.errorContainer
                        : colors.primaryContainer,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.phone_android),
                  title: const Text('Platform'),
                  trailing: Chip(
                    label: Text(_getPlatform()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.app_shortcut_outlined),
                  title: const Text('App Version'),
                  trailing: const Text('1.0.0'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Footer with quick exit button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton.icon(
              onPressed: () => context.goNamed('dashboard'),
              icon: const Icon(Icons.exit_to_app),
              label: const Text('Exit Debug Menu'),
              style: FilledButton.styleFrom(
                backgroundColor: colors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: colors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  String _getPlatform() {
    if (kIsWeb) return 'Web';

    // You can add more platform detection here
    // For now, just return a generic label
    return 'Mobile';
  }
}