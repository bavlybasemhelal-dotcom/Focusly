/// Stub implementation of WebNotificationInterop for non-web platforms / VM tests.
class WebNotificationInterop {
  static bool isSupported() => false;

  static Future<bool> requestPermission() async => true;

  static void showNotification({
    required String title,
    required String body,
    String? icon,
    String? tag,
  }) {}
}
