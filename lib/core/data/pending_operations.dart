import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persist before executing, then acknowledge only after all effects succeed.
/// Account-scoped keys prevent work from following a user into another session.
class PendingOperations {
  static String key(String uid, String kind, String id) =>
      'pending_operation_${uid}_${sha256.convert(utf8.encode('$kind:$id'))}';
  static Future<void> enqueue(
    String uid,
    String kind,
    String id,
    Map<String, dynamic> payload,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storageKey = key(uid, kind, id);
      if (prefs.containsKey(storageKey)) return;
      await prefs.setString(
        storageKey,
        jsonEncode({
          'uid': uid,
          'kind': kind,
          'id': id,
          'payload': payload,
          'attempts': 0,
          'queuedAt': DateTime.now().toIso8601String(),
        }),
      );
    } on MissingPluginException {
      /* Headless service tests have no platform store. */
    }
  }

  static Future<List<Map<String, dynamic>>> list(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final prefix = 'pending_operation_${uid}_';
      final result = <Map<String, dynamic>>[];
      for (final key in prefs.getKeys().where(
        (key) => key.startsWith(prefix),
      )) {
        final raw = prefs.getString(key);
        if (raw == null) continue;
        try {
          result.add({
            ...Map<String, dynamic>.from(jsonDecode(raw) as Map),
            'key': key,
          });
        } catch (_) {
          await prefs.remove(key);
        }
      }
      result.sort(
        (a, b) => (a['queuedAt'] as String).compareTo(b['queuedAt'] as String),
      );
      return result;
    } on MissingPluginException {
      return [];
    }
  }

  static Future<void> acknowledge(String uid, String kind, String id) async {
    try {
      await (await SharedPreferences.getInstance()).remove(key(uid, kind, id));
    } on MissingPluginException {
      /* Headless tests. */
    }
  }

  static Future<void> failed(Map<String, dynamic> job, Object error) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      job['key'] as String,
      jsonEncode({
        ...job,
        'attempts': ((job['attempts'] as num?)?.toInt() ?? 0) + 1,
        'lastError': error.toString(),
        'lastAttempt': DateTime.now().toIso8601String(),
      }),
    );
  }

  static Future<void> clearAccount(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith('pending_operation_${uid}_') ||
          key.startsWith('notification_intent_${uid}_') ||
          key.startsWith('group_last_viewed_${uid}_') ||
          key.endsWith('_$uid')) {
        await prefs.remove(key);
      }
    }
  }
}
