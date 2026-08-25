import 'dart:async';
import 'package:flutter/foundation.dart';
import 'platform_notification_sender.dart';
import 'web_notification_interop.dart'
    if (dart.library.html) 'web_notification_interop_html.dart';

/// Web implementation of [PlatformNotificationSender] using the browser's native HTML5 Notification API.
///
/// -----------------------------------------------------------------------------------------
/// ARCHITECTURAL NOTE FOR MAINTAINERS & BEGINNER DEVELOPERS:
/// -----------------------------------------------------------------------------------------
/// 1. Active Tab Scheduling:
///    While the web page/tab is open, upcoming reminders are scheduled using in-memory [Timer]s
///    that trigger browser desktop/system tray notifications via `new Notification(...)`.
///
/// 2. TODO: True Background Web Notifications (When browser tab is closed):
///    Plain web apps cannot execute code or timers when the tab is completely closed.
///    Delivering notifications with a closed browser tab requires:
///    - Registering a Service Worker (`sw.js`).
///    - Subscribing to Web Push notifications (`PushManager.subscribe()`).
///    - Sending push messages via a backend server (e.g. Firebase Cloud Messaging / Web Push protocol).
class WebNotificationSender implements PlatformNotificationSender {
  static final WebNotificationSender _instance =
      WebNotificationSender._internal();
  factory WebNotificationSender() => _instance;
  WebNotificationSender._internal();

  final Map<int, Timer> _activeTimers = {};
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    _initialized = true;
  }

  @override
  Future<bool> requestPermissions() async {
    return await WebNotificationInterop.requestPermission();
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
    await cancelNotification(id);

    final now = DateTime.now();
    final duration = scheduledDate.difference(now);

    if (duration.isNegative) {
      debugPrint('Warning: Web notification #$id scheduled date in the past ($scheduledDate). Skipping.');
      return;
    }

    debugPrint('Web notification #$id scheduled in ${duration.inSeconds}s (at $scheduledDate)');

    _activeTimers[id] = Timer(duration, () async {
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
    WebNotificationInterop.showNotification(
      title: title,
      body: body,
      tag: id.toString(),
    );
  }

  @override
  Future<void> cancelNotification(int id) async {
    _activeTimers[id]?.cancel();
    _activeTimers.remove(id);
  }

  @override
  Future<void> cancelAllNotifications() async {
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
  }
}
