import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'network_logger.dart';

/// Custom HTTP client that intercepts all requests for network logging.
///
/// This wraps the standard HTTP client and logs all requests/responses
/// to the NetworkLogger for debugging.
class LoggingHttpClient extends http.BaseClient {
  final http.Client _inner;

  LoggingHttpClient(this._inner);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // Only log in debug mode
    if (!kDebugMode) {
      return _inner.send(request);
    }

    final startTime = DateTime.now();

    // Read request body if available
    String? requestBody;
    if (request is http.Request) {
      requestBody = request.body;
    }

    // Log request
    final logId = NetworkLogger.logRequest(
      method: request.method,
      url: request.url.toString(),
      headers: request.headers,
      body: requestBody,
    );

    try {
      // Send request
      final response = await _inner.send(request);
      final duration = DateTime.now().difference(startTime);

      // Read response body (we need to consume the stream)
      final responseBytes = await response.stream.toBytes();
      final responseBody = String.fromCharCodes(responseBytes);

      // Log response
      NetworkLogger.logResponse(
        id: logId,
        statusCode: response.statusCode,
        headers: response.headers,
        body: responseBody,
        duration: duration,
      );

      // Return a new response with the consumed body
      return http.StreamedResponse(
        http.ByteStream.fromBytes(responseBytes),
        response.statusCode,
        contentLength: responseBytes.length,
        request: response.request,
        headers: response.headers,
        isRedirect: response.isRedirect,
        persistentConnection: response.persistentConnection,
        reasonPhrase: response.reasonPhrase,
      );
    } catch (error) {
      final duration = DateTime.now().difference(startTime);

      // Log error
      NetworkLogger.logError(
        id: logId,
        error: error,
        duration: duration,
      );

      rethrow;
    }
  }

  @override
  void close() {
    _inner.close();
  }
}

/// Factory to create HTTP client with logging
class SupabaseHttpClientFactory {
  SupabaseHttpClientFactory._();

  /// Create HTTP client with logging enabled (debug only)
  static http.Client create() {
    final baseClient = http.Client();

    if (kDebugMode) {
      return LoggingHttpClient(baseClient);
    }

    return baseClient;
  }
}