import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/habit_model.dart';

/// Service responsible for managing local notifications for daily Habits in Focusly.
///
/// Schedules daily-repeating alerts at the habit's configured reminder time
/// using timezone-aware notifications and deterministic integer IDs.
class HabitNotificationService {
  static final HabitNotificationService _instance =
      HabitNotificationService._internal();
  factory HabitNotificationService() => _instance;
  HabitNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Initializes the local notification plugin and timezones
  Future<void> initialize() async {
    if (_isInitialized) return;

    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    try {
      await _notificationsPlugin.initialize(initSettings);
      _isInitialized = true;
    } catch (_) {
      // Graceful fallback for headless/test environments
    }
  }

  /// Generates a stable 32-bit positive integer ID for the habit notification
  static int getNotificationId(String habitId) {
    return habitId.hashCode.abs() & 0x7FFFFFFF;
  }

  /// Schedules or reschedules a daily recurring notification for a habit
  Future<void> scheduleHabitReminder({
    required HabitModel habit,
    required String notificationTitle,
  }) async {
    if (habit.time == null) {
      await cancelHabitReminder(habit.id);
      return;
    }

    try {
      await initialize();
      final int notificationId = getNotificationId(habit.id);

      // Cancel previous notification if any
      await _notificationsPlugin.cancel(notificationId);

      final now = tz.TZDateTime.now(tz.local);
      var scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        habit.time!.hour,
        habit.time!.minute,
      );

      // If scheduled time has already passed today, schedule for tomorrow
      if (scheduledDate.isBefore(now)) {
        scheduledDate = scheduledDate.add(const Duration(days: 1));
      }

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'focusly_habits_channel',
        'Habit Reminders',
        channelDescription: 'Daily alerts and streak reminders for Focusly habits',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _notificationsPlugin.zonedSchedule(
        notificationId,
        notificationTitle,
        habit.title,
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Daily repeat at this time
      );
    } catch (_) {
      // Graceful fallback if device permissions are not yet granted
    }
  }

  /// Cancels any scheduled notification for a given habit ID
  Future<void> cancelHabitReminder(String habitId) async {
    try {
      await initialize();
      final int notificationId = getNotificationId(habitId);
      await _notificationsPlugin.cancel(notificationId);
    } catch (_) {}
  }
}
