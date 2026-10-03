import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/localization/app_localizations.dart';
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
    overrides: [
      notificationsControllerProvider.overrideWith(
        (ref) => _NavigationNotificationsController(ref),
      ),
      ...overrides.cast(),
    ],
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

// Navigation tests use a successful storage boundary. Persistence and account
// isolation are exercised against Firestore in implementation_regressions_test.
class _NavigationNotificationsController extends NotificationsController {
  _NavigationNotificationsController(super.ref);
  @override
  Future<bool> markAsRead(String logId) async => true;
  @override
  Future<bool> markAllAsRead() async => true;
  @override
  Future<bool> deleteNotification(String logId) async => true;
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
    testWidgets('Renders empty state when notification log is empty', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildNotificationsTestApp(
          overrides: [
            notificationLogsStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
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

    testWidgets(
      'Renders populated notifications list with unread indicators and type icons',
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
              notificationLogsStreamProvider.overrideWith(
                (ref) => Stream.value(sampleLogs),
              ),
            ],
            home: const NotificationsPage(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Notifications'), findsOneWidget);
        expect(find.text('Deep Work Session Finished'), findsOneWidget);
        expect(
          find.text('25m focus sprint completed. Take a 5m break!'),
          findsOneWidget,
        );
        expect(find.text('Daily Habit Check-in'), findsOneWidget);
        expect(find.text('Mark All Read'), findsOneWidget);
      },
    );

    testWidgets(
      'Tapping notification row opens NotificationDetailPage with full content and related action with back navigation',
      (WidgetTester tester) async {
        final sampleLogs = [
          NotificationLogModel(
            id: 'log_task',
            title: 'Complete Quarterly Report',
            body:
                'Finalize metrics and review team contributions before the 5 PM deadline today.',
            type: 'task_reminder',
            relatedId: 'task_999',
            read: false,
            createdAt: DateTime(2026, 8, 27, 10, 30),
          ),
        ];

        await tester.pumpWidget(
          _buildNotificationsTestApp(
            overrides: [
              notificationLogsStreamProvider.overrideWith(
                (ref) => Stream.value(sampleLogs),
              ),
            ],
            home: const NotificationsPage(),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the notification row
        await tester.tap(find.text('Complete Quarterly Report'));
        await tester.pumpAndSettle();

        // Verify NotificationDetailPage opened
        expect(find.text('Notification Details'), findsOneWidget);
        expect(find.text('Task Reminder'), findsOneWidget);
        expect(find.text('Read'), findsOneWidget);
        expect(find.text('Complete Quarterly Report'), findsOneWidget);
        expect(
          find.text(
            'Finalize metrics and review team contributions before the 5 PM deadline today.',
          ),
          findsOneWidget,
        );
        expect(find.text('View Task'), findsOneWidget);

        // Tap "View Task" action button
        await tester.tap(find.text('View Task'));
        await tester.pumpAndSettle();

        // Destination (TasksScreen) wrapped with back button AppBar
        expect(find.text('Tasks'), findsWidgets);
        expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

        // Tap back button from Tasks screen
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();

        // Verify returned back to NotificationDetailPage (not skipped to Notifications list)
        expect(find.text('Notification Details'), findsOneWidget);
        expect(find.text('View Task'), findsOneWidget);

        // Tap back button to return to Notifications list
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();

        // Back on Notifications list
        expect(find.text('Notifications'), findsOneWidget);
      },
    );

    testWidgets(
      'View Event and View Habit navigation paths render back buttons and return to detail screen',
      (WidgetTester tester) async {
        final sampleLogs = [
          NotificationLogModel(
            id: 'log_event',
            title: 'Design Sync Meeting',
            body: 'Quarterly planning discussion with product team.',
            type: 'event_reminder',
            relatedId: 'event_123',
            read: false,
            createdAt: DateTime(2026, 8, 27, 11, 0),
          ),
          NotificationLogModel(
            id: 'log_habit',
            title: 'Daily Meditation',
            body: '10 minutes of mindfulness breathing.',
            type: 'habit_reminder',
            relatedId: 'habit_456',
            read: false,
            createdAt: DateTime(2026, 8, 27, 7, 30),
          ),
        ];

        await tester.pumpWidget(
          _buildNotificationsTestApp(
            overrides: [
              notificationLogsStreamProvider.overrideWith(
                (ref) => Stream.value(sampleLogs),
              ),
            ],
            home: const NotificationsPage(),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Test Event Navigation
        await tester.tap(find.text('Design Sync Meeting'));
        await tester.pumpAndSettle();

        expect(find.text('Notification Details'), findsOneWidget);
        expect(find.text('View Event'), findsOneWidget);

        await tester.tap(find.text('View Event'));
        await tester.pumpAndSettle();

        // Has back button
        expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Notification Details'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();

        // 2. Test Habit Navigation
        await tester.tap(find.text('Daily Meditation'));
        await tester.pumpAndSettle();

        expect(find.text('Notification Details'), findsOneWidget);
        expect(find.text('View Habit'), findsOneWidget);

        await tester.tap(find.text('View Habit'));
        await tester.pumpAndSettle();

        // Has back button
        expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Notification Details'), findsOneWidget);
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.pumpAndSettle();

        expect(find.text('Notifications'), findsOneWidget);
      },
    );

    testWidgets(
      'NotificationDetailPage hides action button when relatedId is null',
      (WidgetTester tester) async {
        final sampleLogs = [
          NotificationLogModel(
            id: 'log_system',
            title: 'System Update Completed',
            body:
                'Your offline storage and synced caches have been updated to the latest schema version.',
            type: 'system',
            relatedId: null, // No related item
            read: true,
            createdAt: DateTime(2026, 8, 27, 9, 0),
          ),
        ];

        await tester.pumpWidget(
          _buildNotificationsTestApp(
            overrides: [
              notificationLogsStreamProvider.overrideWith(
                (ref) => Stream.value(sampleLogs),
              ),
            ],
            home: const NotificationsPage(),
          ),
        );
        await tester.pumpAndSettle();

        // Tap the notification row
        await tester.tap(find.text('System Update Completed'));
        await tester.pumpAndSettle();

        // Verify NotificationDetailPage opened
        expect(find.text('Notification Details'), findsOneWidget);
        expect(find.text('System Alert'), findsOneWidget);
        expect(find.text('Read'), findsOneWidget);
        expect(find.text('System Update Completed'), findsOneWidget);

        // No action button because relatedId is null
        expect(find.text('View Related Item'), findsNothing);
        expect(find.text('View Task'), findsNothing);
      },
    );

    testWidgets('Arabic localization renders Notifications screen texts', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildNotificationsTestApp(
          locale: const Locale('ar'),
          overrides: [
            notificationLogsStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
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
    testWidgets('HomeScreen AppBar displays notification bell with badge', (
      WidgetTester tester,
    ) async {
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
            notificationLogsStreamProvider.overrideWith(
              (ref) => Stream.value(sampleLogs),
            ),
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

    testWidgets('SettingsPage renders Test Notification (10s) diagnostic row', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _buildNotificationsTestApp(home: const SettingsPage()),
      );
      await tester.pumpAndSettle();

      // Drag to scroll down in Settings
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();

      expect(find.text('Test Notification (10s)'), findsOneWidget);
      expect(
        find.text(
          'Schedules an instant alert in 10 seconds to verify local notifications',
        ),
        findsOneWidget,
      );
    });
  });
}
