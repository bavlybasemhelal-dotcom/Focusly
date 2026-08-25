import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/services/notification_init_service.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/notifications/models/notification_log_model.dart';
import 'package:focusly/features/notifications/notifications_page.dart';
import 'package:focusly/features/notifications/providers/notifications_provider.dart';
import 'package:focusly/features/settings/settings_page.dart';
import 'package:focusly/screens/home_screen.dart';

Widget _buildNotificationsTestApp({
  required Widget home,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: overrides.isEmpty ? const [] : overrides.cast(),
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: home,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationLogModel Unit Tests', () {
    test('Correctly serializes and deserializes fromMap', () {
      final now = DateTime(2026, 8, 25, 14, 30);
      final model = NotificationLogModel(
        id: 'notif_1',
        title: 'Complete Project Review',
        body: 'Due in 1 hour',
        type: 'task_reminder',
        relatedId: 'task_123',
        read: false,
        createdAt: now,
      );

      final map = model.toMap();
      expect(map['title'], 'Complete Project Review');
      expect(map['body'], 'Due in 1 hour');
      expect(map['type'], 'task_reminder');
      expect(map['relatedId'], 'task_123');
      expect(map['read'], false);

      final deserialized = NotificationLogModel.fromMap({
        'title': 'Complete Project Review',
        'body': 'Due in 1 hour',
        'type': 'task_reminder',
        'relatedId': 'task_123',
        'read': false,
        'createdAt': now.toIso8601String(),
      }, 'notif_1');

      expect(deserialized.id, 'notif_1');
      expect(deserialized.title, 'Complete Project Review');
      expect(deserialized.read, isFalse);
    });

    test('copyWith produces updated instance', () {
      final model = NotificationLogModel(
        id: 'notif_1',
        title: 'Workout Reminder',
        body: 'Time for evening cardio',
        type: 'habit_reminder',
        read: false,
        createdAt: DateTime.now(),
      );

      final updated = model.copyWith(read: true);
      expect(updated.read, isTrue);
      expect(updated.id, 'notif_1');
      expect(updated.title, 'Workout Reminder');
    });
  });

  group('NotificationsPage Widget Tests', () {
    testWidgets('Renders empty state when notification log is empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildNotificationsTestApp(
          overrides: [
            notificationLogsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          home: const NotificationsPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('No notifications yet'), findsOneWidget);
      expect(
        find.text(
          'When you receive reminders for tasks, events, habits, or focus sessions, they will appear here.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Renders populated notifications list with unread indicators and type icons',
        (WidgetTester tester) async {
      final sampleLogs = [
        NotificationLogModel(
          id: 'log_1',
          title: 'Deep Work Session Finished',
          body: '25m focus sprint completed. Take a 5m break!',
          type: 'pomodoro',
          read: false,
          createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        ),
        NotificationLogModel(
          id: 'log_2',
          title: 'Daily Habit Check-in',
          body: 'Read 20 pages of Atomic Habits',
          type: 'habit_reminder',
          read: true,
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      ];

      await tester.pumpWidget(
        _buildNotificationsTestApp(
          overrides: [
            notificationLogsStreamProvider
                .overrideWith((ref) => Stream.value(sampleLogs)),
          ],
          home: const NotificationsPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Deep Work Session Finished'), findsOneWidget);
      expect(find.text('25m focus sprint completed. Take a 5m break!'), findsOneWidget);
      expect(find.text('Daily Habit Check-in'), findsOneWidget);
      expect(find.text('Mark All Read'), findsOneWidget);
    });

    testWidgets('Arabic localization renders Notifications screen texts',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildNotificationsTestApp(
          locale: const Locale('ar'),
          overrides: [
            notificationLogsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
          home: const NotificationsPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الإشعارات'), findsOneWidget);
      expect(find.text('لا توجد إشعارات حتى الآن'), findsOneWidget);
    });
  });

  group('HomeScreen & Settings Notifications Integration Tests', () {
    testWidgets('HomeScreen AppBar displays notification bell with badge',
        (WidgetTester tester) async {
      final sampleLogs = [
        NotificationLogModel(
          id: 'log_1',
          title: 'Task Reminder',
          body: 'Submit taxes',
          type: 'task_reminder',
          read: false,
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        _buildNotificationsTestApp(
          overrides: [
            notificationLogsStreamProvider
                .overrideWith((ref) => Stream.value(sampleLogs)),
          ],
          home: const HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Find Notifications bell button in AppBar
      expect(find.byIcon(Icons.notifications_outlined), findsWidgets);
      // Unread badge count 1
      expect(find.text('1'), findsWidgets);
    });

    testWidgets('SettingsPage renders Test Notification (10s) diagnostic row',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildNotificationsTestApp(
          home: const SettingsPage(),
        ),
      );
      await tester.pumpAndSettle();

      // Drag to scroll down in Settings
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.text('Test Notification (10s)'), findsOneWidget);
      expect(
        find.text('Schedules an instant alert in 10 seconds to verify local notifications'),
        findsOneWidget,
      );
    });
  });
}
