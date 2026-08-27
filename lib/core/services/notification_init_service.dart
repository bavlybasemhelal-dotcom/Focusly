import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../notifications/platform_senders/platform_notification_sender.dart';
import '../../features/notifications/services/notification_logger.dart';

/// Centralized Cross-Platform Notification and Timezone Service.
///
/// Dispatches notification operations to the appropriate platform sender:
/// - Mobile (Android/iOS): flutter_local_notifications with timezone exact alarms.
/// - Web: Native Browser Notification API + active tab timer queue.
/// - Desktop (Windows/macOS/Linux): local_notifier + process timer queue.
class NotificationInitService {
  static final PlatformNotificationSender _platformSender =
      PlatformNotificationSender.create();

  static PlatformNotificationSender get platformSender => _platformSender;

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static FlutterLocalNotificationsPlugin get plugin => _notificationsPlugin;

  static bool _isInitialized = false;

  /// Global initialization invoked in `main()` before `runApp()`
  static Future<void> initializeAppNotifications() async {
    if (_isInitialized) return;

    try {
      // 1. Initialize timezone database (required for mobile exact alarms)
      tz.initializeTimeZones();

      // 2. Resolve device's actual native IANA timezone
      if (!kIsWeb) {
        try {
          final String timeZoneName = await FlutterTimezone.getLocalTimezone();
          tz.setLocalLocation(tz.getLocation(timeZoneName));
          debugPrint('Focusly Timezone initialized: $timeZoneName');
        } catch (e) {
          debugPrint('Warning: Could not get device timezone ($e), fallback to UTC/local offset.');
        }
      }

      // 3. Initialize Platform Notification Sender (Mobile / Web / Desktop)
      await _platformSender.initialize();

      _isInitialized = true;
    } catch (e) {
      debugPrint('NotificationInitService initialization error: $e');
    }
  }

  /// Requests runtime notification permissions from user / browser.
  static Future<bool> requestPermissions() async {
    return await _platformSender.requestPermissions();
  }

  /// Sends an instant verification notification immediately across any platform.
  static Future<void> sendInstantTestNotification() async {
    await requestPermissions();

    const testId = 777778;
    const title = '🔔 Focusly Instant Notification';
    const body = 'Your notification channel and heads-up banner are active and working!';

    await _platformSender.showInstantNotification(
      id: testId,
      title: title,
      body: body,
      channelId: 'focusly_diagnostic_channel',
      channelName: 'Diagnostic Test Alerts',
      payload: 'diagnostic_instant_test',
    );

    await NotificationLogger.logNotification(
      title: title,
      body: body,
      type: 'system',
      relatedId: 'diagnostic_instant_test',
    );
  }

  /// Schedules a test notification 10 seconds into the future across any platform.
  static Future<void> scheduleTestNotification({int seconds = 10}) async {
    await requestPermissions();

    final now = DateTime.now();
    final scheduledDate = now.add(Duration(seconds: seconds));

    const testId = 777777;
    const title = '🔔 Focusly Scheduled Notification';
    const body = 'Your scheduled notification pipeline is working perfectly!';

    await _platformSender.scheduleNotification(
      id: testId,
      title: title,
      body: body,
      scheduledDate: scheduledDate,
      channelId: 'focusly_diagnostic_channel',
      channelName: 'Diagnostic Test Alerts',
      payload: 'diagnostic_test',
    );

    // Also log this notification to in-app history
    await NotificationLogger.logNotification(
      title: title,
      body: body,
      type: 'system',
      relatedId: 'diagnostic_test',
      isScheduled: true,
      scheduledFor: scheduledDate,
    );
  }
}
