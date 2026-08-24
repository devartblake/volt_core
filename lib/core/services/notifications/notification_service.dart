import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../settings/app_preferences_service.dart';

/// Local notification reminders for scheduled tasks.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'schedule_reminders';
  static const String _channelName = 'Schedule Reminders';
  static const String _channelDescription =
      'Reminders for upcoming scheduled tasks';

  bool _ready = false;
  bool _permissionRequested = false;

  Future<void> init() async {
    if (_ready) return;
    try {
      tzdata.initializeTimeZones();

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const settings = InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      );

      await _plugin.initialize(settings);
      _ready = true;
    } catch (e) {
      if (kDebugMode) debugPrint('[Notifications] init failed: $e');
    }
  }

  Future<void> _ensurePermission() async {
    if (_permissionRequested) return;
    _permissionRequested = true;
    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      if (kDebugMode) debugPrint('[Notifications] permission request failed: $e');
    }
  }

  int _idFor(String taskId) => taskId.hashCode & 0x7fffffff;

  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {
    if (!AppPreferencesService.instance.notificationsEnabled) return;
    if (!_ready) await init();
    if (!_ready) return;
    if (!scheduledAt.isAfter(DateTime.now())) return;

    await _ensurePermission();

    final when = tz.TZDateTime.from(scheduledAt, tz.UTC);

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    try {
      await _plugin.cancel(_idFor(taskId));
      await _plugin.zonedSchedule(
        _idFor(taskId),
        title,
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: taskId,
      );
      if (kDebugMode) {
        debugPrint('[Notifications] Scheduled "$title" for $scheduledAt');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Notifications] schedule failed: $e');
    }
  }

  Future<void> cancelTaskReminder(String taskId) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(_idFor(taskId));
    } catch (e) {
      if (kDebugMode) debugPrint('[Notifications] cancel failed: $e');
    }
  }

  Future<void> cancelAllTaskReminders() async {
    if (!_ready) await init();
    if (!_ready) return;
    try {
      await _plugin.cancelAll();
    } catch (e) {
      if (kDebugMode) debugPrint('[Notifications] cancel all failed: $e');
    }
  }
}
