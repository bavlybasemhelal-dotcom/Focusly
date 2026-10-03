import 'dart:convert';
import 'dart:js_interop';

@JS('globalThis.FocuslyDesktop')
external JSAny? get _desktop;
@JS('FocuslyDesktop.request')
external JSPromise<JSString> _request(JSString operation, JSString arguments);
@JS('FocuslyDesktop.subscribe')
external void _subscribe(JSFunction callback);

class DesktopBridge {
  static bool get available => _desktop != null;
  static Future<Map<String, dynamic>> request(
    String operation, [
    Map<String, dynamic> args = const {},
  ]) async {
    if (!available) return {};
    final value = await _request(operation.toJS, jsonEncode(args).toJS).toDart;
    return Map<String, dynamic>.from(jsonDecode(value.toDart) as Map);
  }

  static void subscribe(void Function(String) callback) {
    if (available) {
      _subscribe(
        ((JSString value) {
          callback(value.toDart);
        }).toJS,
      );
    }
  }
}
