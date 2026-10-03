import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:flutter/foundation.dart';

@JS('Notification')
extension type _BrowserNotification._(JSObject _) implements JSObject {
  external factory _BrowserNotification(JSString title, JSObject options);
  external static JSString get permission;
  external static JSPromise<JSString> requestPermission();
}

/// Browser HTML5 Notification API implementation for Web builds.
class WebNotificationInterop {
  static bool isSupported() {
    return globalContext.has('Notification');
  }

  static Future<bool> requestPermission() async {
    try {
      if (!isSupported()) return false;
      final permission = await _BrowserNotification.requestPermission().toDart;
      return permission.toDart == 'granted';
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
      if (!isSupported()) return;
      if (_BrowserNotification.permission.toDart == 'granted') {
        _BrowserNotification(
          title.toJS,
          {
                'body': body,
                'icon': icon ?? 'icons/Icon-192.png',
                'tag': ?tag,
              }.jsify()
              as JSObject,
        );
      }
    } catch (e) {
      debugPrint('WebNotificationInterop.showNotification error: $e');
    }
  }
}
