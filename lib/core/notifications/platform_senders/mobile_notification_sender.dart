import '../notification_navigation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'platform_notification_sender.dart';

/// Robust Mobile implementation of [PlatformNotificationSender] using `flutter_local_notifications`.
///
/// CRASH PREVENTION & SYSTEM TRAY RELIABILITY ON REAL ANDROID DEVICES (12+, 13+, 14+):
/// -----------------------------------------------------------------------------------
/// 1. AlarmManager Broadcast Receiver Configuration:
///    `ScheduledNotificationReceiver` MUST be explicitly declared in AndroidManifest.xml
///    with `android:exported="false"` so Android's native AlarmManager can invoke the pending
///    intent when `zonedSchedule()` timer expires and display the tray notification.
///
/// 2. Icon Resource Resolution:
///    In AndroidNotificationDetails, omitting the `icon` argument tells the plugin to use
///    the default app launcher icon from `AndroidInitializationSettings('@mipmap/ic_launcher')`.
///
/// 3. Notification Channels with Max Importance:
///    Explicitly creates and registers all notification channels with `Importance.max` and high priority
///    with Android's NotificationManager so that heads-up notification popups, system tray badges,
///    sound, and vibration are never silenced by the OS.
///
/// 4. Crash-Proof Exact Alarm Scheduling:
///    Attempts exact alarm scheduling (`exactAllowWhileIdle`). If the OEM or system restricts exact alarms
///    (or throws `SecurityException`), it seamlessly catches the error and falls back to `inexactAllowWhileIdle`
///    so that alarms are delivered without crashing the application process.
class MobileNotificationSender implements PlatformNotificationSender {
  static final MobileNotificationSender _instance =
      MobileNotificationSender._internal();
  factory MobileNotificationSender() => _instance;
  MobileNotificationSender._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      tz.initializeTimeZones();
    } catch (_) {}

    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

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

      await _plugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (response) {
          NotificationNavigation.open(response.payload);
        },
      );

      // Explicitly register all native Android notification channels
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImpl != null) {
        await _createAndroidChannels(androidImpl);
      }

      _initialized = true;
      debugPrint('==> MobileNotificationSender initialized successfully.');
    } catch (e, stack) {
      debugPrint('==> MobileNotificationSender.initialize error: $e\n$stack');
    }
  }

  /// Explicitly registers notification channels with Android NotificationManager
  Future<void> _createAndroidChannels(
    AndroidFlutterLocalNotificationsPlugin androidImpl,
  ) async {
    try {
      const channels = [
        AndroidNotificationChannel(
          'focusly_general_channel',
          'Focusly Notifications',
          description: 'General notifications and updates for Focusly',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
        AndroidNotificationChannel(
          'task_reminders',
          'Task Reminders',
          description: 'Reminders and alarms for scheduled tasks',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
        AndroidNotificationChannel(
          'task_deadlines',
          'Task Deadlines',
          description: 'Urgent deadline warnings for tasks',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
        AndroidNotificationChannel(
          'schedule_events',
          'Schedule Events',
          description: 'Calendar event reminders',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
        AndroidNotificationChannel(
          'focusly_habits_channel',
          'Habit Reminders',
          description: 'Daily habit alerts and streak reminders',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
        AndroidNotificationChannel(
          'focusly_pomodoro_channel',
          'Pomodoro Focus Timer',
          description: 'Focus timer and break completion alerts',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
        AndroidNotificationChannel(
          'focusly_diagnostic_channel',
          'Diagnostic Test Alerts',
          description: 'Diagnostic test notifications',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
        ),
      ];

      for (final channel in channels) {
        await androidImpl.createNotificationChannel(channel);
      }
      debugPrint(
        '==> Registered ${channels.length} native Android notification channels with Importance.max',
      );
    } catch (e) {
      debugPrint('==> Error creating Android notification channels: $e');
    }
  }

  @override
  Future<bool> requestPermissions() async {
    await initialize();

    try {
      final androidImpl = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidImpl != null) {
        final granted = await androidImpl.requestNotificationsPermission();
        return granted ?? false;
      }

      final iosImpl = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (iosImpl != null) {
        final granted = await iosImpl.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('==> MobileNotificationSender.requestPermissions error: $e');
    }
    return true;
  }

  @override
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    String? channelId,
    String? channelName,
  }) async {
    await initialize();

    tz.TZDateTime nowTz;
    tz.TZDateTime tzScheduled;
    try {
      nowTz = tz.TZDateTime.now(tz.local);
      tzScheduled = scheduledDate is tz.TZDateTime
          ? scheduledDate
          : tz.TZDateTime.from(scheduledDate, tz.local);
    } catch (e) {
      debugPrint('==> Timezone conversion error ($e). Using UTC conversion.');
      nowTz = tz.TZDateTime.now(tz.UTC);
      tzScheduled = tz.TZDateTime.from(scheduledDate, tz.UTC);
    }

    final int diffSeconds = tzScheduled.difference(nowTz).inSeconds;
    debugPrint(
      '==> [MobileNotificationSender.scheduleNotification] ID: $id | Title: "$title" | Target: $tzScheduled (Local: $nowTz, Delay: ${diffSeconds}s, TimeZone: ${tz.local.name})',
    );

    if (diffSeconds < 0) {
      debugPrint(
        '==> Warning: Attempted to schedule notification in past. Showing immediately.',
      );
      await showInstantNotification(
        id: id,
        title: title,
        body: body,
        payload: payload,
        channelId: channelId,
        channelName: channelName,
      );
      return;
    }

    final details = _buildNotificationDetails(
      channelId ?? 'focusly_general_channel',
      channelName ?? 'Focusly Notifications',
    );

    try {
      // 1. Primary: Attempt exact alarm scheduling
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tzScheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
        matchDateTimeComponents: channelId == 'focusly_habits_daily'
            ? DateTimeComponents.time
            : null,
      );
      debugPrint(
        '==> [MobileNotificationSender] Notification #$id successfully scheduled via exactAllowWhileIdle',
      );
    } catch (e) {
      debugPrint(
        '==> [MobileNotificationSender] exactAllowWhileIdle failed ($e). Retrying with inexactAllowWhileIdle...',
      );
      try {
        // 2. Safe fallback: Schedule with inexactAllowWhileIdle if exact alarm was denied/unsupported
        await _plugin.zonedSchedule(
          id,
          title,
          body,
          tzScheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
          matchDateTimeComponents: channelId == 'focusly_habits_daily'
              ? DateTimeComponents.time
              : null,
        );
        debugPrint(
          '==> [MobileNotificationSender] Notification #$id successfully scheduled via inexact fallback',
        );
      } catch (fallbackError, stack) {
        debugPrint(
          '==> [MobileNotificationSender] Inexact fallback failed: $fallbackError\n$stack',
        );
        rethrow;
      }
    }
  }

  @override
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? channelId,
    String? channelName,
  }) async {
    await initialize();

    final details = _buildNotificationDetails(
      channelId ?? 'focusly_general_channel',
      channelName ?? 'Focusly Notifications',
    );

    debugPrint(
      '==> [MobileNotificationSender] Showing instant notification #$id ("$title")',
    );

    try {
      await _plugin.show(id, title, body, details, payload: payload);
      debugPrint(
        '==> [MobileNotificationSender] Instant notification #$id displayed successfully',
      );
    } catch (e, stack) {
      debugPrint(
        '==> [MobileNotificationSender.showInstantNotification] Error: $e\n$stack',
      );
    }
  }

  @override
  Future<void> cancelNotification(int id) async {
    try {
      await _plugin.cancel(id);
      debugPrint('==> [MobileNotificationSender] Cancelled notification #$id');
    } catch (e) {
      debugPrint('==> [MobileNotificationSender.cancelNotification] error: $e');
    }
  }

  @override
  Future<void> cancelAllNotifications() async {
    try {
      await _plugin.cancelAll();
      debugPrint('==> [MobileNotificationSender] Cancelled all notifications');
    } catch (e) {
      debugPrint(
        '==> [MobileNotificationSender.cancelAllNotifications] error: $e',
      );
    }
  }

  NotificationDetails _buildNotificationDetails(
    String channelId,
    String channelName,
  ) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        channelName,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }
}
