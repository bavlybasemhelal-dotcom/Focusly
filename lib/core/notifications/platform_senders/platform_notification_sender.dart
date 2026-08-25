import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'desktop_notification_sender.dart';
import 'mobile_notification_sender.dart';
import 'web_notification_sender.dart';

/// Common abstraction for delivering OS-level system tray and notification center
/// alerts across Mobile (Android/iOS), Web (Browser Notification API), and Desktop (Windows/macOS/Linux).
///
/// NOTE FOR BEGINNER MAINTAINERS:
/// Each platform has different capabilities and security constraints:
/// - Mobile (Android/iOS): Uses `flutter_local_notifications` with system alarm services
///   (WorkManager/AlarmManager/APNs) to wake up and fire even if the app is backgrounded.
/// - Web: Uses the browser's native JavaScript `Notification` API with an in-app timer queue.
///   (Fires while the browser tab is active. Closed-tab background firing requires Web Push + Service Worker).
/// - Desktop (Windows/macOS/Linux): Uses `local_notifier` with a process timer queue.
///   (Fires while the desktop app process is running. Terminated-app firing requires an OS background service daemon).
abstract class PlatformNotificationSender {
  /// Initializes any platform-specific notification plugins or channels.
  Future<void> initialize();

  /// Requests runtime notification permissions from the user/browser.
  Future<bool> requestPermissions();

  /// Schedules a notification to fire at [scheduledDate].
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    String? channelId,
    String? channelName,
  });

  /// Displays an instant notification immediately.
  Future<void> showInstantNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? channelId,
    String? channelName,
  });

  /// Cancels a specific scheduled notification by ID.
  Future<void> cancelNotification(int id);

  /// Cancels all active scheduled notifications.
  Future<void> cancelAllNotifications();

  /// Factory creator returning the appropriate platform-specific implementation.
  static PlatformNotificationSender create() {
    if (kIsWeb) {
      return WebNotificationSender();
    }
    try {
      if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
        return DesktopNotificationSender();
      }
    } catch (_) {
      // Fallback for web or non-standard environments where Platform getters throw
    }
    return MobileNotificationSender();
  }
}
