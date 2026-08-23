import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../../core/localization/app_localizations.dart';
import '../models/task_model.dart';

/// Service responsible for scheduling and cancelling local task reminder notifications.
///
/// TODO: Note on timezone handling: Timezone database is initialized with local
/// device settings using `timezone` package to keep scheduled alerts synchronized
/// across daylight saving and system clock changes.
class TaskNotificationService {
  static final TaskNotificationService _instance =
      TaskNotificationService._internal();
  factory TaskNotificationService() => _instance;
  TaskNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initializes the local notification plugin and timezone data
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // 1. Initialize time zones
      tz.initializeTimeZones();

      // 2. Android Initialization Settings
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // 3. iOS Initialization Settings
      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification tapped: ${response.payload}');
        },
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('TaskNotificationService initialize error: $e');
    }
  }

  /// Requests notification permissions (especially on Android 13+ and iOS)
  Future<bool> requestPermissions() async {
    try {
      final androidImpl =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final granted = await androidImpl.requestNotificationsPermission();
        return granted ?? false;
      }

      final iosImpl =
          _notificationsPlugin.resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (iosImpl != null) {
        final granted = await iosImpl.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('Error requesting notification permissions: $e');
    }
    return true;
  }

  /// Generates a stable unique integer notification ID from task ID and slot (0, 1, 2)
  int _generateNotificationId(String taskId, int slot) {
    return (taskId.hashCode ^ (slot * 31)).abs() & 0x7FFFFFFF;
  }

  /// Schedules all relevant notifications for a task:
  /// 1. Specific Time Notification (at exact scheduled date + time)
  /// 2. 24 Hours Before Deadline Notification
  /// 3. 1 Hour Before Deadline Notification
  Future<void> scheduleTaskNotifications(
    TaskModel task,
    AppLocalizations localizations,
  ) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Always clear prior scheduled slots first to prevent duplicate or stale alerts
    await cancelTaskNotifications(task.id);

    // If task is completed, do not schedule any upcoming alerts
    if (task.done) return;

    final now = DateTime.now();

    // -------------------------------------------------------------------------
    // 1. SPECIFIC TASK TIME NOTIFICATION
    // -------------------------------------------------------------------------
    if (task.time != null) {
      final scheduledDateTime = DateTime(
        task.date.year,
        task.date.month,
        task.date.day,
        task.time!.hour,
        task.time!.minute,
      );

      if (scheduledDateTime.isAfter(now)) {
        try {
          final tzScheduled = tz.TZDateTime.from(scheduledDateTime, tz.local);
          final id = _generateNotificationId(task.id, 0);

          await _notificationsPlugin.zonedSchedule(
            id,
            localizations.tr('notification_task_time_title'),
            '${task.title} • ${task.time!.hour.toString().padLeft(2, '0')}:${task.time!.minute.toString().padLeft(2, '0')}',
            tzScheduled,
            _buildNotificationDetails('task_reminders', 'Task Reminders'),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: task.id,
          );
        } catch (e) {
          debugPrint('Error scheduling task time notification: $e');
        }
      }
    }

    // -------------------------------------------------------------------------
    // 2. DEADLINE NOTIFICATIONS (24h before & 1h before)
    // -------------------------------------------------------------------------
    if (task.deadline != null) {
      // 2a. 24 Hours Before Deadline
      final deadline24h = task.deadline!.subtract(const Duration(hours: 24));
      if (deadline24h.isAfter(now)) {
        try {
          final tz24h = tz.TZDateTime.from(deadline24h, tz.local);
          final id24 = _generateNotificationId(task.id, 1);

          await _notificationsPlugin.zonedSchedule(
            id24,
            localizations.tr('notification_deadline_24h_title'),
            task.title,
            tz24h,
            _buildNotificationDetails('task_deadlines', 'Task Deadlines'),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: task.id,
          );
        } catch (e) {
          debugPrint('Error scheduling 24h deadline notification: $e');
        }
      }

      // 2b. 1 Hour Before Deadline
      final deadline1h = task.deadline!.subtract(const Duration(hours: 1));
      if (deadline1h.isAfter(now)) {
        try {
          final tz1h = tz.TZDateTime.from(deadline1h, tz.local);
          final id1 = _generateNotificationId(task.id, 2);

          await _notificationsPlugin.zonedSchedule(
            id1,
            localizations.tr('notification_deadline_1h_title'),
            task.title,
            tz1h,
            _buildNotificationDetails('task_deadlines', 'Task Deadlines'),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: task.id,
          );
        } catch (e) {
          debugPrint('Error scheduling 1h deadline notification: $e');
        }
      }
    }
  }

  /// Cancels all scheduled notification slots for a given task ID
  Future<void> cancelTaskNotifications(String taskId) async {
    try {
      await _notificationsPlugin.cancel(_generateNotificationId(taskId, 0));
      await _notificationsPlugin.cancel(_generateNotificationId(taskId, 1));
      await _notificationsPlugin.cancel(_generateNotificationId(taskId, 2));
    } catch (e) {
      debugPrint('Error cancelling task notifications: $e');
    }
  }

  NotificationDetails _buildNotificationDetails(String channelId, String channelName) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }
}
