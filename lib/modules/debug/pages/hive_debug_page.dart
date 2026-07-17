import 'package:flutter/material.dart';

import '../../../core/services/hive/hive_service.dart';
import '../../../modules/maintenance/infra/datasources/hive_boxes_maintenance.dart';

/// Debug menu page for Hive management.
///
/// Only available in debug builds.
/// Add to your router for easy access during development.
class HiveDebugPage extends StatefulWidget {
  const HiveDebugPage({super.key});

  @override
  State<HiveDebugPage> createState() => _HiveDebugPageState();
}

class _HiveDebugPageState extends State<HiveDebugPage> {
  Map<String, int>? _stats;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refreshStats();
  }

  void _refreshStats() {
    setState(() {
      _stats = HiveService.getBoxStatistics();
    });
  }

  Future<void> _resetData({required bool deleteData}) async {
    final confirmed = await _showConfirmDialog(
      title: deleteData ? 'Delete All Data?' : 'Reset Hive?',
      message: deleteData
          ? 'This will permanently delete ALL local data. This cannot be undone!'
          : 'This will close and reopen all boxes. Data will be preserved.',
    );

    if (!confirmed) return;

    setState(() => _loading = true);

    try {
      await HiveService.reset(deleteData: deleteData);
      await MaintenanceBoxes.init();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(deleteData ? 'All data deleted!' : 'Hive reset!'),
            backgroundColor: Colors.green,
          ),
        );
        _refreshStats();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
        false;
  }

  void _printDebugInfo() {
    HiveService.printDebugInfo();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Debug info printed to console'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hive Debug'),
        backgroundColor: colors.errorContainer,
        foregroundColor: colors.onErrorContainer,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Warning banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.errorContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_rounded,
                  color: colors.onErrorContainer,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Debug Mode Only\nBe careful with destructive actions!',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Status section
          _buildSection(
            title: 'Status',
            children: [
              _buildStatusTile(
                'Initialized',
                HiveService.isInitialized,
                icon: HiveService.isInitialized
                    ? Icons.check_circle
                    : Icons.error,
                color: HiveService.isInitialized
                    ? Colors.green
                    : Colors.red,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Statistics section
          _buildSection(
            title: 'Box Statistics',
            children: [
              if (_stats == null || _stats!.isEmpty)
                const ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('No boxes open'),
                )
              else
                ..._stats!.entries.map((entry) {
                  return ListTile(
                    leading: const Icon(Icons.storage),
                    title: Text(entry.key),
                    trailing: Chip(
                      label: Text('${entry.value} entries'),
                    ),
                  );
                }),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: _refreshStats,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh Stats'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Actions section
          _buildSection(
            title: 'Actions',
            children: [
              ListTile(
                leading: const Icon(Icons.bug_report),
                title: const Text('Print Debug Info'),
                subtitle: const Text('Prints detailed info to console'),
                onTap: _printDebugInfo,
              ),
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Reset (Keep Data)'),
                subtitle: const Text('Close and reopen boxes'),
                onTap: () => _resetData(deleteData: false),
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_forever,
                  color: Colors.red,
                ),
                title: const Text(
                  'Delete All Data',
                  style: TextStyle(color: Colors.red),
                ),
                subtitle: const Text('Permanently delete everything'),
                onTap: () => _resetData(deleteData: true),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Info section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.surfaceVariant,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: colors.onSurfaceVariant,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'About',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: colors.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'This page is only available in debug builds. '
                      'Use it to inspect and manage local Hive data during development.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: colors.primary,
            ),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusTile(
      String label,
      bool value, {
        required IconData icon,
        required Color color,
      }) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(label),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(
          value ? 'Yes' : 'No',
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
