import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/energy_mood/providers/energy_mood_provider.dart';
import 'package:focusly/features/rituals/daily_rituals_page.dart';
import 'package:focusly/features/rituals/models/gratitude_model.dart';
import 'package:focusly/features/rituals/models/ritual_model.dart';
import 'package:focusly/features/rituals/providers/rituals_provider.dart';
import 'package:focusly/features/rituals/widgets/morning_intention_banner.dart';
import 'package:focusly/features/rituals/widgets/morning_intention_modal.dart';
import 'package:focusly/features/rituals/widgets/shutdown_wizard_modal.dart';
import 'package:focusly/features/tasks/models/task_model.dart';
import 'package:focusly/features/tasks/providers/tasks_provider.dart';

Widget createRitualsTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_rituals'),
      ...overrides.cast(),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Daily Rituals Models & Serialization Tests', () {
    test('ShutdownData serializes and deserializes correctly', () {
      const shutdown = ShutdownData(
        completed: true,
        gratitudeText: 'Coffee • Sunshine • Friends',
        tomorrowTasks: ['Task A', 'Task B'],
        lesson: 'Stay focused on one thing',
      );

      final map = shutdown.toMap();
      expect(map['completed'], isTrue);
      expect(map['gratitudeText'], equals('Coffee • Sunshine • Friends'));
      expect(map['tomorrowTasks'], equals(['Task A', 'Task B']));
      expect(map['lesson'], equals('Stay focused on one thing'));

      final reconstructed = ShutdownData.fromMap(map);
      expect(reconstructed.completed, isTrue);
      expect(reconstructed.gratitudeText, equals('Coffee • Sunshine • Friends'));
      expect(reconstructed.tomorrowTasks.length, equals(2));
      expect(reconstructed.lesson, equals('Stay focused on one thing'));
    });

    test('RitualModel getters and copyWith work as expected', () {
      final now = DateTime(2026, 8, 24, 10, 0);
      final ritual = RitualModel(
        date: '2026-08-24',
        intention: 'Complete the rituals feature release',
        shutdown: const ShutdownData(completed: true),
        createdAt: now,
        updatedAt: now,
      );

      expect(ritual.hasIntention, isTrue);
      expect(ritual.isShutdownCompleted, isTrue);

      final updated = ritual.copyWith(
        clearShutdown: true,
      );
      expect(updated.isShutdownCompleted, isFalse);
      expect(updated.hasIntention, isTrue);
    });

    test('GratitudeModel serializes correctly with combinedText helper', () {
      final now = DateTime(2026, 8, 24);
      final gratitude = GratitudeModel(
        id: '2026-08-24',
        date: now,
        item1: 'Family health',
        item2: 'Focusly app growth',
        item3: 'Fresh morning coffee',
        createdAt: now,
        updatedAt: now,
      );

      expect(gratitude.combinedText, equals('Family health • Focusly app growth • Fresh morning coffee'));
      final map = gratitude.toMap();
      expect(map['id'], equals('2026-08-24'));
      expect(map['item1'], equals('Family health'));

      final reconstructed = GratitudeModel.fromMap(map, '2026-08-24');
      expect(reconstructed.item2, equals('Focusly app growth'));
    });
  });

  group('Daily Rituals Provider Tests', () {
    test('MorningIntentionDismissedNotifier tracks and persists state', () async {
      SharedPreferences.setMockInitialValues({});
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(morningIntentionDismissedProvider), isFalse);
      await container.read(morningIntentionDismissedProvider.notifier).markShownToday();
      expect(container.read(morningIntentionDismissedProvider), isTrue);

      await container.read(morningIntentionDismissedProvider.notifier).reset();
      expect(container.read(morningIntentionDismissedProvider), isFalse);

      await container.read(morningIntentionDismissedProvider.notifier).dismiss();
      expect(container.read(morningIntentionDismissedProvider), isTrue);
    });
  });

  group('Daily Rituals UI & Widget Tests', () {
    testWidgets('MorningIntentionModal renders and validates required input', (tester) async {
      await tester.pumpWidget(
        createRitualsTestWidget(
          child: const MorningIntentionModal(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Morning Intention'), findsOneWidget);
      expect(find.text('Set Intention'), findsOneWidget);

      // Attempt submit without text
      await tester.tap(find.text('Set Intention'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your focus for today'), findsOneWidget);
    });

    testWidgets('MorningIntentionBanner renders prompt card with dismiss and calm entry point', (tester) async {
      await tester.pumpWidget(
        createRitualsTestWidget(
          child: const MorningIntentionBanner(),
          overrides: [
            todayRitualStreamProvider.overrideWithValue(const AsyncData(null)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Initial state: shows prompt card with Set button and close X
      expect(find.text('Set Morning Intention'), findsOneWidget);
      expect(find.text('Set'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);

      // Dismiss the prompt
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      // After dismissal: shows calm, non-intrusive persistent entry point
      expect(find.text('Set Morning Intention'), findsOneWidget);
      expect(find.text('Set'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_ios_rounded), findsOneWidget);

      // Tapping the calm persistent entry point opens the modal
      await tester.tap(find.text('Set Morning Intention'));
      await tester.pumpAndSettle();
      expect(find.text('Set Intention'), findsOneWidget);
    });

    testWidgets('MorningIntentionBanner renders intention when set and allows dismissal', (tester) async {
      final now = DateTime.now();
      final ritual = RitualModel(
        date: '2026-08-24',
        intention: 'Master Flutter and Riverpod',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        createRitualsTestWidget(
          child: const MorningIntentionBanner(),
          overrides: [
            todayRitualStreamProvider.overrideWithValue(AsyncData(ritual)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("TODAY'S FOCUS"), findsOneWidget);
      expect(find.text('Master Flutter and Riverpod'), findsOneWidget);

      // Tap dismiss X icon
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();

      expect(find.text("TODAY'S FOCUS"), findsNothing);
    });

    testWidgets('ShutdownWizardModal steps through 5-step flow and checks gratitude', (tester) async {
      final now = DateTime.now();
      final tasks = [
        TaskModel(
          id: 't1',
          title: 'Daily Standup',
          categoryId: 'work',
          done: true,
          date: now,
          createdAt: now,
        ),
      ];

      await tester.pumpWidget(
        createRitualsTestWidget(
          child: const ShutdownWizardModal(),
          overrides: [
            todayRitualStreamProvider.overrideWithValue(const AsyncData(null)),
            tasksStreamProvider.overrideWithValue(AsyncData(tasks)),
            todayCheckinStreamProvider.overrideWithValue(const AsyncData(null)),
            preferredShutdownTimeSettingProvider.overrideWith(
              PreferredShutdownTimeSettingNotifier.new,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Step 1: Review Today
      expect(find.text('Review Today'), findsOneWidget);
      expect(find.text('1 of 1 tasks completed today'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);

      // Advance to Step 2: Plan Tomorrow
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Plan Tomorrow'), findsOneWidget);

      // Advance to Step 3: Quick Check-In
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Quick Check-In'), findsOneWidget);

      // Advance to Step 4: Lesson Learned
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Lesson Learned'), findsOneWidget);

      // Advance to Step 5: Daily Gratitude
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Daily Gratitude'), findsOneWidget);
      expect(find.text('Finish & Close Day'), findsOneWidget);

      // Attempt finish without gratitude items
      await tester.tap(find.text('Finish & Close Day'));
      await tester.pumpAndSettle();
      expect(find.text('Please fill in all 3 items'), findsOneWidget);
    });

    testWidgets('DailyRitualsPage renders intention card, shutdown card, and history', (tester) async {
      final now = DateTime.now();
      final ritual = RitualModel(
        date: '2026-08-24',
        intention: 'Crush all feature requirements',
        shutdown: const ShutdownData(
          completed: true,
          gratitudeText: 'Good food • Great code',
          lesson: 'Patience brings excellence',
        ),
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        createRitualsTestWidget(
          child: const DailyRitualsPage(),
          overrides: [
            todayRitualStreamProvider.overrideWithValue(AsyncData(ritual)),
            ritualsHistoryStreamProvider.overrideWithValue(AsyncData([ritual])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Daily Rituals'), findsOneWidget);
      expect(find.text('Morning Intention'), findsOneWidget);
      expect(find.text('Shutdown Ritual'), findsOneWidget);
      expect(find.text('Rituals History'), findsOneWidget);
      expect(find.text('Crush all feature requirements'), findsWidgets);
    });
  });
}
