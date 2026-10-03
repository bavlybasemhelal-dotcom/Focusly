import '../../../core/notifications/platform_senders/mobile_notification_sender.dart';
import '../../../core/notifications/managed_notification_sender.dart';
import '../../../core/data/completion_ledger.dart';
import '../../../core/notifications/platform_senders/platform_notification_sender.dart';
import '../../../core/services/notification_init_service.dart';
import '../models/habit_model.dart';

/// Service responsible for managing local notifications for daily Habits in Focusly.
///
/// Schedules daily-repeating alerts at the habit's configured reminder time
/// using [PlatformNotificationSender] across Mobile, Web, and Desktop.
class HabitNotificationService {
  static final HabitNotificationService _instance =
      HabitNotificationService._internal();
  factory HabitNotificationService() => _instance;
  HabitNotificationService._internal();

  PlatformNotificationSender get _platformSender =>
      NotificationInitService.platformSender;

  /// Generates a stable 32-bit positive integer ID for the habit notification
  static int getNotificationId(String habitId) {
    return ManagedNotificationSender.stableId('habit:$habitId');
  }

  /// Schedules or reschedules a daily recurring notification for a habit
  Future<void> scheduleHabitReminder({
    required HabitModel habit,
    required String notificationTitle,
    String? uid,
  }) async {
    final account = uid ?? ManagedNotificationSender.uid;
    if (account == null || ManagedNotificationSender.uid != account) return;
    if (habit.time == null) {
      await cancelHabitReminder(habit.id);
      return;
    }

    try {
      await NotificationInitService.initializeAppNotifications();
      await NotificationInitService.requestPermissions();

      if (ManagedNotificationSender.uid != account) return;
      await cancelHabitReminder(habit.id);
      final now = DateTime.now();
      final mobile =
          NotificationInitService.platformSender.delegate
              is MobileNotificationSender;
      final daily = mobile && habit.weekdays.length == 7;
      final first =
          DateTime(
            now.year,
            now.month,
            now.day,
            habit.time!.hour,
            habit.time!.minute,
          ).isAfter(now)
          ? 0
          : 1;
      for (var day = first; day < first + (daily ? 1 : 30); day++) {
        if (ManagedNotificationSender.uid != account) return;
        final scheduledDate = DateTime(
          now.year,
          now.month,
          now.day + day,
          habit.time!.hour,
          habit.time!.minute,
        );
        if (!scheduledDate.isAfter(now) ||
            !habit.weekdays.contains(scheduledDate.weekday)) {
          continue;
        }
        final id = ManagedNotificationSender.stableId(
          'habit:${habit.id}:${CompletionLedger.dateKey(scheduledDate)}',
        );
        await _platformSender.scheduleNotification(
          id: id,
          title: notificationTitle,
          body: habit.title,
          scheduledDate: scheduledDate,
          channelId: daily ? 'focusly_habits_daily' : 'focusly_habits_channel',
          channelName: 'Habit Reminders',
          payload: 'habit:${habit.id}',
        );
      }
    } catch (_) {
      // Graceful fallback if device permissions are not yet granted
    }
  }

  /// Cancels any scheduled notification for a given habit ID
  Future<void> cancelHabitReminder(String habitId) async {
    try {
      await NotificationInitService.platformSender.cancelSource(
        'habit:$habitId',
      );
      await _platformSender.cancelNotification(getNotificationId(habitId));
    } catch (_) {}
  }
}
