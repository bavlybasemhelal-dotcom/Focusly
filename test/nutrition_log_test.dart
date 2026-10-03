import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/nutrition_log/helpers/nutrition_log_helpers.dart';
import 'package:focusly/features/nutrition_log/models/nutrition_log_model.dart';
import 'package:focusly/features/nutrition_log/nutrition_log_page.dart';
import 'package:focusly/features/nutrition_log/providers/nutrition_log_provider.dart';
import 'package:focusly/features/nutrition_log/widgets/last_7_days_card.dart';
import 'package:focusly/features/nutrition_log/widgets/nutrition_form_modal.dart';
import 'package:focusly/features/nutrition_log/widgets/nutrition_history_card.dart';
import 'package:focusly/features/nutrition_log/widgets/weekly_comparison_card.dart';
import 'package:focusly/features/rituals/providers/rituals_provider.dart';
import 'package:focusly/screens/home_screen.dart';

class MockDismissedNotifier extends MorningIntentionDismissedNotifier {
  @override
  bool build() => true;
}

Widget createNutritionTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_nutrition'),
      morningIntentionPromptSettingProvider.overrideWith(
        MorningIntentionPromptSettingNotifier.new,
      ),
      morningIntentionDismissedProvider.overrideWith(MockDismissedNotifier.new),
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
      home: child,
    ),
  );
}

