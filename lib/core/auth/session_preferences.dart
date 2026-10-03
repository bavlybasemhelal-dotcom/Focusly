import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SessionPreferences {
  static const _rememberKey = 'remember_session';
  static Future<void> setRemember(bool remember) async {
    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(
        remember ? Persistence.LOCAL : Persistence.SESSION,
      );
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_rememberKey, remember);
  }

  static Future<bool> prepareStartup() async {
    final preferences = await SharedPreferences.getInstance();
    if (!kIsWeb && preferences.getBool(_rememberKey) == false) {
      await FirebaseAuth.instance.signOut();
    }
    final firstLaunch = preferences.getBool('onboarding_seen') != true;
    return firstLaunch;
  }

  static Future<void> completeOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('onboarding_seen', true);
  }
}
