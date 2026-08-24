import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:voltcore/core/services/network/network_logger.dart';
import 'package:voltcore/core/services/settings/app_preferences_service.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('voltcore-network-log-test-');
    Hive.init(tempDir.path);
    NetworkLogger.init(NetworkLogsNotifier());
  });

  tearDown(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  test('basic logging omits headers and bodies and sanitizes URL secrets', () {
    final notifier = NetworkLogsNotifier();
    NetworkLogger.init(notifier);

    NetworkLogger.logRequest(
      method: 'GET',
      url: 'https://example.test/items?token=secret&limit=10',
      headers: {'Authorization': 'Bearer secret', 'Accept': 'application/json'},
      body: {'private': 'value'},
    );

    final log = notifier.state.single;
    expect(log.requestHeaders, isNull);
    expect(log.requestBody, isNull);
    expect(log.url, contains('token=%5Bredacted%5D'));
    expect(log.url, contains('limit=10'));
    expect(log.url, isNot(contains('secret')));
  });

  test('advanced logging keeps useful payload detail but redacts credentials',
      () async {
    await AppPreferencesService.instance.setAdvancedLoggingEnabled(true);
    final notifier = NetworkLogsNotifier();
    NetworkLogger.init(notifier);

    final id = NetworkLogger.logRequest(
      method: 'POST',
      url: 'https://example.test/items',
      headers: {
        'Authorization': 'Bearer secret',
        'apikey': 'secret-key',
        'Accept': 'application/json',
      },
      body: {'name': 'Generator A'},
    );
    NetworkLogger.logResponse(
      id: id,
      statusCode: 200,
      headers: {'set-cookie': 'session=secret', 'Content-Type': 'application/json'},
      body: {'ok': true},
      duration: const Duration(milliseconds: 20),
    );

    final log = notifier.state.single;
    expect(log.requestHeaders?['Authorization'], '[redacted]');
    expect(log.requestHeaders?['apikey'], '[redacted]');
    expect(log.requestHeaders?['Accept'], 'application/json');
    expect(log.requestBody, contains('Generator A'));
    expect(log.responseHeaders?['set-cookie'], '[redacted]');
    expect(log.responseHeaders?['Content-Type'], 'application/json');
    expect(log.responseBody, contains('true'));
  });
}
