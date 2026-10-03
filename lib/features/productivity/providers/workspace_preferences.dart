import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/auth/auth_provider.dart';

class WorkspacePreferences extends Notifier<Map<String, dynamic>> {
  int generation = 0;
  final Map<String, dynamic> editsDuringLoad = {};
  Future<void>? loading;
  Future<void> writes = Future.value();
  @override
  Map<String, dynamic> build() {
    final uid = ref.watch(currentUserIdProvider);
    final version = ++generation;
    editsDuringLoad.clear();
    loading = uid == null ? null : _load(uid, version);
    return {};
  }

  Future<void> _load(String uid, int version) async {
    try {
      final raw = (await SharedPreferences.getInstance()).getString(
        'workspace_preferences_$uid',
      );
      if (raw != null && ref.mounted && generation == version) {
        state = {
          ...Map<String, dynamic>.from(jsonDecode(raw) as Map),
          ...editsDuringLoad,
        };
      }
    } catch (_) {}
  }

  Future<void> set(String key, dynamic value) {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return Future.value();
    editsDuringLoad[key] = value;
    state = {...state, key: value};
    final version = generation;
    final currentLoad = loading;
    final write = writes.catchError((Object _) {}).then((_) async {
      await currentLoad;
      if (!ref.mounted ||
          generation != version ||
          ref.read(currentUserIdProvider) != uid) {
        return;
      }
      final encoded = jsonEncode(state);
      await (await SharedPreferences.getInstance()).setString(
        'workspace_preferences_$uid',
        encoded,
      );
    });
    writes = write;
    return write;
  }
}

final workspacePreferencesProvider =
    NotifierProvider<WorkspacePreferences, Map<String, dynamic>>(
      WorkspacePreferences.new,
    );
bool moduleVisible(Map<String, dynamic> settings, String module) =>
    !(settings['hiddenModules'] as List? ?? []).contains(module);
