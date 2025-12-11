import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Network log entry
class NetworkLog {
  final String id;
  final DateTime timestamp;
  final String method;
  final String url;
  final Map<String, dynamic>? requestHeaders;
  final String? requestBody;
  final int? statusCode;
  final Map<String, dynamic>? responseHeaders;
  final String? responseBody;
  final String? error;
  final Duration? duration;

  const NetworkLog({
    required this.id,
    required this.timestamp,
    required this.method,
    required this.url,
    this.requestHeaders,
    this.requestBody,
    this.statusCode,
    this.responseHeaders,
    this.responseBody,
    this.error,
    this.duration,
  });

  NetworkLog copyWith({
    int? statusCode,
    Map<String, dynamic>? responseHeaders,
    String? responseBody,
    String? error,
    Duration? duration,
  }) {
    return NetworkLog(
      id: id,
      timestamp: timestamp,
      method: method,
      url: url,
      requestHeaders: requestHeaders,
      requestBody: requestBody,
      statusCode: statusCode ?? this.statusCode,
      responseHeaders: responseHeaders ?? this.responseHeaders,
      responseBody: responseBody ?? this.responseBody,
      error: error ?? this.error,
      duration: duration ?? this.duration,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'method': method,
      'url': url,
      'requestHeaders': requestHeaders,
      'requestBody': requestBody,
      'statusCode': statusCode,
      'responseHeaders': responseHeaders,
      'responseBody': responseBody,
      'error': error,
      'durationMs': duration?.inMilliseconds,
    };
  }
}

/// Network logger state notifier
class NetworkLogsNotifier extends StateNotifier<List<NetworkLog>> {
  NetworkLogsNotifier() : super([]);

  /// Add a new request log
  String logRequest({
    required String method,
    required String url,
    Map<String, dynamic>? headers,
    String? body,
  }) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final log = NetworkLog(
      id: id,
      timestamp: DateTime.now(),
      method: method.toUpperCase(),
      url: url,
      requestHeaders: headers,
      requestBody: body,
    );

    state = [...state, log];

    if (kDebugMode) {
      debugPrint('[Network] ${log.method} ${log.url}');
    }

    return id;
  }

  /// Update log with response
  void logResponse({
    required String id,
    required int statusCode,
    Map<String, dynamic>? headers,
    String? body,
    required Duration duration,
  }) {
    state = [
      for (final log in state)
        if (log.id == id)
          log.copyWith(
            statusCode: statusCode,
            responseHeaders: headers,
            responseBody: body,
            duration: duration,
          )
        else
          log,
    ];

    if (kDebugMode) {
      debugPrint('[Network] Response $statusCode in ${duration.inMilliseconds}ms');
    }
  }

  /// Log error
  void logError({
    required String id,
    required String error,
    required Duration duration,
  }) {
    state = [
      for (final log in state)
        if (log.id == id)
          log.copyWith(
            error: error,
            duration: duration,
          )
        else
          log,
    ];

    if (kDebugMode) {
      debugPrint('[Network] Error: $error');
    }
  }

  /// Clear all logs
  void clearLogs() {
    state = [];
    if (kDebugMode) {
      debugPrint('[Network] Logs cleared');
    }
  }

  /// Remove logs older than duration
  void removeOldLogs(Duration maxAge) {
    final cutoff = DateTime.now().subtract(maxAge);
    state = state.where((log) => log.timestamp.isAfter(cutoff)).toList();
  }
}

/// Provider for network logs
final networkLogsProvider =
StateNotifierProvider<NetworkLogsNotifier, List<NetworkLog>>((ref) {
  return NetworkLogsNotifier();
});

/// Network logger utility class
class NetworkLogger {
  NetworkLogger._();

  static NetworkLogsNotifier? _notifier;

  /// Initialize the network logger with the notifier
  static void init(NetworkLogsNotifier notifier) {
    _notifier = notifier;
  }

  /// Log a request (returns ID for tracking)
  static String logRequest({
    required String method,
    required String url,
    Map<String, dynamic>? headers,
    dynamic body,
  }) {
    if (_notifier == null) {
      if (kDebugMode) {
        debugPrint('[NetworkLogger] Warning: Logger not initialized');
      }
      return '';
    }

    String? bodyStr;
    if (body != null) {
      try {
        bodyStr = body is String ? body : jsonEncode(body);
      } catch (e) {
        bodyStr = body.toString();
      }
    }

    return _notifier!.logRequest(
      method: method,
      url: url,
      headers: headers,
      body: bodyStr,
    );
  }

  /// Log a response
  static void logResponse({
    required String id,
    required int statusCode,
    Map<String, dynamic>? headers,
    dynamic body,
    required Duration duration,
  }) {
    if (_notifier == null) return;

    String? bodyStr;
    if (body != null) {
      try {
        bodyStr = body is String ? body : jsonEncode(body);
        // Truncate very long responses
        if (bodyStr.length > 10000) {
          bodyStr = '${bodyStr.substring(0, 10000)}... [truncated]';
        }
      } catch (e) {
        bodyStr = body.toString();
      }
    }

    _notifier!.logResponse(
      id: id,
      statusCode: statusCode,
      headers: headers,
      body: bodyStr,
      duration: duration,
    );
  }

  /// Log an error
  static void logError({
    required String id,
    required dynamic error,
    required Duration duration,
  }) {
    if (_notifier == null) return;

    _notifier!.logError(
      id: id,
      error: error.toString(),
      duration: duration,
    );
  }

  /// Export logs as JSON
  static String exportLogsAsJson(List<NetworkLog> logs) {
    final data = {
      'exportedAt': DateTime.now().toIso8601String(),
      'totalLogs': logs.length,
      'logs': logs.map((log) => log.toJson()).toList(),
    };

    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (e) {
      return jsonEncode(data);
    }
  }
}