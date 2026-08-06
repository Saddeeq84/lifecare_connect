// ignore_for_file: deprecated_member_use, depend_on_referenced_packages

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class NotificationService {
  static final _notifications = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();

    await _notifications.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
  }

  /// Show an instant notification (for visit reminders, etc.)
  static Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const android = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _notifications.show(
      id,
      title,
      body,
      const NotificationDetails(android: android),
    );
  }

  /// Show a notification immediately (generic)
  static Future<void> showNow({
    required String title,
    required String body,
  }) async {
    const android = AndroidNotificationDetails(
      'main_channel',
      'Main Channel',
      importance: Importance.max,
      priority: Priority.high,
    );

    await _notifications.show(
      DateTime.now().millisecond,
      title,
      body,
      const NotificationDetails(android: android),
    );
  }

  /// General method to schedule a notification
  static Future<void> scheduleVisitReminder({
    required String title,
    required String body,
    required DateTime dateTime,
    bool repeatDaily = false,
  }) async {
    await _notifications.zonedSchedule(
      dateTime.millisecond,
      title,
      body,
      tz.TZDateTime.from(dateTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminder_channel',
          'Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      matchDateTimeComponents: repeatDaily ? DateTimeComponents.time : null,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  /// Specific method to schedule an ANC visit reminder for tomorrow
  static Future<void> scheduleANCVisitReminder() async {
    final scheduledTime = tz.TZDateTime.now(
      tz.local,
    ).add(const Duration(days: 1));
    await _notifications.zonedSchedule(
      0,
      'ANC Visit Reminder',
      'Reminder for upcoming ANC visit tomorrow.',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'visit_reminder',
          'ANC Visit Reminder',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      matchDateTimeComponents: DateTimeComponents.time, // optional for daily
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }
}
