import 'dart:io';
import '../windows_schedule.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';
import 'platform_notification_sender.dart';

/// Desktop implementation of [PlatformNotificationSender] for Windows, macOS, and Linux.
///
/// Uses `local_notifier` to trigger native OS-level Toast notifications
/// in the Windows Action Center, macOS Notification Center, and Linux Desktop environments.
///
/// -----------------------------------------------------------------------------------------
/// ARCHITECTURAL NOTE FOR MAINTAINERS & BEGINNER DEVELOPERS:
/// -----------------------------------------------------------------------------------------
/// 1. Active Process Scheduling:
///    While Focusly is open (or minimized to taskbar/tray), future notifications are managed
///    via an active Dart [Timer] queue keyed by notification ID.
///
/// 2. TODO: Terminated App Background Notifications on Desktop:
///    If the desktop application process is completely closed/killed by the user or OS,
///    in-memory timers will not run. Achieving scheduled alert delivery with a fully closed
///    desktop app requires registering a background helper service (e.g. Windows Background
///    Task, macOS launchd daemon, or Linux systemd user service).
class DesktopNotificationSender implements PlatformNotificationSender {
  static final DesktopNotificationSender _instance =
      DesktopNotificationSender._internal();
  factory DesktopNotificationSender() => _instance;
  DesktopNotificationSender._internal();

  final Map<int, Timer> _activeTimers = {};
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      await localNotifier.setup(
        appName: 'Focusly',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      _initialized = true;
      debugPrint('Desktop local_notifier initialized successfully.');
    } catch (e) {
      debugPrint('DesktopNotificationSender.initialize error: $e');
    }
  }

  @override
  Future<bool> requestPermissions() async {
    // Desktop platforms (Windows, macOS, Linux) typically permit local notifications
    // without runtime modal prompts, though macOS may prompt on first launch.
    await initialize();
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

    if (Platform.isWindows) {
      await WindowsSchedule.request({
        'action': 'schedule',
        'id': id,
        'title': title,
        'body': body,
        'date': scheduledDate.toIso8601String(),
        'payload': payload,
      });
      return;
    }
    // Cancel existing timer for this ID if scheduled previously
    await cancelNotification(id);

    final now = DateTime.now();
    final durationUntilTrigger = scheduledDate.difference(now);

    if (durationUntilTrigger.isNegative) {
      debugPrint(
        'Warning: Scheduled desktop date $scheduledDate has already passed. Skipping.',
      );
      return;
    }

    debugPrint(
      'Desktop notification #$id scheduled in ${durationUntilTrigger.inSeconds}s (at $scheduledDate)',
    );

    // Schedule active in-process timer
    _activeTimers[id] = Timer(durationUntilTrigger, () async {
      await showInstantNotification(
        id: id,
        title: title,
        body: body,
        payload: payload,
      );
      _activeTimers.remove(id);
    });
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

    try {
      final notification = LocalNotification(
        identifier: id.toString(),
        title: title,
        body: body,
        actions: [LocalNotificationAction(text: 'Open Focusly')],
      );

      notification.onShow = () {
        debugPrint('Desktop Notification displayed in OS tray/center: #$id');
      };

      notification.onClick = () {
        debugPrint('Desktop Notification clicked: #$id with payload: $payload');
      };

      await notification.show();
    } catch (e) {
      debugPrint('DesktopNotificationSender.showInstantNotification error: $e');
    }
  }

  @override
  Future<void> cancelNotification(int id) async {
    if (Platform.isWindows) {
      await WindowsSchedule.request({'action': 'cancel', 'id': id});
    }
    _activeTimers[id]?.cancel();
    _activeTimers.remove(id);
  }

  @override
  Future<void> cancelAllNotifications() async {
    if (Platform.isWindows) {
      await WindowsSchedule.request({'action': 'cancelAll'});
    }
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
  }
}
