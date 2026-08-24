import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../settings/app_preferences_service.dart';

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
      responseHeaders: responseHeaders,
      responseBody: responseBody,
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

class NetworkLogsNotifier extends StateNotifier<List<NetworkLog>> {
  NetworkLogsNotifier() : super([]);

  String logRequest({
    required String method,
    required String url,
    Map<String, dynamic>? headers,
    String? body,
  }) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
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
      debugPrint(
        '[Network] Response $statusCode in ${duration.inMilliseconds}ms',
      );
    }
  }

  void logError({
    required String id,
    required String error,
    required Duration duration,
  }) {
    state = [
      for (final log in state)
        if (log.id == id)
          log.copyWith(error: error, duration: duration)
        else
          log,
    ];

    if (kDebugMode) debugPrint('[Network] Error: $error');
  }

  void clearLogs() {
    state = [];
    if (kDebugMode) debugPrint('[Network] Logs cleared');
  }

  void removeOldLogs(Duration maxAge) {
    final cutoff = DateTime.now().subtract(maxAge);
    state = state.where((log) => log.timestamp.isAfter(cutoff)).toList();
  }
}

final networkLogsProvider =
    StateNotifierProvider<NetworkLogsNotifier, List<NetworkLog>>((ref) {
  return NetworkLogsNotifier();
});

class NetworkLogger {
  NetworkLogger._();

  static NetworkLogsNotifier? _notifier;

  static const _sensitiveHeaderNames = {
    'authorization',
    'apikey',
    'x-api-key',
    'cookie',
    'set-cookie',
  };

  static const _sensitiveQueryNames = {
    'access_token',
    'token',
    'apikey',
    'api_key',
    'key',
    'code',
  };

  static void init(NetworkLogsNotifier notifier) {
    _notifier = notifier;
  }

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

    final advanced = AppPreferencesService.instance.advancedLoggingEnabled;
    return _notifier!.logRequest(
      method: method,
      url: _sanitizeUrl(url),
      headers: advanced ? _redactHeaders(headers) : null,
      body: advanced ? _serializeBody(body) : null,
    );
  }

  static void logResponse({
    required String id,
    required int statusCode,
    Map<String, dynamic>? headers,
    dynamic body,
    required Duration duration,
  }) {
    if (_notifier == null) return;

    final advanced = AppPreferencesService.instance.advancedLoggingEnabled;
    _notifier!.logResponse(
      id: id,
      statusCode: statusCode,
      headers: advanced ? _redactHeaders(headers) : null,
      body: advanced ? _serializeBody(body) : null,
      duration: duration,
    );
  }

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

  static Map<String, dynamic>? _redactHeaders(
    Map<String, dynamic>? headers,
  ) {
    if (headers == null) return null;
    return {
      for (final entry in headers.entries)
        entry.key: _sensitiveHeaderNames.contains(entry.key.toLowerCase())
            ? '[redacted]'
            : entry.value,
    };
  }

  static String? _serializeBody(dynamic body) {
    if (body == null) return null;
    String result;
    try {
      result = body is String ? body : jsonEncode(body);
    } catch (_) {
      result = body.toString();
    }
    if (result.length > 10000) {
      return '${result.substring(0, 10000)}... [truncated]';
    }
    return result;
  }

  static String _sanitizeUrl(String rawUrl) {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.queryParameters.isEmpty) return rawUrl;

    var changed = false;
    final safeQuery = <String, String>{};
    for (final entry in uri.queryParameters.entries) {
      if (_sensitiveQueryNames.contains(entry.key.toLowerCase())) {
        safeQuery[entry.key] = '[redacted]';
        changed = true;
      } else {
        safeQuery[entry.key] = entry.value;
      }
    }
    return changed ? uri.replace(queryParameters: safeQuery).toString() : rawUrl;
  }

  static String exportLogsAsJson(List<NetworkLog> logs) {
    final data = {
      'exportedAt': DateTime.now().toIso8601String(),
      'totalLogs': logs.length,
      'logs': logs.map((log) => log.toJson()).toList(),
    };

    try {
      return const JsonEncoder.withIndent('  ').convert(data);
    } catch (_) {
      return jsonEncode(data);
    }
  }
}
