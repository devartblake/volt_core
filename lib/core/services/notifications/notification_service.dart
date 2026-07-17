import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Local notification reminders for scheduled tasks (upcoming inspections /
/// maintenance). Uses `flutter_local_notifications` with inexact scheduling so
/// no exact-alarm permission is required.
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

  /// Initialize the plugin and timezone database. Does not prompt for
  /// permission — that happens the first time a reminder is scheduled, so the
  /// prompt appears in context rather than at cold start. Never throws.
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
      final android =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();

      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      if (kDebugMode) debugPrint('[Notifications] permission request failed: $e');
    }
  }

  /// Stable non-negative notification id derived from the task id.
  int _idFor(String taskId) => taskId.hashCode & 0x7fffffff;

  /// Schedule (or reschedule) a reminder for a task. A past time is ignored.
  Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {
    if (!_ready) await init();
    if (!_ready) return;
    if (!scheduledAt.isAfter(DateTime.now())) return;

    await _ensurePermission();

    // Express the target instant as a TZDateTime. Using UTC keeps the absolute
    // instant correct without needing the device's IANA timezone name; the
    // notification fires at that instant regardless of the zone it's expressed
    // in.
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
      // Cancel any existing reminder for this task before rescheduling.
      await _plugin.cancel(_idFor(taskId));
      await _plugin.zonedSchedule(
        _idFor(taskId),
        title,
        body,
        when,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: taskId,
      );
      if (kDebugMode) {
        debugPrint('[Notifications] Scheduled "$title" for $scheduledAt');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[Notifications] schedule failed: $e');
    }
  }

  /// Cancel a task's reminder (e.g. when the task is deleted or completed).
  Future<void> cancelTaskReminder(String taskId) async {
    if (!_ready) return;
    try {
      await _plugin.cancel(_idFor(taskId));
    } catch (e) {
      if (kDebugMode) debugPrint('[Notifications] cancel failed: $e');
    }
  }
}
