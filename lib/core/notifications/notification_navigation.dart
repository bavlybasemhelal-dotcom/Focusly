class NotificationNavigation {
  static void Function(String)? onOpen;
  static String? pending;
  static void open(String? payload) {
    if (payload == null || payload.isEmpty) return;
    if (onOpen == null) {
      pending = payload;
    } else {
      onOpen!(payload);
    }
  }
}
