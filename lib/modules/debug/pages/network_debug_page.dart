import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/network/network_logger.dart';

/// Network debugging page for monitoring API requests and responses.
///
/// Features:
/// - Real-time request/response logging
/// - Request/response details inspection
/// - Filter by method, status code, endpoint
/// - Copy request/response for debugging
/// - Clear logs
/// - Export logs
class NetworkDebugPage extends ConsumerStatefulWidget {
  const NetworkDebugPage({super.key});

  @override
  ConsumerState<NetworkDebugPage> createState() => _NetworkDebugPageState();
}

class _NetworkDebugPageState extends ConsumerState<NetworkDebugPage> {
  String _searchQuery = '';
  String? _filterMethod;
  String? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(networkLogsProvider);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    // Filter logs based on search and filters
    final filteredLogs = logs.where((log) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        final matchesUrl = log.url.toLowerCase().contains(query);
        final matchesMethod = log.method.toLowerCase().contains(query);
        if (!matchesUrl && !matchesMethod) return false;
      }

      // Method filter
      if (_filterMethod != null && log.method != _filterMethod) {
        return false;
      }

      // Status filter
      if (_filterStatus != null) {
        if (_filterStatus == 'success' && (log.statusCode == null || log.statusCode! < 200 || log.statusCode! >= 300)) {
          return false;
        }
        if (_filterStatus == 'error' && (log.statusCode == null || log.statusCode! < 400)) {
          return false;
        }
      }

      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Network Debug'),
        backgroundColor: colors.tertiaryContainer,
        foregroundColor: colors.onTertiaryContainer,
        actions: [
          // Clear logs
          IconButton(
            onPressed: () {
              ref.read(networkLogsProvider.notifier).clearLogs();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Logs cleared')),
              );
            },
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear Logs',
          ),
          // Export logs
          IconButton(
            onPressed: () => _exportLogs(logs),
            icon: const Icon(Icons.download),
            tooltip: 'Export Logs',
          ),
          // Back to debug menu
          IconButton(
            onPressed: () => context.goNamed('debug_menu'),
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to Debug Menu',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and filters
          Container(
            padding: const EdgeInsets.all(16),
            color: colors.surfaceVariant,
            child: Column(
              children: [
                // Search bar
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by URL or method...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: colors.surface,
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
                const SizedBox(height: 12),
                // Filters
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        decoration: InputDecoration(
                          labelText: 'Method',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: colors.surface,
                        ),
                        value: _filterMethod,
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All')),
                          DropdownMenuItem(value: 'GET', child: Text('GET')),
                          DropdownMenuItem(value: 'POST', child: Text('POST')),
                          DropdownMenuItem(value: 'PUT', child: Text('PUT')),
                          DropdownMenuItem(value: 'DELETE', child: Text('DELETE')),
                          DropdownMenuItem(value: 'PATCH', child: Text('PATCH')),
                        ],
                        onChanged: (value) {
                          setState(() => _filterMethod = value);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        decoration: InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: colors.surface,
                        ),
                        value: _filterStatus,
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All')),
                          DropdownMenuItem(value: 'success', child: Text('Success')),
                          DropdownMenuItem(value: 'error', child: Text('Error')),
                        ],
                        onChanged: (value) {
                          setState(() => _filterStatus = value);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Stats bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: colors.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStatChip(
                  'Total',
                  filteredLogs.length.toString(),
                  colors.primaryContainer,
                  colors.onPrimaryContainer,
                ),
                _buildStatChip(
                  'Success',
                  filteredLogs.where((l) => l.statusCode != null && l.statusCode! >= 200 && l.statusCode! < 300).length.toString(),
                  Colors.green.shade100,
                  Colors.green.shade900,
                ),
                _buildStatChip(
                  'Error',
                  filteredLogs.where((l) => l.statusCode != null && l.statusCode! >= 400).length.toString(),
                  Colors.red.shade100,
                  Colors.red.shade900,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Logs list
          Expanded(
            child: filteredLogs.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.network_check,
                    size: 64,
                    color: colors.outline,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    logs.isEmpty
                        ? 'No network requests yet'
                        : 'No requests match filters',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (logs.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Make an API call to see logs here',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            )
                : ListView.builder(
              itemCount: filteredLogs.length,
              itemBuilder: (context, index) {
                final log = filteredLogs[filteredLogs.length - 1 - index]; // Reverse order
                return _NetworkLogTile(log: log);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: textColor.withOpacity(0.7),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  void _exportLogs(List<NetworkLog> logs) {
    final json = NetworkLogger.exportLogsAsJson(logs);
    Clipboard.setData(ClipboardData(text: json));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Logs copied to clipboard as JSON'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

/// Individual network log tile
class _NetworkLogTile extends StatelessWidget {
  const _NetworkLogTile({required this.log});

  final NetworkLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final statusColor = _getStatusColor(log.statusCode);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        leading: _buildMethodBadge(log.method, colors),
        title: Text(
          _getEndpoint(log.url),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${_formatDuration(log.duration)} • ${_formatTimestamp(log.timestamp)}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        trailing: log.statusCode != null
            ? Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: statusColor.withOpacity(0.3)),
          ),
          child: Text(
            log.statusCode.toString(),
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        )
            : const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        children: [
          _NetworkLogDetails(log: log),
        ],
      ),
    );
  }

  Widget _buildMethodBadge(String method, ColorScheme colors) {
    final color = _getMethodColor(method);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        method,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  String _getEndpoint(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.path.isEmpty ? '/' : uri.path;
    } catch (_) {
      return url;
    }
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return 'Pending...';
    if (duration.inMilliseconds < 1000) {
      return '${duration.inMilliseconds}ms';
    }
    return '${(duration.inMilliseconds / 1000).toStringAsFixed(2)}s';
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }

  Color _getMethodColor(String method) {
    switch (method) {
      case 'GET':
        return Colors.blue;
      case 'POST':
        return Colors.green;
      case 'PUT':
        return Colors.orange;
      case 'DELETE':
        return Colors.red;
      case 'PATCH':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(int? statusCode) {
    if (statusCode == null) return Colors.grey;
    if (statusCode >= 200 && statusCode < 300) return Colors.green;
    if (statusCode >= 300 && statusCode < 400) return Colors.blue;
    if (statusCode >= 400 && statusCode < 500) return Colors.orange;
    return Colors.red;
  }
}

/// Detailed view of network log
class _NetworkLogDetails extends StatelessWidget {
  const _NetworkLogDetails({required this.log});

  final NetworkLog log;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      color: colors.surfaceVariant.withOpacity(0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full URL
          _buildSection(
            'URL',
            log.url,
            context,
            canCopy: true,
          ),

          const Divider(height: 24),

          // Request Headers
          if (log.requestHeaders?.isNotEmpty ?? false)
            _buildSection(
              'Request Headers',
              _formatHeaders(log.requestHeaders!),
              context,
              canCopy: true,
            ),

          // Request Body
          if (log.requestBody != null) ...[
            const Divider(height: 24),
            _buildSection(
              'Request Body',
              log.requestBody!,
              context,
              canCopy: true,
            ),
          ],

          // Response Headers
          if (log.responseHeaders?.isNotEmpty ?? false) ...[
            const Divider(height: 24),
            _buildSection(
              'Response Headers',
              _formatHeaders(log.responseHeaders!),
              context,
              canCopy: true,
            ),
          ],

          // Response Body
          if (log.responseBody != null) ...[
            const Divider(height: 24),
            _buildSection(
              'Response Body',
              log.responseBody!,
              context,
              canCopy: true,
            ),
          ],

          // Error
          if (log.error != null) ...[
            const Divider(height: 24),
            _buildSection(
              'Error',
              log.error!,
              context,
              isError: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSection(
      String title,
      String content,
      BuildContext context, {
        bool canCopy = false,
        bool isError = false,
      }) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isError ? colors.error : colors.primary,
              ),
            ),
            if (canCopy)
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$title copied'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isError
                ? colors.errorContainer.withOpacity(0.3)
                : colors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isError
                  ? colors.error.withOpacity(0.3)
                  : colors.outline.withOpacity(0.2),
            ),
          ),
          child: SelectableText(
            content,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: isError ? colors.error : colors.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  String _formatHeaders(Map<String, dynamic> headers) {
    return headers.entries
        .map((e) => '${e.key}: ${e.value}')
        .join('\n');
  }
}