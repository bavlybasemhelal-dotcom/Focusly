import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'platform_notification_sender.dart';

/// Mobile implementation of [PlatformNotificationSender] using `flutter_local_notifications`.
///
/// Handles Android 12+/13+/14+ exact alarms (`exactAllowWhileIdle`),
/// Notification channels with high importance and vibration, and iOS foreground presentation.
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
          debugPrint('Mobile notification response payload: ${response.payload}');
        },
      );

      _initialized = true;
    } catch (e) {
      debugPrint('MobileNotificationSender.initialize error: $e');
    }
  }

  @override
  Future<bool> requestPermissions() async {
    try {
      final androidImpl =
          _plugin.resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final granted = await androidImpl.requestNotificationsPermission();
        try {
          await androidImpl.requestExactAlarmsPermission();
        } catch (_) {}
        return granted ?? false;
      }

      final iosImpl =
          _plugin.resolvePlatformSpecificImplementation<
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
      debugPrint('MobileNotificationSender.requestPermissions error: $e');
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

    tz.TZDateTime now;
    tz.TZDateTime tzScheduled;
    try {
      tz.initializeTimeZones();
      now = tz.TZDateTime.now(tz.local);
      tzScheduled = tz.TZDateTime.from(scheduledDate, tz.local);
    } catch (_) {
      // In headless test environments where tz is uninitialized
      return;
    }

    if (tzScheduled.isBefore(now)) {
      debugPrint('Warning: Attempted to schedule notification in the past ($scheduledDate). Skipping.');
      return;
    }

    final details = _buildNotificationDetails(
      channelId ?? 'focusly_general_channel',
      channelName ?? 'Focusly Notifications',
    );

    try {
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
      );
    } catch (e) {
      debugPrint('MobileNotificationSender.scheduleNotification error: $e');
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
      channelId ?? 'focusly_instant_channel',
      channelName ?? 'Focusly Instant Alerts',
    );

    try {
      await _plugin.show(
        id,
        title,
        body,
        details,
        payload: payload,
      );
    } catch (e) {
      debugPrint('MobileNotificationSender.showInstantNotification error: $e');
    }
  }

  @override
  Future<void> cancelNotification(int id) async {
    try {
      await _plugin.cancel(id);
    } catch (e) {
      debugPrint('MobileNotificationSender.cancelNotification error: $e');
    }
  }

  @override
  Future<void> cancelAllNotifications() async {
    try {
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('MobileNotificationSender.cancelAllNotifications error: $e');
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
        icon: '@mipmap/ic_launcher',
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
