import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/auth/auth_provider.dart';
import '../../../core/localization/app_localizations.dart';
import '../helpers/recurrence_helper.dart';
import '../models/event_model.dart';
import '../models/event_type_model.dart';
import '../services/event_notification_service.dart';
import '../../progress/services/progress_service.dart';

/// Available view modes in the Schedule calendar
enum ScheduleViewMode {
  month,
  week,
  day,
}

/// Controller managing the active view mode (Month, Week, Day/Agenda)
class ScheduleViewModeNotifier extends Notifier<ScheduleViewMode> {
  @override
  ScheduleViewMode build() => ScheduleViewMode.month;

  void setMode(ScheduleViewMode mode) {
    state = mode;
  }
}

final scheduleViewModeProvider =
    NotifierProvider<ScheduleViewModeNotifier, ScheduleViewMode>(
  ScheduleViewModeNotifier.new,
);

/// Controller managing the currently selected date in the calendar
class SelectedDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return RecurrenceHelper.normalizeDate(now);
  }

  void selectDate(DateTime date) {
    state = RecurrenceHelper.normalizeDate(date);
  }

  void jumpToToday() {
    state = RecurrenceHelper.normalizeDate(DateTime.now());
  }
}

final selectedDateProvider =
    NotifierProvider<SelectedDateNotifier, DateTime>(
  SelectedDateNotifier.new,
);

/// Controller managing the currently focused month in view navigation
class FocusedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, 1);
  }

  void setMonth(DateTime month) {
    state = DateTime(month.year, month.month, 1);
  }

  void nextMonth() {
    state = DateTime(state.year, state.month + 1, 1);
  }

  void previousMonth() {
    state = DateTime(state.year, state.month - 1, 1);
  }

  void resetToCurrent() {
    final now = DateTime.now();
    state = DateTime(now.year, now.month, 1);
  }
}

final focusedMonthProvider =
    NotifierProvider<FocusedMonthNotifier, DateTime>(
  FocusedMonthNotifier.new,
);

/// Stream of all event types (seeded defaults + custom types stored in Firestore)
///
/// DATA ISOLATION: Watches [currentUserIdProvider] to ensure real-time isolation
/// and instant stream destruction on logout.
final eventTypesStreamProvider = StreamProvider<List<EventType>>((ref) {
  final uid = ref.watch(currentUserIdProvider);

  if (uid == null || uid.isEmpty) {
    return Stream.value(EventType.defaultEventTypes);
  }

  try {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('event_types')
        .snapshots()
        .map((snapshot) {
      final customTypes = snapshot.docs
          .map((doc) => EventType.fromMap(doc.data(), doc.id))
          .toList();

      return [...EventType.defaultEventTypes, ...customTypes];
    }).handleError((_) => EventType.defaultEventTypes);
  } catch (_) {
    return Stream.value(EventType.defaultEventTypes);
  }
});

/// Stream of all raw events for the authenticated user from Firestore
///
/// DATA ISOLATION: Scoped strictly to `users/{uid}/events`. Watching [currentUserIdProvider]
/// guarantees zero calendar event bleed between distinct accounts.
final eventsStreamProvider = StreamProvider<List<EventModel>>((ref) {
  final uid = ref.watch(currentUserIdProvider);

  if (uid == null || uid.isEmpty) {
    return Stream.value(<EventModel>[]);
  }

  try {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('events')
        .orderBy('date', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => EventModel.fromMap(doc.data(), doc.id))
          .toList();
    }).handleError((e) {
      debugPrint('Firestore events stream error: $e');
      return <EventModel>[];
    });
  } catch (_) {
    return Stream.value([]);
  }
});

/// Controller handling Firestore operations and notification scheduling for Schedule Events
class ScheduleController {
  final EventNotificationService _notificationService =
      EventNotificationService();

  String? get _currentUserId {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  CollectionReference<Map<String, dynamic>>? get _eventsCollection {
    final uid = _currentUserId;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('events');
  }

  /// Adds a new calendar event and schedules its notification alerts
  Future<void> addEvent(EventModel event, BuildContext context) async {
    final localizations = AppLocalizations.of(context);
    final col = _eventsCollection;
    if (col == null) return;

    try {
      final docRef = col.doc();
      final newEvent = event.copyWith(id: docRef.id);
      await docRef.set(newEvent.toMap());

      // Schedule notifications for upcoming occurrences
      await _notificationService.scheduleEventNotifications(
        newEvent,
        localizations,
      );

      // Achievement check hook for adding events (1st, 5th, 20th)
      ProgressService().awardXp(0);
    } catch (e) {
      debugPrint('Error adding schedule event: $e');
    }
  }

  /// Updates an existing calendar event and reschedules its alerts
  Future<void> updateEvent(EventModel event, BuildContext context) async {
    final localizations = AppLocalizations.of(context);
    final col = _eventsCollection;
    if (col == null) return;

    try {
      await col.doc(event.id).update(event.toMap());

      // Reschedule notifications
      await _notificationService.scheduleEventNotifications(
        event,
        localizations,
      );
    } catch (e) {
      debugPrint('Error updating schedule event: $e');
    }
  }

  /// Deletes a calendar event and cancels all its scheduled alerts
  Future<void> deleteEvent(EventModel event) async {
    final col = _eventsCollection;
    if (col == null) return;

    try {
      await col.doc(event.id).delete();
      await _notificationService.cancelEventNotifications(event);
    } catch (e) {
      debugPrint('Error deleting schedule event: $e');
    }
  }

  /// Adds a custom user event type to Firestore
  Future<void> addCustomEventType(String name, int colorValue) async {
    final uid = _currentUserId;
    if (uid == null || name.trim().isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('event_types')
          .add({
        'name': name.trim(),
        'colorValue': colorValue,
        'isDefault': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error adding custom event type: $e');
    }
  }

  /// Deletes a custom event type from Firestore
  Future<void> deleteCustomEventType(String typeId) async {
    final uid = _currentUserId;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('event_types')
          .doc(typeId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting custom event type: $e');
    }
  }
}

/// Global provider for Schedule Controller operations
final scheduleControllerProvider = Provider<ScheduleController>((ref) {
  return ScheduleController();
});
