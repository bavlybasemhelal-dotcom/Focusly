// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/foundation.dart';

/// Browser HTML5 Notification API implementation for Web builds.
class WebNotificationInterop {
  static bool isSupported() {
    return html.Notification.supported;
  }

  static Future<bool> requestPermission() async {
    try {
      if (!html.Notification.supported) return false;
      final permission = await html.Notification.requestPermission();
      return permission == 'granted';
    } catch (e) {
      debugPrint('WebNotificationInterop.requestPermission error: $e');
      return false;
    }
  }

  static void showNotification({
    required String title,
    required String body,
    String? icon,
    String? tag,
  }) {
    try {
      if (!html.Notification.supported) return;
      if (html.Notification.permission == 'granted') {
        html.Notification(
          title,
          body: body,
          icon: icon ?? 'icons/Icon-192.png',
          tag: tag,
        );
      }
    } catch (e) {
      debugPrint('WebNotificationInterop.showNotification error: $e');
    }
  }
}
