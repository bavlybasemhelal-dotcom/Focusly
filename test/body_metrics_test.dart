import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/body_metrics/body_metrics_page.dart';
import 'package:focusly/features/body_metrics/helpers/body_metrics_helpers.dart';
import 'package:focusly/features/body_metrics/models/body_metric_model.dart';
import 'package:focusly/features/body_metrics/providers/body_metrics_provider.dart';
import 'package:focusly/features/body_metrics/widgets/body_metric_form_modal.dart';
import 'package:focusly/features/body_metrics/widgets/body_metric_stat_card.dart';
import 'package:focusly/features/body_metrics/widgets/trend_line_chart.dart';
import 'package:focusly/features/rituals/providers/rituals_provider.dart';
import 'package:focusly/screens/home_screen.dart';

class MockDismissedNotifier extends MorningIntentionDismissedNotifier {
  @override
  bool build() => true;
}

Widget createBodyMetricsTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_body_metrics'),
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
  group('BodyMetricsHelpers Unit Tests', () {
    final now = DateTime(2026, 8, 25);

    test(
      'computeLatestReadings extracts latest non-null value per metric independently',
      () {
        final logs = [
          // Most recent entry (only pulse logged)
          BodyMetricModel(
            id: '1',
            date: DateTime(2026, 8, 25),
            pulse: 68,
            createdAt: now,
            updatedAt: now,
          ),
          // 1 day ago (only BP logged)
          BodyMetricModel(
            id: '2',
            date: DateTime(2026, 8, 24),
            bpSystolic: 118,
            bpDiastolic: 78,
            createdAt: now,
            updatedAt: now,
          ),
          // 2 days ago (only weight logged)
          BodyMetricModel(
            id: '3',
            date: DateTime(2026, 8, 23),
            weight: 76.5,
            createdAt: now,
            updatedAt: now,
          ),
        ];

        final latest = BodyMetricsHelpers.computeLatestReadings(logs);

        expect(latest.latestWeight, equals(76.5));
        expect(latest.latestSystolic, equals(118));
        expect(latest.latestDiastolic, equals(78));
        expect(latest.latestPulse, equals(68));
      },
    );

    test(
      'extractWeightSeries sorts ascending chronologically and ignores empty weight entries',
      () {
        final logs = [
          BodyMetricModel(
            id: '1',
            date: DateTime(2026, 8, 25),
            weight: 75.0,
            createdAt: now,
            updatedAt: now,
          ),
          BodyMetricModel(
            id: '2',
            date: DateTime(2026, 8, 20),
            // No weight
            pulse: 70,
            createdAt: now,
            updatedAt: now,
          ),
          BodyMetricModel(
            id: '3',
            date: DateTime(2026, 8, 22),
            weight: 76.0,
            createdAt: now,
            updatedAt: now,
          ),
        ];

        final series = BodyMetricsHelpers.extractWeightSeries(logs);
        expect(series.length, equals(2));
        expect(series[0].date, equals(DateTime(2026, 8, 22)));
        expect(series[0].value, equals(76.0));
        expect(series[1].date, equals(DateTime(2026, 8, 25)));
        expect(series[1].value, equals(75.0));
      },
    );

    test('extractBpSeries requires complete paired systolic and diastolic', () {
      final logs = [
        BodyMetricModel(
          id: '1',
          date: DateTime(2026, 8, 25),
          bpSystolic: 120,
          bpDiastolic: 80,
          createdAt: now,
          updatedAt: now,
        ),
        BodyMetricModel(
          id: '2',
          date: DateTime(2026, 8, 23),
          bpSystolic: 125, // Missing diastolic
          createdAt: now,
          updatedAt: now,
        ),
        BodyMetricModel(
          id: '3',
          date: DateTime(2026, 8, 21),
          bpSystolic: 115,
          bpDiastolic: 75,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final bpSeries = BodyMetricsHelpers.extractBpSeries(logs);
      expect(bpSeries.hasEnoughPoints, isTrue);
      expect(bpSeries.systolicPoints.length, equals(2));
      expect(bpSeries.diastolicPoints.length, equals(2));
      expect(bpSeries.systolicPoints[0].value, equals(115.0));
      expect(bpSeries.diastolicPoints[0].value, equals(75.0));
      expect(bpSeries.systolicPoints[1].value, equals(120.0));
      expect(bpSeries.diastolicPoints[1].value, equals(80.0));
    });
  });

  group('BodyMetricModel Tests', () {
    test('Serialization to and from map works accurately', () {
      final now = DateTime(2026, 8, 25, 8, 30);
      final model = BodyMetricModel(
        id: 'metric_1',
        date: DateTime(2026, 8, 25),
        weight: 78.2,
        bpSystolic: 122,
        bpDiastolic: 82,
        pulse: 74,
        note: 'Felt well-rested',
        createdAt: now,
        updatedAt: now,
      );

      final map = model.toMap();
      expect(map['weight'], equals(78.2));
      expect(map['bpSystolic'], equals(122));
      expect(map['bpDiastolic'], equals(82));
      expect(map['pulse'], equals(74));
      expect(map['note'], equals('Felt well-rested'));
      expect(map['date'], isA<Timestamp>());

      final deserialized = BodyMetricModel.fromMap(map, 'metric_1');
      expect(deserialized.id, equals('metric_1'));
      expect(deserialized.weight, equals(78.2));
      expect(deserialized.bpSystolic, equals(122));
      expect(deserialized.bpDiastolic, equals(82));
      expect(deserialized.pulse, equals(74));
      expect(deserialized.hasWeight, isTrue);
      expect(deserialized.hasCompleteBp, isTrue);
      expect(deserialized.hasPulse, isTrue);
    });
  });

  group('Body Metrics UI & Widget Tests', () {
    final testDate = DateTime(2026, 8, 25);
    final mockMetrics = [
      BodyMetricModel(
        id: '1',
        date: DateTime(2026, 8, 25),
        weight: 74.5,
        bpSystolic: 120,
        bpDiastolic: 80,
        pulse: 72,
        note: 'Morning post-run measurement',
        createdAt: testDate,
        updatedAt: testDate,
      ),
      BodyMetricModel(
        id: '2',
        date: DateTime(2026, 8, 23),
        weight: 75.0,
        bpSystolic: 124,
        bpDiastolic: 82,
        pulse: 75,
        note: null,
        createdAt: testDate,
        updatedAt: testDate,
      ),
    ];

    testWidgets('BodyMetricStatCard renders label, value and icon', (
      tester,
    ) async {
      await tester.pumpWidget(
        createBodyMetricsTestWidget(
          child: const Scaffold(
            body: BodyMetricStatCard(
              icon: Icons.scale_rounded,
              iconColor: Color(0xFF10B981),
              label: 'Latest Weight',
              value: '74.5 kg',
              valueColor: Color(0xFF10B981),
              dateSubtitle: '08-25',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Latest Weight'), findsOneWidget);
      expect(find.text('74.5 kg'), findsOneWidget);
      expect(find.text('08-25'), findsOneWidget);
    });

    testWidgets('TrendLineChart renders single and dual series smoothly', (
      tester,
    ) async {
      final points = [
        ChartDataPoint(
          date: DateTime(2026, 8, 20),
          value: 70.0,
          formattedDate: '08-20',
          formattedValue: '70',
        ),
        ChartDataPoint(
          date: DateTime(2026, 8, 25),
          value: 75.0,
          formattedDate: '08-25',
          formattedValue: '75',
        ),
      ];

      await tester.pumpWidget(
        createBodyMetricsTestWidget(
          child: Scaffold(
            body: TrendLineChart(
              seriesList: [
                TrendSeries(
                  points: points,
                  color: const Color(0xFF10B981),
                  label: 'Weight',
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('08-20'), findsOneWidget);
      expect(find.text('08-25'), findsOneWidget);
    });

    testWidgets('BodyMetricsPage renders empty state when zero entries exist', (
      tester,
    ) async {
      await tester.pumpWidget(
        createBodyMetricsTestWidget(
          child: const BodyMetricsPage(),
          overrides: [
            bodyMetricsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('⚖️ Start by logging your measurements'),
        findsOneWidget,
      );
      expect(
        find.text('Add Metric'),
        findsNWidgets(2),
      ); // in FAB and in empty state button
    });

    testWidgets(
      'BodyMetricsPage renders stats, charts, and history list with inline chips',
      (tester) async {
        await tester.pumpWidget(
          createBodyMetricsTestWidget(
            child: const BodyMetricsPage(),
            overrides: [
              bodyMetricsStreamProvider.overrideWith(
                (ref) => Stream.value(mockMetrics),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Stats
        expect(find.text('Latest Weight'), findsWidgets);
        expect(find.text('74.5 kg'), findsOneWidget);
        expect(find.text('Blood Pressure'), findsWidgets);
        expect(find.text('120/80'), findsOneWidget);
        expect(find.text('Pulse'), findsWidgets);
        expect(find.text('72 bpm'), findsOneWidget);

        // Trend Charts (scroll down to ensure visible in ListView)
        expect(find.text('Weight Trend'), findsOneWidget);
        expect(find.text('Blood Pressure Trend'), findsOneWidget);
        await tester.scrollUntilVisible(find.text('Pulse Trend'), 100);
        expect(find.text('Pulse Trend'), findsOneWidget);

        // History
        await tester.scrollUntilVisible(find.text('Measurement History'), 100);
        expect(find.text('Measurement History'), findsOneWidget);
        expect(find.text('Morning post-run measurement'), findsOneWidget);
      },
    );

    testWidgets(
      'BodyMetricFormModal validates that at least one measurement is entered',
      (tester) async {
        await tester.pumpWidget(
          createBodyMetricsTestWidget(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => BodyMetricFormModal.show(context),
                child: const Text('Open Modal'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Modal'));
        await tester.pumpAndSettle();

        expect(find.text('Log Body Metric'), findsOneWidget);

        // Scroll to Save button and tap
        await tester.ensureVisible(find.text('Save'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(
          find.text('Please log at least one measurement'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Navigation Drawer contains Body Metrics item in Health section',
      (tester) async {
        await tester.pumpWidget(
          createBodyMetricsTestWidget(
            child: const HomeScreen(),
            overrides: [
              bodyMetricsStreamProvider.overrideWith((ref) => Stream.value([])),
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
      },
    );

    testWidgets('Arabic localization renders all Body Metrics texts', (
      tester,
    ) async {
      await tester.pumpWidget(
        createBodyMetricsTestWidget(
          locale: const Locale('ar'),
          child: const BodyMetricsPage(),
          overrides: [
            bodyMetricsStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('المؤشرات الحيوية'), findsOneWidget);
      expect(find.text('⚖️ ابدأ بتسجيل قياساتك الحيوية'), findsOneWidget);
      expect(find.text('إضافة قياس'), findsNWidgets(2));
    });
  });
}
