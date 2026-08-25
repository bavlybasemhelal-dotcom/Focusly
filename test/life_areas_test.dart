import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/life_areas/life_areas_page.dart';
import 'package:focusly/features/life_areas/models/life_area_assessment_model.dart';
import 'package:focusly/features/life_areas/providers/life_areas_provider.dart';
import 'package:focusly/features/life_areas/widgets/assessment_form_modal.dart';
import 'package:focusly/features/life_areas/widgets/wheel_of_life_radar_chart.dart';
import 'package:focusly/features/rituals/providers/rituals_provider.dart';
import 'package:focusly/screens/home_screen.dart';

class MockDismissedNotifier extends MorningIntentionDismissedNotifier {
  @override
  bool build() => true;
}

Widget createLifeAreasTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_life_areas'),
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
  final testAssessment1 = LifeAreaAssessmentModel(
    id: 'a1',
    date: DateTime(2026, 8, 25),
    career: 8,
    finance: 7,
    health: 9,
    family: 6,
    romance: 7,
    growth: 8,
    fun: 5,
    environment: 6,
    createdAt: DateTime(2026, 8, 25),
  );

  final testAssessment2 = LifeAreaAssessmentModel(
    id: 'a2',
    date: DateTime(2026, 8, 1),
    career: 5,
    finance: 4,
    health: 6,
    family: 5,
    romance: 5,
    growth: 5,
    fun: 4,
    environment: 5,
    createdAt: DateTime(2026, 8, 1),
  );

  group('LifeAreaAssessmentModel Unit Tests', () {
    test('Model serialization and averageScore computation', () {
      final map = testAssessment1.toMap();
      expect(map['career'], equals(8));
      expect(map['finance'], equals(7));
      expect(map['health'], equals(9));
      expect(map['family'], equals(6));

      final deserialized = LifeAreaAssessmentModel.fromMap(map, 'a1');
      expect(deserialized.id, equals('a1'));
      expect(deserialized.career, equals(8));
      expect(deserialized.finance, equals(7));
      expect(deserialized.health, equals(9));
      expect(deserialized.romance, equals(7));

      // Average: (8 + 7 + 9 + 6 + 7 + 8 + 5 + 6) / 8 = 56 / 8 = 7.0
      expect(testAssessment1.averageScore, equals(7.0));
      expect(testAssessment1.formattedDate, equals('Aug 25, 2026'));
    });

    test('copyWith updates specified dimensions correctly', () {
      final updated = testAssessment1.copyWith(
        career: 10,
        fun: 8,
      );
      expect(updated.career, equals(10));
      expect(updated.fun, equals(8));
      expect(updated.finance, equals(7)); // Unchanged
    });
  });

  group('WheelOfLifeRadarChart Tests', () {
    testWidgets('WheelOfLifeRadarChart paints single and comparison polygons', (tester) async {
      await tester.pumpWidget(
        createLifeAreasTestWidget(
          child: Scaffold(
            body: WheelOfLifeRadarChart(
              primary: testAssessment1,
              comparison: testAssessment2,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(WheelOfLifeRadarChart), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });
  });

  group('LifeAreasPage UI & Widget Tests', () {
    testWidgets('Renders empty state when 0 assessments exist', (tester) async {
      await tester.pumpWidget(
        createLifeAreasTestWidget(
          child: const LifeAreasPage(),
          overrides: [
            lifeAreasStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wheel of Life'), findsOneWidget);
      expect(find.text('Evaluate your life balance'), findsOneWidget);
      expect(find.text('Start Assessment'), findsOneWidget);
    });

    testWidgets('Renders Radar Card with dropdown selectors and History Card', (tester) async {
      await tester.pumpWidget(
        createLifeAreasTestWidget(
          child: const LifeAreasPage(),
          overrides: [
            lifeAreasStreamProvider.overrideWith(
              (ref) => Stream.value([testAssessment1, testAssessment2]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Wheel of Life'), findsOneWidget);
      expect(find.text('Primary Assessment'), findsOneWidget);
      expect(find.text('Compare With'), findsOneWidget);
      expect(find.byType(WheelOfLifeRadarChart), findsOneWidget);

      // Scroll down to reveal history card
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Assessment History'), findsOneWidget);
      expect(find.text('Aug 25, 2026'), findsWidgets);
    });

    testWidgets('Navigation Drawer includes Wheel of Life item in Analytics section', (tester) async {
      await tester.pumpWidget(
        createLifeAreasTestWidget(
          child: const HomeScreen(),
          overrides: [
            lifeAreasStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final menuButton = find.byTooltip('Open navigation menu');
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      expect(find.text('ANALYTICS'), findsOneWidget);
      expect(find.text('Wheel of Life'), findsOneWidget);
    });

    testWidgets('Arabic localization renders all Wheel of Life texts', (tester) async {
      await tester.pumpWidget(
        createLifeAreasTestWidget(
          locale: const Locale('ar'),
          child: const LifeAreasPage(),
          overrides: [
            lifeAreasStreamProvider.overrideWith(
              (ref) => Stream.value([testAssessment1]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('عجلة الحياة'), findsOneWidget);
      expect(find.text('التقييم الأساسي'), findsOneWidget);
      expect(find.text('مقارنة مع'), findsOneWidget);

      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('سجل التقييمات السابقة'), findsOneWidget);
    });
  });

  group('AssessmentFormModal Tests', () {
    testWidgets('Renders all 8 sliders and date selector', (tester) async {
      await tester.pumpWidget(
        createLifeAreasTestWidget(
          child: Scaffold(
            body: AssessmentFormModal(
              assessmentToEdit: testAssessment1,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Assessment'), findsOneWidget);
      expect(find.text('Career'), findsOneWidget);
      expect(find.text('Finance'), findsOneWidget);
      expect(find.text('Health'), findsOneWidget);
      expect(find.text('Family'), findsOneWidget);
      expect(find.text('Romance'), findsOneWidget);
      expect(find.text('Personal Growth'), findsOneWidget);
      expect(find.text('Fun & Recreation'), findsOneWidget);
      expect(find.text('Environment'), findsOneWidget);
      expect(find.text('Save Assessment'), findsOneWidget);
      expect(find.text('Delete Assessment'), findsOneWidget);
      expect(find.byType(Slider), findsNWidgets(8));
    });
  });
}
