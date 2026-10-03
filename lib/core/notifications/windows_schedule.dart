import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';

/// Windows owns these reminders after registration, including while Focusly is closed.
class WindowsSchedule {
  static Future<void> request(Map<String, dynamic> data) async {
    final directory = Directory(
      '${Platform.environment['LOCALAPPDATA']}\\Focusly\\notifications',
    );
    await directory.create(recursive: true);
    final script = File('${directory.path}\\windows_notifications.ps1');
    final content = await rootBundle.loadString(
      'assets/scripts/windows_notifications.ps1',
    );
    if (!await script.exists() || await script.readAsString() != content) {
      await script.writeAsString(content);
    }
    final encoded = base64Encode(utf8.encode(jsonEncode(data)));
    final result = await Process.run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-WindowStyle',
      'Hidden',
      '-ExecutionPolicy',
      'Bypass',
      '-File',
      script.path,
      '-RequestBase64',
      encoded,
    ]);
    if (result.exitCode != 0) {
      throw StateError('Windows reminder scheduling failed: ${result.stderr}');
    }
  }
}
