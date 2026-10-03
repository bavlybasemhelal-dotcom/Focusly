class DesktopBridge {
  static bool get available => false;
  static Future<Map<String, dynamic>> request(
    String operation, [
    Map<String, dynamic> args = const {},
  ]) async => {};
  static void subscribe(void Function(String) callback) {}
}