void main() {
  group('NutritionLogHelpers Calculation & Timeline Tests', () {
    final now = DateTime(2026, 8, 25);

    test('compute7DayTimeline returns exactly 7 cells ending with today', () {
      final logs = [
        NutritionLogModel(
          id: '2026-08-25',
          rating: 5,
          date: DateTime(2026, 8, 25), // Today
          note: 'Salad and grilled salmon',
          createdAt: now,
          updatedAt: now,
        ),
        NutritionLogModel(
          id: '2026-08-23',
          rating: 3,
          date: DateTime(2026, 8, 23), // 2 days ago
          note: 'Pasta with vegetables',
          createdAt: now,
          updatedAt: now,
        ),
        NutritionLogModel(
          id: '2026-08-19',
          rating: 1,
          date: DateTime(2026, 8, 19), // 6 days ago (oldest in 7-day window)
          note: 'Fast food burger and fries',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final timeline = NutritionLogHelpers.compute7DayTimeline(logs, now);
      expect(timeline.length, equals(7));

      // Oldest cell (index 0, 6 days ago: 2026-08-19)
      final oldestCell = timeline[0];
      expect(oldestCell.formattedMonthDay, equals('08-19'));
      expect(oldestCell.rating, equals(1));
      expect(oldestCell.emoji, equals('😞'));

      // 5 days ago (index 1: 2026-08-20, no log)
      final noLogCell = timeline[1];
      expect(noLogCell.formattedMonthDay, equals('08-20'));
      expect(noLogCell.rating, isNull);
      expect(noLogCell.emoji, equals('⚪'));

      // 2 days ago (index 4: 2026-08-23)
      final middleCell = timeline[4];
      expect(middleCell.formattedMonthDay, equals('08-23'));
      expect(middleCell.rating, equals(3));
      expect(middleCell.emoji, equals('😐'));

      // Today (index 6: 2026-08-25)
      final todayCell = timeline[6];
      expect(todayCell.formattedMonthDay, equals('08-25'));
      expect(todayCell.rating, equals(5));
      expect(todayCell.emoji, equals('😊'));
    });

    test('calculateWeeklyAverage computes averages for this week (0-6 days) and last week (7-13 days)', () {
      final logs = [
        // This week entries (2026-08-25 down to 2026-08-19)
        NutritionLogModel(
          id: '2026-08-25',
          rating: 5,
          date: DateTime(2026, 8, 25),
          createdAt: now,
          updatedAt: now,
        ),
        NutritionLogModel(
          id: '2026-08-24',
          rating: 4,
          date: DateTime(2026, 8, 24),
          createdAt: now,
          updatedAt: now,
        ),
        NutritionLogModel(
          id: '2026-08-21',
          rating: 3,
          date: DateTime(2026, 8, 21),
          createdAt: now,
          updatedAt: now,
        ),

        // Last week entries (2026-08-18 down to 2026-08-12)
        NutritionLogModel(
          id: '2026-08-18', // 7 days ago
          rating: 2,
          date: DateTime(2026, 8, 18),
          createdAt: now,
          updatedAt: now,
        ),
        NutritionLogModel(
          id: '2026-08-14', // 11 days ago
          rating: 4,
          date: DateTime(2026, 8, 14),
          createdAt: now,
          updatedAt: now,
        ),

        // Older than 14 days
        NutritionLogModel(
          id: '2026-08-01',
          rating: 5,
          date: DateTime(2026, 8, 1),
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final comparison = NutritionLogHelpers.computeWeeklyComparison(logs, now);

      // This week: (5 + 4 + 3) / 3 = 4.0
      expect(comparison.thisWeekAvg, equals(4.0));
      expect(NutritionLogHelpers.formatAverage(comparison.thisWeekAvg), equals('4.0'));

      // Last week: (2 + 4) / 2 = 3.0
      expect(comparison.lastWeekAvg, equals(3.0));
      expect(NutritionLogHelpers.formatAverage(comparison.lastWeekAvg), equals('3.0'));
    });

    test('formatAverage returns − when null', () {
      expect(NutritionLogHelpers.formatAverage(null), equals('−'));
    });
  });

  group('NutritionLogModel Tests', () {
    test('Emoji mapping mirrors ratings 5->😊, 4->🙂, 3->😐, 2->😕, 1->😞, fallback->⚪', () {
      expect(NutritionLogModel.getEmojiForRating(5), equals('😊'));
      expect(NutritionLogModel.getEmojiForRating(4), equals('🙂'));
      expect(NutritionLogModel.getEmojiForRating(3), equals('😐'));
      expect(NutritionLogModel.getEmojiForRating(2), equals('😕'));
      expect(NutritionLogModel.getEmojiForRating(1), equals('😞'));
      expect(NutritionLogModel.getEmojiForRating(null), equals('⚪'));
    });

    test('Model serializes toMap and deserializes fromMap accurately', () {
      final now = DateTime(2026, 8, 25, 12, 0);
      final model = NutritionLogModel(
        id: '2026-08-25',
        rating: 4,
        date: DateTime(2026, 8, 25),
        note: 'Healthy lunch box',
        createdAt: now,
        updatedAt: now,
      );

      final map = model.toMap();
      expect(map['rating'], equals(4));
      expect(map['note'], equals('Healthy lunch box'));
      expect(map['date'], isA<Timestamp>());

      final deserialized = NutritionLogModel.fromMap(map, '2026-08-25');
      expect(deserialized.id, equals('2026-08-25'));
      expect(deserialized.rating, equals(4));
      expect(deserialized.emoji, equals('🙂'));
      expect(deserialized.note, equals('Healthy lunch box'));
    });
  });

  group('Nutrition Log UI & Widget Tests', () {
    final current = DateTime.now();
    final testDate = DateTime(current.year, current.month, current.day);
    final previousDate = DateTime(current.year, current.month, current.day - 1);
    final mockLogs = [
      NutritionLogModel(
        id: NutritionLogHelpers.formatDateKey(testDate),
        rating: 5,
        date: testDate,
        note: 'Superfood quinoa bowl',
        createdAt: testDate,
        updatedAt: testDate,
      ),
      NutritionLogModel(
        id: NutritionLogHelpers.formatDateKey(previousDate),
        rating: 3,
        date: previousDate,
        note: null, // Test empty note placeholder
        createdAt: testDate,
        updatedAt: testDate,
      ),
    ];

    testWidgets('Last7DaysCard renders header, Rate Today button, and 7 emoji cells', (tester) async {
      await tester.pumpWidget(
        createNutritionTestWidget(
          child: const Scaffold(
            body: SingleChildScrollView(child: Last7DaysCard()),
          ),
          overrides: [
            nutritionLogsStreamProvider.overrideWith((ref) => Stream.value(mockLogs)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Last 7 Days'), findsOneWidget);
      expect(find.text('Rate Today'), findsOneWidget);
      expect(find.text('😊'), findsOneWidget);
    });

    testWidgets('NutritionHistoryCard renders history list, labels, and action buttons', (tester) async {
      await tester.pumpWidget(
        createNutritionTestWidget(
          child: const Scaffold(
            body: SingleChildScrollView(child: NutritionHistoryCard()),
          ),
          overrides: [
            nutritionLogsStreamProvider.overrideWith((ref) => Stream.value(mockLogs)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nutrition History'), findsOneWidget);
      expect(find.text('Add Log'), findsOneWidget);
      expect(find.text('Superfood quinoa bowl'), findsOneWidget);
      expect(find.text('No notes written'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsNWidgets(2));
      expect(find.byIcon(Icons.delete_outline_rounded), findsNWidgets(2));
    });

    testWidgets('WeeklyComparisonCard renders This Week and Last Week average rows', (tester) async {
      await tester.pumpWidget(
        createNutritionTestWidget(
          child: const Scaffold(
            body: SingleChildScrollView(child: WeeklyComparisonCard()),
          ),
          overrides: [
            nutritionLogsStreamProvider.overrideWith((ref) => Stream.value(mockLogs)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Weekly Comparison'), findsOneWidget);
      expect(find.text('This Week Avg'), findsOneWidget);
      expect(find.text('Last Week Avg'), findsOneWidget);
      expect(find.text('4.0/5'), findsOneWidget);
      expect(find.text('−'), findsOneWidget); // Last week has no logs
    });

    testWidgets('NutritionLogPage renders empty state when no logs exist', (tester) async {
      await tester.pumpWidget(
        createNutritionTestWidget(
          child: const NutritionLogPage(),
          overrides: [
            nutritionLogsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text("🥗 Rate today's nutrition"), findsOneWidget);
      expect(find.text("Rate Food"), findsNWidgets(2)); // in FAB and in empty state button
    });

    testWidgets('NutritionFormModal renders rating selector with 5 options and default 3', (tester) async {
      await tester.pumpWidget(
        createNutritionTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => NutritionFormModal.show(context),
              child: const Text('Open Modal'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Rate Food Quality'), findsOneWidget);
      expect(find.text('Excellent (100% Healthy)'), findsOneWidget);
      expect(find.text('Very Good'), findsOneWidget);
      expect(find.text('Average'), findsOneWidget);
      expect(find.text('Unhealthy'), findsOneWidget);
      expect(find.text('Very Bad (Fast Food/Sweets)'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });

    testWidgets('Navigation Drawer contains Nutrition Log item in Health section', (tester) async {
      await tester.pumpWidget(
        createNutritionTestWidget(
          child: const HomeScreen(),
          overrides: [
            nutritionLogsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Open Navigation Drawer
      final menuButton = find.byTooltip('Open navigation menu');
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      // Verify Health & Fitness section contains Nutrition Log
      expect(find.text('HEALTH & FITNESS'), findsOneWidget);
      expect(find.text('Workout Tracker'), findsOneWidget);
      expect(find.text('Nutrition Log'), findsOneWidget);
    });

    testWidgets('Arabic localization renders all Nutrition Log texts', (tester) async {
      await tester.pumpWidget(
        createNutritionTestWidget(
          locale: const Locale('ar'),
          child: const NutritionLogPage(),
          overrides: [
            nutritionLogsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('سجل التغذية'), findsOneWidget);
      expect(find.text('🥗 قيّم جودة تغذيتك اليوم'), findsOneWidget);
      expect(find.text('تقييم الوجبات'), findsNWidgets(2));
    });
  });
}
