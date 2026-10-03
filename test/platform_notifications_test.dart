import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/notifications/platform_senders/desktop_notification_sender.dart';
import 'package:focusly/core/notifications/platform_senders/mobile_notification_sender.dart';
import 'package:focusly/core/notifications/platform_senders/platform_notification_sender.dart';
import 'package:focusly/core/notifications/platform_senders/web_notification_sender.dart';
import 'package:focusly/core/services/notification_init_service.dart';
import 'package:focusly/features/habits/models/habit_model.dart';
import 'package:focusly/features/habits/services/habit_notification_service.dart';
import 'package:focusly/features/pomodoro/services/pomodoro_notification_service.dart';
import 'package:focusly/features/schedule/models/event_model.dart';
import 'package:focusly/features/schedule/services/event_notification_service.dart';
import 'package:focusly/features/tasks/models/task_model.dart';
import 'package:focusly/features/tasks/services/task_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlatformNotificationSender Architecture Tests', () {
    test('PlatformNotificationSender.create() returns non-null sender', () {
      final sender = PlatformNotificationSender.create();
      expect(sender, isNotNull);
      expect(sender, isA<PlatformNotificationSender>());
    });

    test(
      'MobileNotificationSender initializes and handles schedule calls safely',
      () async {
        final sender = MobileNotificationSender();
        await sender.initialize();
        final hasPermission = await sender.requestPermissions();
        expect(hasPermission, isA<bool>());

        // Attempt schedule in past (safely ignored)
        await sender.scheduleNotification(
          id: 101,
          title: 'Past Alert',
          body: 'Should not crash',
          scheduledDate: DateTime.now().subtract(const Duration(hours: 1)),
        );

        // Cancel notification
        await sender.cancelNotification(101);
        await sender.cancelAllNotifications();
      },
    );

    test('DesktopNotificationSender manages in-process timer queue', () async {
      final sender = DesktopNotificationSender();
      await sender.initialize();
      final hasPermission = await sender.requestPermissions();
      expect(hasPermission, isTrue);

      // Schedule notification in future
      final futureDate = DateTime.now().add(const Duration(minutes: 10));
      await sender.scheduleNotification(
        id: 201,
        title: 'Desktop Reminder',
        body: 'Test body',
        scheduledDate: futureDate,
      );

      // Cancel notification
      await sender.cancelNotification(201);
      await sender.cancelAllNotifications();
    });

    test('WebNotificationSender manages active tab timer queue', () async {
      final sender = WebNotificationSender();
      await sender.initialize();
      final hasPermission = await sender.requestPermissions();
      expect(hasPermission, isA<bool>());

      // Schedule notification in future
      final futureDate = DateTime.now().add(const Duration(minutes: 5));
      await sender.scheduleNotification(
        id: 301,
        title: 'Web Reminder',
        body: 'Test body',
        scheduledDate: futureDate,
      );

      // Cancel notification
      await sender.cancelNotification(301);
      await sender.cancelAllNotifications();
    });
  });

  group('Feature Notification Services Integration Tests', () {
    final localizations = AppLocalizations(const Locale('en'));

    test(
      'TaskNotificationService schedules without crashing across platforms',
      () async {
        final service = TaskNotificationService();
        final task = TaskModel(
          id: 'task_test_1',
          title: 'Complete System Architecture Review',
          categoryId: 'work_cat',
          date: DateTime.now().add(const Duration(days: 1)),
          time: const TimeOfDay(hour: 14, minute: 30),
          deadline: DateTime.now().add(const Duration(days: 2)),
          createdAt: DateTime.now(),
        );

        await service.scheduleTaskNotifications(task, localizations);
        await service.cancelTaskNotifications(task.id);
      },
    );

    test(
      'EventNotificationService schedules recurring window without crashing',
      () async {
        final service = EventNotificationService();
        final event = EventModel(
          id: 'event_test_1',
          title: 'Weekly Team Sync',
          date: DateTime.now().add(const Duration(days: 1)),
          time: const TimeOfDay(hour: 10, minute: 0),
          typeId: 'work',
          createdAt: DateTime.now(),
        );

        await service.scheduleEventNotifications(event, localizations);
        await service.cancelEventNotifications(event);
      },
    );

    test('HabitNotificationService schedules daily reminder', () async {
      final service = HabitNotificationService();
      final habit = HabitModel.create(
        id: 'habit_test_1',
        title: 'Read 20 pages',
        time: const TimeOfDay(hour: 20, minute: 0),
      );

      await service.scheduleHabitReminder(
        habit: habit,
        notificationTitle: 'Daily Habit Reminder',
      );
      await service.cancelHabitReminder(habit.id);
    });

    test('PomodoroNotificationService schedules phase completion', () async {
      final service = PomodoroNotificationService();
      final endTime = DateTime.now().add(const Duration(minutes: 25));

      await service.schedulePhaseCompletion(
        targetEndTime: endTime,
        title: 'Focus Sprint Completed',
        body: 'Time for a 5-minute break!',
      );
      await service.cancelPendingNotification();
    });

    test(
      'NotificationInitService.scheduleTestNotification executes cleanly',
      () async {
        await NotificationInitService.scheduleTestNotification(seconds: 10);
      },
    );
  });
}
