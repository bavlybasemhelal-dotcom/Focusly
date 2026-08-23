import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../../../core/localization/app_localizations.dart';
import '../helpers/recurrence_helper.dart';
import '../models/event_model.dart';

/// Service responsible for scheduling and cancelling local notifications for Schedule calendar events.
///
/// TODO: The upcoming recurrence scheduling window is set to 30 days. This window
/// should be refreshed periodically (e.g. on app launch or date change) to continuously
/// schedule upcoming future occurrences indefinitely without hitting device notification limits.
class EventNotificationService {
  static final EventNotificationService _instance =
      EventNotificationService._internal();
  factory EventNotificationService() => _instance;
  EventNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initializes timezone and local notification plugin
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      tz.initializeTimeZones();

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

      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Event notification tapped: ${response.payload}');
        },
      );

      _isInitialized = true;
    } catch (e) {
      debugPrint('EventNotificationService initialize error: $e');
    }
  }

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
    if (!_isInitialized) {
      await initialize();
    }

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
          final tzScheduled = tz.TZDateTime.from(startDt, tz.local);
          final id = _generateOccurrenceNotificationId(event.id, occ.date);

          await _notificationsPlugin.zonedSchedule(
            id,
            localizations.tr('notification_event_title'),
            '${event.title} • ${event.time.hour.toString().padLeft(2, '0')}:${event.time.minute.toString().padLeft(2, '0')}',
            tzScheduled,
            _buildNotificationDetails('schedule_events', 'Schedule Events'),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            payload: event.id,
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
        await _notificationsPlugin.cancel(id);
        current = current.add(const Duration(days: 1));
      }
    } catch (e) {
      debugPrint('Error cancelling event notifications: $e');
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
