import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:focusly/core/data/firestore_provider.dart';
import 'package:focusly/features/skills/widgets/dated_skill_sparkline.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/rituals/providers/rituals_provider.dart';
import 'package:focusly/features/skills/helpers/skill_math_helper.dart';
import 'package:focusly/features/skills/models/skill_model.dart';
import 'package:focusly/features/skills/providers/skills_provider.dart';
import 'package:focusly/features/skills/skills_board_page.dart';
import 'package:focusly/features/skills/widgets/radar_chart_widget.dart';
import 'package:focusly/features/skills/widgets/skill_card.dart';
import 'package:focusly/features/skills/widgets/skill_form_modal.dart';
import 'package:focusly/features/skills/widgets/skill_quick_update_dialog.dart';
import 'package:focusly/features/tasks/models/task_model.dart';
import 'package:focusly/screens/home_screen.dart';

class MockDismissedNotifier extends MorningIntentionDismissedNotifier {
  @override
  bool build() => true;
}

Widget createSkillsTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      firestoreProvider.overrideWithValue(FakeFirebaseFirestore()),
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_skills'),
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
  group('Skill Math Helper Pure Function Tests', () {
    test(
      'computeXpProgress handles normal XP progression without level-up',
      () {
        final res = SkillMathHelper.computeXpProgress(
          currentLevel: 1,
          currentXp: 40,
          addedXp: 30,
        );

        expect(res.newLevel, equals(1));
        expect(res.newXp, equals(70));
        expect(res.levelGain, equals(0));
        expect(res.didLevelUp, isFalse);
      },
    );

    test(
      'computeXpProgress triggers level-up when XP reaches or exceeds 100',
      () {
        final res = SkillMathHelper.computeXpProgress(
          currentLevel: 2,
          currentXp: 85,
          addedXp: 25, // 85 + 25 = 110
        );

        expect(res.newLevel, equals(3));
        expect(res.newXp, equals(10));
        expect(res.levelGain, equals(1));
        expect(res.didLevelUp, isTrue);
      },
    );

    test(
      'computeXpProgress handles multiple level jumps for large XP additions',
      () {
        final res = SkillMathHelper.computeXpProgress(
          currentLevel: 1,
          currentXp: 10,
          addedXp: 250, // 260 total -> 2 levels + 60 xp
        );

        expect(res.newLevel, equals(3));
        expect(res.newXp, equals(60));
        expect(res.levelGain, equals(2));
        expect(res.didLevelUp, isTrue);
      },
    );

    test('normalizeDirectInput handles direct user inputs with overflow', () {
      final res = SkillMathHelper.normalizeDirectInput(
        levelInput: 3,
        xpInput: 180,
        previousLevel: 3,
      );

      expect(res.newLevel, equals(4)); // 3 + 1
      expect(res.newXp, equals(80));
      expect(res.didLevelUp, isTrue);
    });

    test('updateHistoryToday updates index 6 with the new level', () {
      final history = [1, 1, 1, 2, 2, 2, 2];
      final updated = SkillMathHelper.updateHistoryToday(history, 3);

      expect(updated.length, equals(7));
      expect(updated[6], equals(3));
      expect(updated[5], equals(2));
    });
  });

  group('Skill Model & TaskModel Skill Extension Tests', () {
    test('SkillModel serializes and deserializes correctly', () {
      final now = DateTime(2026, 8, 24, 10, 0);
      final skill = SkillModel(
        id: 'skill_1',
        name: 'Flutter Development',
        category: 'work',
        level: 4,
        xp: 65,
        color: 0xFF2E6FF2,
        history: const [1, 2, 2, 3, 3, 4, 4],
        createdAt: now,
        updatedAt: now,
      );

      final map = skill.toMap();
      expect(map['name'], equals('Flutter Development'));
      expect(map['category'], equals('work'));
      expect(map['level'], equals(4));
      expect(map['xp'], equals(65));
      expect(map['color'], equals(0xFF2E6FF2));

      final reconstructed = SkillModel.fromMap(map, 'skill_1');
      expect(reconstructed.id, equals('skill_1'));
      expect(reconstructed.name, equals('Flutter Development'));
      expect(reconstructed.level, equals(4));
      expect(reconstructed.xp, equals(65));
      expect(reconstructed.xpProgress, closeTo(0.65, 0.001));
      expect(reconstructed.history.length, equals(7));
    });

    test('TaskModel skillId serialization and copyWith work properly', () {
      final now = DateTime.now();
      final task = TaskModel(
        id: 't1',
        title: 'Build Feature',
        categoryId: 'work',
        date: now,
        createdAt: now,
        skillId: 'skill_123',
      );

      expect(task.skillId, equals('skill_123'));
      final map = task.toMap();
      expect(map['skillId'], equals('skill_123'));

      final fromMapTask = TaskModel.fromMap(map, 't1');
      expect(fromMapTask.skillId, equals('skill_123'));

      final clearedTask = task.copyWith(clearSkillId: true);
      expect(clearedTask.skillId, isNull);
    });
  });

  group('Skills Board UI & Widget Tests', () {
    testWidgets(
      'SkillCard renders name, category, level badge, XP, and sparkline',
      (tester) async {
        final now = DateTime.now();
        final skill = SkillModel(
          id: 's1',
          name: 'Public Speaking',
          category: 'work',
          level: 3,
          xp: 45,
          color: 0xFF10B981,
          history: const [1, 1, 2, 2, 2, 3, 3],
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(
          createSkillsTestWidget(
            child: Scaffold(body: SkillCard(skill: skill)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Public Speaking'), findsOneWidget);
        expect(find.text('Level 3'), findsOneWidget);
        expect(find.text('45 / 100 XP'), findsOneWidget);
        expect(find.byType(DatedSkillSparkline), findsOneWidget);
      },
    );

    testWidgets('RadarChartWidget renders without errors for skills list', (
      tester,
    ) async {
      final now = DateTime.now();
      final skills = [
        SkillModel(
          id: '1',
          name: 'Coding',
          category: 'work',
          level: 5,
          xp: 20,
          createdAt: now,
          updatedAt: now,
        ),
        SkillModel(
          id: '2',
          name: 'Fitness',
          category: 'health',
          level: 4,
          xp: 50,
          createdAt: now,
          updatedAt: now,
        ),
        SkillModel(
          id: '3',
          name: 'Reading',
          category: 'study',
          level: 3,
          xp: 80,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await tester.pumpWidget(
        createSkillsTestWidget(
          child: Scaffold(body: RadarChartWidget(skills: skills)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RadarChartWidget), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets(
      'SkillQuickUpdateDialog renders level and XP fields and handles edits',
      (tester) async {
        final now = DateTime.now();
        final skill = SkillModel(
          id: 's1',
          name: 'Design',
          category: 'work',
          level: 2,
          xp: 30,
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(
          createSkillsTestWidget(
            child: Scaffold(body: SkillQuickUpdateDialog(skill: skill)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Quick Skill Update'), findsOneWidget);
        expect(find.text('2'), findsOneWidget);
        expect(find.text('30'), findsOneWidget);
      },
    );

    testWidgets('SkillFormModal validates required name field', (tester) async {
      await tester.pumpWidget(
        createSkillsTestWidget(child: const Scaffold(body: SkillFormModal())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add New Skill'), findsOneWidget);

      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Skill name is required'), findsOneWidget);
    });

    testWidgets(
      'SkillsBoardPage renders empty state and switches to skills list when populated',
      (tester) async {
        // 1. Empty state
        await tester.pumpWidget(
          createSkillsTestWidget(
            child: const SkillsBoardPage(),
            overrides: [
              skillsStreamProvider.overrideWithValue(const AsyncData([])),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Skills Board'), findsOneWidget);
        expect(find.text('No skills added yet 🎯'), findsOneWidget);

        // 2. Populated list
        final now = DateTime.now();
        final skills = [
          SkillModel(
            id: 's1',
            name: 'Architecture',
            category: 'work',
            level: 4,
            xp: 75,
            createdAt: now,
            updatedAt: now,
          ),
        ];

        await tester.pumpWidget(
          createSkillsTestWidget(
            child: const SkillsBoardPage(),
            overrides: [
              skillsStreamProvider.overrideWithValue(AsyncData(skills)),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Architecture'), findsOneWidget);
        expect(find.text('Level 4'), findsOneWidget);
        expect(find.text('All Skills'), findsOneWidget);
      },
    );

    testWidgets(
      'Navigation Drawer contains Skills Board item in Learning section',
      (tester) async {
        await tester.pumpWidget(
          createSkillsTestWidget(
            child: const HomeScreen(),
            overrides: [
              skillsStreamProvider.overrideWithValue(const AsyncData([])),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Open Navigation Drawer
        final menuButton = find.byTooltip('Open navigation menu');
        expect(menuButton, findsOneWidget);
        await tester.tap(menuButton);
        await tester.pumpAndSettle();

        // Scroll inside drawer to find "Skills Board"
        final drawerScrollable = find.descendant(
          of: find.byType(Drawer),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.text('Skills Board'),
          50,
          scrollable: drawerScrollable,
        );
        expect(find.text('Skills Board'), findsOneWidget);
      },
    );
  });
}
