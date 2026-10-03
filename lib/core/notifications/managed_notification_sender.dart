import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'platform_senders/platform_notification_sender.dart';

/// Local schedule registry: stable IDs, quiet hours, cancellation and restart recovery.
/// Scheduled means accepted for scheduling; it does not assert OS delivery.
class ManagedNotificationSender implements PlatformNotificationSender {
  ManagedNotificationSender(
    this.delegate, {
    String? Function()? accountProvider,
  }) : _accountProvider = accountProvider;
  final String? Function()? _accountProvider;
  String? get currentAccount =>
      _accountProvider == null ? uid : _accountProvider();
  final PlatformNotificationSender delegate;
  static String? get uid {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  static int stableId(String key) {
    final bytes = sha256.convert(utf8.encode(key)).bytes;
    return ((bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3]) &
        0x7fffffff;
  }

  static Future<Map<String, dynamic>> settings(String uid) async {
    final raw = (await SharedPreferences.getInstance()).getString(
      'notification_settings_$uid',
    );
    return raw == null ? {} : Map<String, dynamic>.from(jsonDecode(raw) as Map);
  }

  static Future<void> saveSettings(
    String uid,
    Map<String, dynamic> data,
  ) async => (await SharedPreferences.getInstance()).setString(
    'notification_settings_$uid',
    jsonEncode(data),
  );
  static DateTime applyQuietHours(
    DateTime time,
    Map<String, dynamic> settings,
  ) {
    if (settings['quietEnabled'] != true) return time;
    final start = (settings['quietStart'] as num?)?.toInt() ?? 22;
    final end = (settings['quietEnd'] as num?)?.toInt() ?? 7;
    if (start < 0 || start > 23 || end < 0 || end > 23 || start == end) {
      return time;
    }
    final minute = time.hour * 60 + time.minute;
    final quiet = start < end
        ? minute >= start * 60 && minute < end * 60
        : minute >= start * 60 || minute < end * 60;
    if (!quiet) return time;
    return DateTime(
      time.year,
      time.month,
      time.day + (start > end && minute >= start * 60 ? 1 : 0),
      end,
    );
  }

  @override
  Future<void> initialize() => delegate.initialize();
  @override
  Future<bool> requestPermissions() => delegate.requestPermissions();

  Future<List<Map<String, dynamic>>> pending({String? account}) async {
    final accountId = account ?? currentAccount;
    if (accountId == null) return [];
    final preferences = await SharedPreferences.getInstance();
    final prefix = 'notification_intent_${accountId}_';
    final values = <Map<String, dynamic>>[];
    for (final key in preferences.getKeys().where(
      (key) => key.startsWith(prefix),
    )) {
      final raw = preferences.getString(key);
      if (raw == null) continue;
      try {
        final value = Map<String, dynamic>.from(jsonDecode(raw) as Map);
        final date = DateTime.tryParse(value['date'] as String? ?? '');
        if (date != null && date.isAfter(DateTime.now())) values.add(value);
      } catch (_) {
        await preferences.remove(key);
      }
    }
    values.sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));
    return values;
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
    final account = currentAccount;
    if (account == null) return;
    final configuration = await settings(account);
    if (currentAccount != account) return;
    final date = applyQuietHours(scheduledDate, configuration);
    if (!date.isAfter(DateTime.now())) return;
    final actualId = stableId('$account:$id');
    final preferences = await SharedPreferences.getInstance();
    final data = {
      'id': id,
      'actualId': actualId,
      'uid': account,
      'title': title,
      'body': body,
      'date': date.toIso8601String(),
      'originalDate': scheduledDate.toIso8601String(),
      'payload': payload,
      'channelId': channelId,
      'channelName': channelName,
      'status': 'scheduled',
    };
    if (configuration['enabled'] == false ||
        configuration[channelId] == false) {
      await delegate.cancelNotification(actualId);
      await preferences.setString(
        'notification_intent_${account}_$id',
        jsonEncode({...data, 'status': 'paused'}),
      );
      return;
    }
    await delegate.scheduleNotification(
      id: actualId,
      title: title,
      body: body,
      scheduledDate: date,
      payload: 'account=$account|$payload',
      channelId: channelId,
      channelName: channelName,
    );
    if (currentAccount != account) {
      await delegate.cancelNotification(actualId);
      return;
    }
    await preferences.setString(
      'notification_intent_${account}_$id',
      jsonEncode(data),
    );
  }

  Future<void> restore() async {
    final account = currentAccount;
    if (account == null) return;
    for (final data in await pending(account: account)) {
      if (currentAccount != account) return;
      await scheduleNotification(
        id: data['id'] as int,
        title: data['title'] as String,
        body: data['body'] as String,
        scheduledDate: DateTime.parse(
          (data['originalDate'] ?? data['date']) as String,
        ),
        payload: data['payload'] as String?,
        channelId: data['channelId'] as String?,
        channelName: data['channelName'] as String?,
      );
    }
  }

  Future<void> updateSettings(
    String account,
    Map<String, dynamic> configuration,
  ) async {
    if (currentAccount != account) return;
    await saveSettings(account, configuration);
    for (final data in await pending(account: account)) {
      if (currentAccount != account) return;
      await delegate.cancelNotification(data['actualId'] as int);
    }
    await restore();
  }

  Future<void> cancelSource(String payload) async {
    for (final data in await pending()) {
      if (data['payload'] == payload) {
        await cancelNotification(data['id'] as int);
      }
    }
  }

  Future<void> snooze(int id, Duration duration) async {
    final list = await pending();
    final data = list.where((data) => data['id'] == id).firstOrNull;
    if (data == null) throw StateError('Reminder no longer exists');
    if (duration.inMinutes < 1 || duration > const Duration(days: 31)) {
      throw ArgumentError('Choose a future reminder within 30 days');
    }
    await scheduleNotification(
      id: id,
      title: data['title'] as String,
      body: data['body'] as String,
      scheduledDate: DateTime.now().add(duration),
      payload: data['payload'] as String?,
      channelId: data['channelId'] as String?,
      channelName: data['channelName'] as String?,
    );
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
    final account = currentAccount;
    if (account == null) return;
    final configuration = await settings(account);
    if (currentAccount != account ||
        configuration['enabled'] == false ||
        configuration[channelId] == false) {
      return;
    }
    if (applyQuietHours(
      DateTime.now(),
      configuration,
    ).isAfter(DateTime.now())) {
      return;
    }
    await delegate.showInstantNotification(
      id: stableId('$account:$id'),
      title: title,
      body: body,
      payload: 'account=$account|$payload',
      channelId: channelId,
      channelName: channelName,
    );
  }

  @override
  Future<void> cancelNotification(int id) async {
    final account = currentAccount;
    if (account == null) return;
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString('notification_intent_${account}_$id');
    final actual = raw == null
        ? stableId('$account:$id')
        : (jsonDecode(raw) as Map)['actualId'] as int;
    await delegate.cancelNotification(actual);
    await preferences.remove('notification_intent_${account}_$id');
  }

  @override
  Future<void> cancelAllNotifications() async {
    await delegate.cancelAllNotifications();
    // Logout/mute cancels native delivery while preserving account-scoped intent.
    // Restore re-registers only the account that actually signs in.
  }
}
