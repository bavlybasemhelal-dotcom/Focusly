import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Service managing precisely timed local notifications for Pomodoro phase completions.
///
/// Ensures phase-end alerts trigger on time even if the app is backgrounded.
class PomodoroNotificationService {
  static final PomodoroNotificationService _instance =
      PomodoroNotificationService._internal();
  factory PomodoroNotificationService() => _instance;
  PomodoroNotificationService._internal();

  static const int pomodoroNotificationId = 999991;

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
      // Graceful fallback for tests/headless
    }
  }

  /// Schedules a phase-completion notification at the exact target end timestamp
  Future<void> schedulePhaseCompletion({
    required DateTime targetEndTime,
    required String title,
    required String body,
  }) async {
    try {
      await initialize();
      await cancelPendingNotification();

      final now = tz.TZDateTime.now(tz.local);
      final scheduledDate = tz.TZDateTime.from(targetEndTime, tz.local);

      if (scheduledDate.isBefore(now)) return;

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'focusly_pomodoro_channel',
        'Pomodoro Focus Timer',
        channelDescription:
            'Alerts when focus sessions and break periods complete in Focusly',
        importance: Importance.max,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
        playSound: true,
        enableVibration: true,
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
        pomodoroNotificationId,
        title,
        body,
        scheduledDate,
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  /// Cancels any scheduled Pomodoro notification
  Future<void> cancelPendingNotification() async {
    try {
      await initialize();
      await _notificationsPlugin.cancel(pomodoroNotificationId);
    } catch (_) {}
  }
}
