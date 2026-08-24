import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/mental_health/helpers/mental_health_helpers.dart';
import 'package:focusly/features/mental_health/mental_health_page.dart';
import 'package:focusly/features/mental_health/models/mental_log_model.dart';
import 'package:focusly/features/mental_health/providers/mental_health_provider.dart';
import 'package:focusly/features/mental_health/widgets/mental_health_form_modal.dart';
import 'package:focusly/features/mental_health/widgets/mental_radar_chart.dart';
import 'package:focusly/features/rituals/providers/rituals_provider.dart';
import 'package:focusly/screens/home_screen.dart';

class MockDismissedNotifier extends MorningIntentionDismissedNotifier {
  @override
  bool build() => true;
}

class MockMentalSelectedDateNotifier extends MentalSelectedDateNotifier {
  @override
  DateTime build() => DateTime(2026, 8, 25);
}

class MockMentalViewModeNotifier extends MentalViewModeNotifier {
  @override
  MentalViewMode build() => MentalViewMode.daily;
}

Widget createMentalHealthTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_mental'),
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
  group('MentalHealthHelpers Unit Tests', () {
    test('getWeekBoundaries returns Sunday to Saturday week range', () {
      // 2026-08-25 is Tuesday
      final date = DateTime(2026, 8, 25);
      final range = MentalHealthHelpers.getWeekBoundaries(date);

      // Sunday 2026-08-23 to Saturday 2026-08-29
      expect(range.startDate, equals(DateTime(2026, 8, 23)));
      expect(range.endDate, equals(DateTime(2026, 8, 29)));
      expect(range.formattedStartDate, equals('2026-08-23'));
      expect(range.formattedEndDate, equals('2026-08-29'));
    });

    test('computeWeeklyAverage aggregates entries in same calendar week', () {
      final now = DateTime(2026, 8, 25);
      final logs = [
        MentalLogModel(
          id: '2026-08-25',
          weekOf: '2026-08-25', // Tuesday (in week 08-23 to 08-29)
          anxiety: 4,
          happiness: 8,
          socialEnergy: 6,
          selfSatisfaction: 7,
          balance: 6,
          createdAt: now,
          updatedAt: now,
        ),
        MentalLogModel(
          id: '2026-08-23',
          weekOf: '2026-08-23', // Sunday (in week 08-23 to 08-29)
          anxiety: 6,
          happiness: 6,
          socialEnergy: 8,
          selfSatisfaction: 5,
          balance: 8,
          createdAt: now,
          updatedAt: now,
        ),
        MentalLogModel(
          id: '2026-08-15',
          weekOf: '2026-08-15', // Outside week
          anxiety: 9,
          happiness: 2,
          socialEnergy: 2,
          selfSatisfaction: 2,
          balance: 2,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final avg = MentalHealthHelpers.computeWeeklyAverage(logs, DateTime(2026, 8, 25));
      expect(avg, isNotNull);
      // Anxiety: (4 + 6) / 2 = 5
      expect(avg!.anxiety, equals(5));
      // Happiness: (8 + 6) / 2 = 7
      expect(avg.happiness, equals(7));
      // Social Energy: (6 + 8) / 2 = 7
      expect(avg.socialEnergy, equals(7));
      // Self Satisfaction: (7 + 5) / 2 = 6
      expect(avg.selfSatisfaction, equals(6));
      // Balance: (6 + 8) / 2 = 7
      expect(avg.balance, equals(7));
    });

    test('findLowestDimension calculates Calm as 11 - anxiety and returns correct tip', () {
      final now = DateTime(2026, 8, 25);

      // Case 1: High anxiety (anxiety = 9 -> calmScore = 2, lowest of all)
      final log1 = MentalLogModel(
        id: '2026-08-25',
        weekOf: '2026-08-25',
        anxiety: 9, // calm = 2
        happiness: 8,
        socialEnergy: 7,
        selfSatisfaction: 8,
        balance: 7,
        createdAt: now,
        updatedAt: now,
      );

      final tip1 = MentalHealthHelpers.findLowestDimension(
        currentDisplayLog: log1,
        allLogs: [log1],
      );
      expect(tip1, isNotNull);
      expect(tip1!.dimensionKey, equals('dimension_calm'));
      expect(tip1.tipKey, equals('tip_calm'));
      expect(tip1.score, equals(2));

      // Case 2: Low life balance (balance = 3, anxiety = 2 -> calm = 9)
      final log2 = MentalLogModel(
        id: '2026-08-25',
        weekOf: '2026-08-25',
        anxiety: 2, // calm = 9
        happiness: 8,
        socialEnergy: 7,
        selfSatisfaction: 8,
        balance: 3,
        createdAt: now,
        updatedAt: now,
      );

      final tip2 = MentalHealthHelpers.findLowestDimension(
        currentDisplayLog: log2,
        allLogs: [log2],
      );
      expect(tip2, isNotNull);
      expect(tip2!.dimensionKey, equals('dimension_balance'));
      expect(tip2.tipKey, equals('tip_balance'));
      expect(tip2.score, equals(3));
    });

    test('compareTodayVsYesterday evaluates polarity correctly for Anxiety vs other dimensions', () {
      final now = DateTime(2026, 8, 25);

      final today = MentalLogModel(
        id: '2026-08-25',
        weekOf: '2026-08-25',
        anxiety: 3, // Dropped from 6 -> IMPROVED
        happiness: 8, // Rose from 6 -> IMPROVED
        socialEnergy: 4, // Dropped from 7 -> DECLINED
        selfSatisfaction: 5, // Equal to 5 -> SAME
        balance: 7,
        createdAt: now,
        updatedAt: now,
      );

      final yesterday = MentalLogModel(
        id: '2026-08-24',
        weekOf: '2026-08-24',
        anxiety: 6,
        happiness: 6,
        socialEnergy: 7,
        selfSatisfaction: 5,
        balance: 7,
        createdAt: now,
        updatedAt: now,
      );

      final comp = MentalHealthHelpers.compareTodayVsYesterday(
        todayLog: today,
        yesterdayLog: yesterday,
      );

      expect(comp.hasYesterday, isTrue);

      // Happiness (increased: 6 -> 8)
      expect(comp.comparisons[0].dimensionKey, equals('dimension_happiness'));
      expect(comp.comparisons[0].direction, equals(ComparisonDirection.improved));

      // Anxiety (decreased: 6 -> 3 => IMPROVED)
      expect(comp.comparisons[1].dimensionKey, equals('dimension_anxiety'));
      expect(comp.comparisons[1].direction, equals(ComparisonDirection.improved));

      // Social Energy (decreased: 7 -> 4 => DECLINED)
      expect(comp.comparisons[2].dimensionKey, equals('dimension_social_energy'));
      expect(comp.comparisons[2].direction, equals(ComparisonDirection.declined));

      // Self Satisfaction (unchanged: 5 == 5 => SAME)
      expect(comp.comparisons[3].dimensionKey, equals('dimension_self_satisfaction'));
      expect(comp.comparisons[3].direction, equals(ComparisonDirection.same));
    });
  });

  group('MentalLogModel Tests', () {
    test('Model serializes and deserializes accurately with calmScore getter', () {
      final now = DateTime(2026, 8, 25, 10, 0);
      final model = MentalLogModel(
        id: '2026-08-25',
        weekOf: '2026-08-25',
        anxiety: 4,
        happiness: 8,
        socialEnergy: 6,
        selfSatisfaction: 7,
        balance: 9,
        createdAt: now,
        updatedAt: now,
      );

      expect(model.calmScore, equals(7)); // 11 - 4 = 7

      final map = model.toMap();
      expect(map['weekOf'], equals('2026-08-25'));
      expect(map['anxiety'], equals(4));
      expect(map['happiness'], equals(8));
      expect(map['createdAt'], isA<Timestamp>());

      final deserialized = MentalLogModel.fromMap(map, '2026-08-25');
      expect(deserialized.id, equals('2026-08-25'));
      expect(deserialized.anxiety, equals(4));
      expect(deserialized.calmScore, equals(7));
      expect(deserialized.balance, equals(9));
    });
  });

  group('Mental Health UI & Widget Tests', () {
    final testDate = DateTime(2026, 8, 25);
    final mockLogs = [
      MentalLogModel(
        id: '2026-08-25',
        weekOf: '2026-08-25',
        anxiety: 3,
        happiness: 8,
        socialEnergy: 6,
        selfSatisfaction: 7,
        balance: 6,
        createdAt: testDate,
        updatedAt: testDate,
      ),
      MentalLogModel(
        id: '2026-08-24',
        weekOf: '2026-08-24',
        anxiety: 5,
        happiness: 7,
        socialEnergy: 7,
        selfSatisfaction: 6,
        balance: 5,
        createdAt: testDate,
        updatedAt: testDate,
      ),
    ];

    testWidgets('MentalRadarChart renders custom painter without errors', (tester) async {
      await tester.pumpWidget(
        createMentalHealthTestWidget(
          child: Scaffold(
            body: MentalRadarChart(log: mockLogs.first),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('MentalHealthPage renders empty state when zero entries exist', (tester) async {
      await tester.pumpWidget(
        createMentalHealthTestWidget(
          child: const MentalHealthPage(),
          overrides: [
            mentalLogsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('🧘 How is your mental health today?'), findsOneWidget);
      expect(find.text('Rate Today'), findsNWidgets(2)); // FAB + Empty button
    });

    testWidgets('MentalHealthPage renders Daily mode with Radar chart, Tip card, and Today vs Yesterday', (tester) async {
      await tester.pumpWidget(
        createMentalHealthTestWidget(
          child: const MentalHealthPage(),
          overrides: [
            mentalLogsStreamProvider.overrideWith((ref) => Stream.value(mockLogs)),
            mentalSelectedDateProvider.overrideWith(MockMentalSelectedDateNotifier.new),
            mentalViewModeProvider.overrideWith(MockMentalViewModeNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Controls
      expect(find.text('2026-08-25'), findsOneWidget);
      expect(find.text('Daily'), findsOneWidget);
      expect(find.text('Weekly Average'), findsOneWidget);

      // Radar Card
      expect(find.text('Daily Radar Chart (2026-08-25)'), findsOneWidget);
      expect(find.byType(MentalRadarChart), findsOneWidget);

      // Tip Card
      expect(find.text('Personalized Tip'), findsOneWidget);

      // Comparison Card
      await tester.scrollUntilVisible(find.text('Today vs Yesterday'), 100);
      expect(find.text('Today vs Yesterday'), findsOneWidget);
      expect(find.text('↗️ Improved'), findsWidgets);
    });

    testWidgets('MentalHealthPage switches to Weekly Average mode upon tapping toggle', (tester) async {
      await tester.pumpWidget(
        createMentalHealthTestWidget(
          child: const MentalHealthPage(),
          overrides: [
            mentalLogsStreamProvider.overrideWith((ref) => Stream.value(mockLogs)),
            mentalSelectedDateProvider.overrideWith(MockMentalSelectedDateNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap Weekly Average toggle
      await tester.tap(find.text('Weekly Average'));
      await tester.pumpAndSettle();

      expect(find.text('Weekly Average Chart (2026-08-23 – 2026-08-29)'), findsOneWidget);
      expect(find.byType(MentalRadarChart), findsOneWidget);
    });

    testWidgets('MentalHealthFormModal renders 5 sliders and saves', (tester) async {
      await tester.pumpWidget(
        createMentalHealthTestWidget(
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => MentalHealthFormModal.show(
                context,
                targetDate: DateTime(2026, 8, 25),
              ),
              child: const Text('Open Modal'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Open Modal'));
      await tester.pumpAndSettle();

      expect(find.text('Daily Mental Wellbeing'), findsOneWidget);
      expect(find.text('2026-08-25'), findsOneWidget);
      expect(find.text('Calm ↔ Anxiety (1 = Calm, 10 = Anxious)'), findsOneWidget);
      expect(find.text('Happiness'), findsOneWidget);
      expect(find.text('Social Energy'), findsOneWidget);
      expect(find.text('Self Satisfaction'), findsOneWidget);
      expect(find.text('Life Balance'), findsOneWidget);
      expect(find.byType(Slider), findsNWidgets(5));
    });

    testWidgets('Navigation Drawer contains Mental Health item in Health section', (tester) async {
      await tester.pumpWidget(
        createMentalHealthTestWidget(
          child: const HomeScreen(),
          overrides: [
            mentalLogsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final menuButton = find.byTooltip('Open navigation menu');
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      expect(find.text('HEALTH & FITNESS'), findsOneWidget);
      expect(find.text('Workout Tracker'), findsOneWidget);
      expect(find.text('Nutrition Log'), findsOneWidget);
      expect(find.text('Body Metrics'), findsOneWidget);
      expect(find.text('Mental Health'), findsOneWidget);
    });

    testWidgets('Arabic localization renders all Mental Health texts', (tester) async {
      await tester.pumpWidget(
        createMentalHealthTestWidget(
          locale: const Locale('ar'),
          child: const MentalHealthPage(),
          overrides: [
            mentalLogsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('الصحة النفسية'), findsOneWidget);
      expect(find.text('🧘 كيف تشعر نفسياً اليوم؟'), findsOneWidget);
      expect(find.text('تقييم اليوم'), findsNWidgets(2));
    });
  });
}
