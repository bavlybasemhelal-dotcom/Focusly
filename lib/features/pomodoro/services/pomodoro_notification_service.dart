import '../../../core/notifications/platform_senders/platform_notification_sender.dart';
import '../../../core/services/notification_init_service.dart';
import '../../notifications/services/notification_logger.dart';

/// Service managing precisely timed local notifications for Pomodoro phase completions.
///
/// Uses [PlatformNotificationSender] to trigger phase-end alerts across Mobile, Web, and Desktop.
class PomodoroNotificationService {
  static final PomodoroNotificationService _instance =
      PomodoroNotificationService._internal();
  factory PomodoroNotificationService() => _instance;
  PomodoroNotificationService._internal();

  static const int pomodoroNotificationId = 999991;

  PlatformNotificationSender get _platformSender =>
      NotificationInitService.platformSender;

  /// Schedules a phase-completion notification at the exact target end timestamp
  Future<void> schedulePhaseCompletion({
    required DateTime targetEndTime,
    required String title,
    required String body,
  }) async {
    try {
      await NotificationInitService.initializeAppNotifications();
      await NotificationInitService.requestPermissions();
      await cancelPendingNotification();

      final now = DateTime.now();
      if (targetEndTime.isBefore(now)) return;

      await _platformSender.scheduleNotification(
        id: pomodoroNotificationId,
        title: title,
        body: body,
        scheduledDate: targetEndTime,
        channelId: 'focusly_pomodoro_channel',
        channelName: 'Pomodoro Focus Timer',
      );

      await NotificationLogger.logNotification(
        title: title,
        body: body,
        type: 'pomodoro',
        isScheduled: true,
        scheduledFor: targetEndTime,
      );
    } catch (_) {}
  }

  /// Cancels any scheduled Pomodoro notification
  Future<void> cancelPendingNotification() async {
    try {
      await _platformSender.cancelNotification(pomodoroNotificationId);
    } catch (_) {}
  }
}
