import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_provider.dart';
import '../localization/app_localizations.dart';
import '../services/notification_init_service.dart';
import '../../features/tasks/providers/tasks_provider.dart';
import '../../features/tasks/services/task_notification_service.dart';
import '../../features/schedule/providers/schedule_provider.dart';
import '../../features/schedule/services/event_notification_service.dart';
import '../../features/habits/providers/habits_provider.dart';
import '../../features/habits/services/habit_notification_service.dart';
import '../../features/energy_mood/providers/energy_mood_provider.dart';
import '../../features/reading_tracker/providers/reading_provider.dart';
import '../../features/goals/providers/goals_provider.dart';
import '../../features/life_score/providers/life_score_provider.dart';
import '../../features/productivity/services/productivity_service.dart';
import 'calendar_clock.dart';
import 'firestore_provider.dart';
import 'completion_ledger.dart';
import 'pending_operations.dart';
import 'pending_operations_processor.dart';
import '../../features/productivity/outbox_page.dart';
import '../../features/contacts/providers/contacts_provider.dart';
import '../../features/contacts/services/contact_reminder_service.dart';

class SessionCoordinator extends ConsumerStatefulWidget {
  const SessionCoordinator({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<SessionCoordinator> createState() => _SessionCoordinatorState();
}

class _SessionCoordinatorState extends ConsumerState<SessionCoordinator> {
  Timer? timer, snapshotTimer;
  bool draining = false, refreshing = false;
  int pending = 0;
  String? lastScore;
  String? get uid => ref.read(currentUserIdProvider);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _start();
    });
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      _drain();
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    snapshotTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    try {
      await NotificationInitService.platformSender.restore();
    } catch (_) {}
    await _drain();
    await _refresh();
  }

  Future<void> _drain({bool manual = false}) async {
    final account = uid;
    if (account == null || draining || !mounted) return;
    draining = true;
    try {
      final db = ref.read(firestoreProvider);
      await PendingOperationsProcessor.drain(
        db,
        account,
        manual: manual,
        stillCurrent: () => mounted && uid == account,
      );
      final count = (await PendingOperations.list(account)).length;
      if (mounted && uid == account && count != pending) {
        setState(() => pending = count);
      }
    } catch (_) {
      /* Keep persisted work for the next retry. */
    } finally {
      draining = false;
    }
  }

  Future<void> _refresh() async {
    final account = uid;
    if (account == null || refreshing || !mounted) return;
    refreshing = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final today = ref.read(calendarClockProvider);
      final day = CompletionLedger.dateKey(today);
      await ProductivityService(
        ref.read(firestoreProvider),
      ).materialize(account, today);
      if (prefs.getString('last_reminder_refresh_$account') == day) return;
      final tasks = await ref.read(tasksStreamProvider.future);
      final habits = await ref.read(habitsStreamProvider.future);
      final events = await ref.read(eventsStreamProvider.future);
      final contacts = await ref.read(contactsStreamProvider.future);
      if (!mounted || uid != account) return;
      await ContactReminderService.refresh(account, contacts);
      if (!mounted || uid != account) return;
      final locale = AppLocalizations.of(context);
      for (final task in tasks) {
        if (!mounted || uid != account) return;
        await TaskNotificationService().scheduleTaskNotifications(
          task,
          locale,
          uid: account,
        );
      }
      for (final habit in habits) {
        if (!mounted || uid != account) return;
        if (habit.time != null) {
          await HabitNotificationService().scheduleHabitReminder(
            habit: habit,
            notificationTitle: locale.tr('notification_habit_title'),
            uid: account,
          );
        }
      }
      for (final event in events) {
        if (!mounted || uid != account) return;
        await EventNotificationService().scheduleEventNotifications(
          event,
          locale,
          uid: account,
        );
      }
      await prefs.setString('last_reminder_refresh_$account', day);
    } catch (_) {
      /* A failed refresh is retried on the next launch/day. */
    } finally {
      refreshing = false;
    }
  }

  void _scheduleSnapshot() {
    snapshotTimer?.cancel();
    snapshotTimer = Timer(const Duration(seconds: 2), () async {
      final account = uid;
      if (!mounted || account == null) return;
      final sources = [
        ref.read(tasksStreamProvider),
        ref.read(habitsStreamProvider),
        ref.read(checkinsHistoryStreamProvider),
        ref.read(booksStreamProvider),
        ref.read(goalsStreamProvider),
      ];
      if (sources.any(
        (value) => !value.hasValue || value.isLoading || value.hasError,
      )) {
        return;
      }
      final score = ref.read(currentLiveLifeScoreProvider);
      final fingerprint = jsonEncode({
        'week': score.weekOf,
        'total': score.total,
        'breakdown': score.breakdown.toMap(),
      });
      if (fingerprint == lastScore) return;
      try {
        await ref.read(lifeScoreServiceProvider).saveSnapshot(account, score);
        if (mounted && uid == account) lastScore = fingerprint;
      } catch (_) {
        /* Never replace a previous snapshot with incomplete data. */
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(calendarClockProvider, (_, _) {
      _refresh();
      _scheduleSnapshot();
    });
    ref.listen(contactsStreamProvider, (_, next) {
      final account = uid;
      if (account != null && next.hasValue) {
        ContactReminderService.refresh(account, next.value!);
      }
    });
    ref.listen(tasksStreamProvider, (_, _) => _scheduleSnapshot());
    ref.listen(habitsStreamProvider, (_, _) => _scheduleSnapshot());
    ref.listen(checkinsHistoryStreamProvider, (_, _) => _scheduleSnapshot());
    ref.listen(booksStreamProvider, (_, _) => _scheduleSnapshot());
    ref.listen(goalsStreamProvider, (_, _) => _scheduleSnapshot());
    return Column(
      children: [
        if (pending > 0)
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: SafeArea(
              bottom: false,
              child: ListTile(
                dense: true,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        OutboxPage(onRetry: () => _drain(manual: true)),
                  ),
                ),
                leading: const Icon(Icons.sync),
                title: Text(
                  Localizations.localeOf(context).languageCode == 'ar'
                      ? '$pending عملية محفوظة محليًا تنتظر المزامنة'
                      : '$pending saved operations await synchronization',
                ),
                trailing: TextButton(
                  onPressed: () => _drain(manual: true),
                  child: Text(context.tr('retry')),
                ),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
