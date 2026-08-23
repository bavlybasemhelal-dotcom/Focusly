import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/contacts/providers/contacts_provider.dart';
import '../../features/energy_mood/providers/energy_mood_provider.dart';
import '../../features/goals/providers/goals_provider.dart';
import '../../features/groups/providers/groups_provider.dart';
import '../../features/gtd/providers/gtd_provider.dart';
import '../../features/habits/providers/habits_provider.dart';
import '../../features/para/providers/para_provider.dart';
import '../../features/pomodoro/providers/pomodoro_provider.dart';
import '../../features/progress/providers/progress_provider.dart';
import '../../features/rituals/providers/rituals_provider.dart';
import '../../features/schedule/providers/schedule_provider.dart';
import '../../features/tasks/providers/tasks_provider.dart';
import '../../features/time_audit/providers/time_audit_provider.dart';
import '../../features/weekly_review/providers/weekly_review_provider.dart';

/// Stream provider for Firebase Auth state changes.
///
/// Whenever a user logs in, logs out, or switches accounts, this stream
/// emits the new [User] (or null) immediately.
final authStateStreamProvider = StreamProvider<User?>((ref) {
  try {
    return FirebaseAuth.instance.authStateChanges();
  } catch (_) {
    return Stream.value(null);
  }
});

/// Reactive Provider exposing the currently authenticated User ID.
///
/// CRITICAL DATA ISOLATION ARCHITECTURE:
/// Every single personal data provider (tasks, events, habits, pomodoro,
/// progress, groups) MUST watch this [currentUserIdProvider].
///
/// When the user logs out (uid becomes null) or logs into a different account
/// (uid changes), Riverpod will automatically:
/// 1. Cancel and tear down the previous user's Firestore stream subscriptions.
/// 2. Clear any cached in-memory state belonging to the previous account.
/// 3. Re-initialize a fresh stream exclusively scoped to the new user's `users/{uid}/...` subcollections.
final currentUserIdProvider = Provider<String?>((ref) {
  final authAsync = ref.watch(authStateStreamProvider);
  if (authAsync.hasValue) {
    return authAsync.value?.uid;
  }
  try {
    return FirebaseAuth.instance.currentUser?.uid;
  } catch (_) {
    return null;
  }
});

/// Reactive Provider exposing the current [User] object (or null if not logged in).
final currentUserProvider = Provider<User?>((ref) {
  final authAsync = ref.watch(authStateStreamProvider);
  if (authAsync.hasValue) {
    return authAsync.value;
  }
  try {
    return FirebaseAuth.instance.currentUser;
  } catch (_) {
    return null;
  }
});

/// Comprehensive session cleanup function to be invoked on user logout.
///
/// This performs an explicit reset of:
/// 1. Firebase Auth session (signs out).
/// 2. All feature Riverpod stream and notifier providers (tasks, schedule, habits,
///    pomodoro, progress, groups).
/// 3. Pomodoro active timer state.
Future<void> logoutAndClearSession(WidgetRef ref) async {
  try {
    // 1. Sign out from Firebase Auth
    await FirebaseAuth.instance.signOut();
  } catch (e) {
    debugPrint('Error signing out from FirebaseAuth: $e');
  }

  // 2. Explicitly invalidate and reset all user-scoped providers to clear in-memory caches
  ref.invalidate(tasksStreamProvider);
  ref.invalidate(categoriesProvider);
  ref.invalidate(eventsStreamProvider);
  ref.invalidate(eventTypesStreamProvider);
  ref.invalidate(habitsStreamProvider);
  ref.invalidate(pomodoroLogsStreamProvider);
  ref.invalidate(userXpStreamProvider);
  ref.invalidate(unlockedAchievementsStreamProvider);
  ref.invalidate(myGroupsStreamProvider);
  ref.invalidate(inboxStreamProvider);
  ref.invalidate(paraAreasStreamProvider);
  ref.invalidate(allParaProjectsStreamProvider);
  ref.invalidate(allParaResourcesStreamProvider);
  ref.invalidate(todayCheckinStreamProvider);
  ref.invalidate(checkinsHistoryStreamProvider);
  ref.invalidate(contactsStreamProvider);
  ref.invalidate(goalsStreamProvider);
  ref.invalidate(timeAuditLogsStreamProvider);
  ref.invalidate(todayRitualStreamProvider);
  ref.invalidate(lastReviewDateStreamProvider);
  ref.invalidate(weeklyReviewsStreamProvider);

  // 3. Reset Pomodoro active timer state if running
  try {
    ref.read(pomodoroTimerProvider.notifier).reset();
  } catch (_) {}
}
