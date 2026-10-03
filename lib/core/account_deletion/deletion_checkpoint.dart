import 'package:shared_preferences/shared_preferences.dart';

/// Survives root-profile deletion when Firebase Auth requires another attempt.
class DeletionCheckpoint {
  static Future<bool> pending(String uid) async {
    try {
      return (await SharedPreferences.getInstance()).getBool(
            'deletion_pending_$uid',
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> set(String uid, bool pending) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      if (pending) {
        await preferences.setBool('deletion_pending_$uid', true);
      } else {
        await preferences.remove('deletion_pending_$uid');
      }
    } catch (_) {
      /* Firestore's deletion marker remains authoritative until root deletion. */
    }
  }
}
