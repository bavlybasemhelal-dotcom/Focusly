import 'package:flutter/foundation.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/notifications/platform_senders/platform_notification_sender.dart';
import '../../../core/services/notification_init_service.dart';
import '../../notifications/services/notification_logger.dart';
import '../helpers/recurrence_helper.dart';
import '../models/event_model.dart';

/// Service responsible for scheduling and cancelling local notifications for Schedule calendar events.
///
/// Uses [PlatformNotificationSender] to deliver alerts across Mobile (Android/iOS), Web, and Desktop.
class EventNotificationService {
  static final EventNotificationService _instance =
      EventNotificationService._internal();
  factory EventNotificationService() => _instance;
  EventNotificationService._internal();

  PlatformNotificationSender get _platformSender =>
      NotificationInitService.platformSender;

  /// Generates a stable unique notification ID from an event ID and occurrence date
  int _generateOccurrenceNotificationId(String eventId, DateTime occurrenceDate) {
    final normalized = RecurrenceHelper.normalizeDate(occurrenceDate);
    return (eventId.hashCode ^ (normalized.millisecondsSinceEpoch ~/ 1000)).abs() &
        0x7FFFFFFF;
  }

  /// Schedules local notification alerts for an event (including next 30 days of recurring occurrences)
  Future<void> scheduleEventNotifications(
    EventModel event,
    AppLocalizations localizations,
  ) async {
    await NotificationInitService.initializeAppNotifications();
    await NotificationInitService.requestPermissions();

    // First cancel existing scheduled slots for this event
    await cancelEventNotifications(event);

    final now = DateTime.now();
    final windowEnd = now.add(const Duration(days: 30));

    // Expand occurrences from today up to next 30 days
    final occurrences = RecurrenceHelper.expandEventsForDateRange(
      [event],
      now.subtract(const Duration(days: 1)),
      windowEnd,
    );

    for (final occ in occurrences) {
      final startDt = occ.startDateTime;
      if (startDt.isAfter(now)) {
        try {
          final id = _generateOccurrenceNotificationId(event.id, occ.date);
          final title = localizations.tr('notification_event_title');
          final body =
              '${event.title} • ${event.time.hour.toString().padLeft(2, '0')}:${event.time.minute.toString().padLeft(2, '0')}';

          await _platformSender.scheduleNotification(
            id: id,
            title: title,
            body: body,
            scheduledDate: startDt,
            channelId: 'schedule_events',
            channelName: 'Schedule Events',
            payload: event.id,
          );

          // Log in in-app notification history
          await NotificationLogger.logNotification(
            title: title,
            body: body,
            type: 'event_reminder',
            relatedId: event.id,
          );
        } catch (e) {
          debugPrint('Error scheduling event notification: $e');
        }
      }
    }
  }

  /// Cancels all scheduled notifications for an event across the 30-day window
  Future<void> cancelEventNotifications(EventModel event) async {
    try {
      final now = DateTime.now();
      final windowEnd = now.add(const Duration(days: 35));

      DateTime current = event.date;
      while (!current.isAfter(windowEnd)) {
        final id = _generateOccurrenceNotificationId(event.id, current);
        await _platformSender.cancelNotification(id);
        current = current.add(const Duration(days: 1));
      }
    } catch (e) {
      debugPrint('Error cancelling event notifications: $e');
    }
  }
}
