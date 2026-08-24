import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/para/models/para_project_model.dart';
import 'package:focusly/features/para/providers/para_provider.dart';
import 'package:focusly/features/project_retrospective/models/retrospective_model.dart';
import 'package:focusly/features/project_retrospective/providers/retrospective_provider.dart';
import 'package:focusly/features/project_retrospective/retrospective_page.dart';
import 'package:focusly/features/project_retrospective/widgets/retrospective_card.dart';
import 'package:focusly/features/project_retrospective/widgets/retrospective_form_modal.dart';
import 'package:focusly/features/rituals/providers/rituals_provider.dart';
import 'package:focusly/screens/home_screen.dart';

class MockDismissedNotifier extends MorningIntentionDismissedNotifier {
  @override
  bool build() => true;
}

Widget createRetrospectiveTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_retros'),
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
  group('Project Retrospective Model Tests', () {
    test('RetrospectiveModel serializes toMap and deserializes fromMap correctly', () {
      final now = DateTime(2026, 8, 24, 11, 0);
      final retro = RetrospectiveModel(
        id: 'retro_1',
        projectId: 'proj_mobile_v2',
        date: now,
        wentWell: 'Shipped design system overhaul 2 days ahead of schedule.',
        toImprove: 'Underestimated QA testing matrix on Android tablets.',
        learnings: 'Allocate at least 3 dedicated days for cross-device QA testing.',
        createdAt: now,
        updatedAt: now,
      );

      final map = retro.toMap();
      expect(map['id'], equals('retro_1'));
      expect(map['projectId'], equals('proj_mobile_v2'));
      expect(map['wentWell'], equals('Shipped design system overhaul 2 days ahead of schedule.'));
      expect(map['toImprove'], equals('Underestimated QA testing matrix on Android tablets.'));
      expect(map['learnings'], equals('Allocate at least 3 dedicated days for cross-device QA testing.'));

      final reconstructed = RetrospectiveModel.fromMap(map, 'retro_1');
      expect(reconstructed.id, equals('retro_1'));
      expect(reconstructed.projectId, equals(retro.projectId));
      expect(reconstructed.wentWell, equals(retro.wentWell));
      expect(reconstructed.toImprove, equals(retro.toImprove));
      expect(reconstructed.learnings, equals(retro.learnings));
    });

    test('RetrospectiveModel copyWith and equality work correctly', () {
      final now = DateTime(2026, 8, 24);
      final r1 = RetrospectiveModel(
        id: '1',
        projectId: 'p1',
        date: now,
        wentWell: 'Great velocity',
        toImprove: 'Tech debt',
        learnings: 'Write more unit tests',
        createdAt: now,
        updatedAt: now,
      );

      final r2 = r1.copyWith(
        wentWell: 'Exceptional velocity and team spirit',
      );

      expect(r2.wentWell, equals('Exceptional velocity and team spirit'));
      expect(r2.toImprove, equals(r1.toImprove));
      expect(r1 == r2, isFalse);

      final r3 = r1.copyWith();
      expect(r1 == r3, isTrue);
    });
  });

  group('Project Retrospective Providers Tests', () {
    test('projectTitleResolverProvider resolves title from PARA Projects', () {
      final now = DateTime.now();
      final projects = [
        ParaProjectModel(
          id: 'proj_alpha',
          title: 'Brand Refresh & Website Launch',
          areaId: 'area_marketing',
          createdAt: now,
        ),
        ParaProjectModel(
          id: 'proj_beta',
          title: 'Mobile App Performance Optimization',
          areaId: 'area_eng',
          createdAt: now,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          allParaProjectsStreamProvider.overrideWithValue(AsyncData(projects)),
        ],
      );
      addTearDown(container.dispose);

      final titleAlpha = container.read(projectTitleResolverProvider('proj_alpha'));
      expect(titleAlpha, equals('Brand Refresh & Website Launch'));

      final titleMissing = container.read(projectTitleResolverProvider('non_existent'));
      expect(titleMissing, isNull);
    });
  });

  group('Project Retrospective UI & Widget Tests', () {
    testWidgets('RetrospectiveCard renders project title and 3 inset blocks', (tester) async {
      final now = DateTime(2026, 8, 24);
      final retro = RetrospectiveModel(
        id: 'r100',
        projectId: 'proj_growth',
        date: now,
        wentWell: 'Strong user retention after onboarding refactor.',
        toImprove: 'Notification permissions were requested too early.',
        learnings: 'Delay notification prompt until user finishes first deep work session.',
        createdAt: now,
        updatedAt: now,
      );

      final projects = [
        ParaProjectModel(
          id: 'proj_growth',
          title: 'Q3 User Growth Campaign',
          areaId: 'area_growth',
          createdAt: now,
        ),
      ];

      await tester.pumpWidget(
        createRetrospectiveTestWidget(
          child: Scaffold(body: RetrospectiveCard(retrospective: retro)),
          overrides: [
            allParaProjectsStreamProvider.overrideWithValue(AsyncData(projects)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Q3 User Growth Campaign'), findsOneWidget);
      expect(find.text('🟢 What went well?'), findsOneWidget);
      expect(find.text('Strong user retention after onboarding refactor.'), findsOneWidget);
      expect(find.text('🔴 What needs improvement?'), findsOneWidget);
      expect(find.text('Notification permissions were requested too early.'), findsOneWidget);
      expect(find.text('🧠 Lessons learned & next steps'), findsOneWidget);
      expect(find.text('Delay notification prompt until user finishes first deep work session.'), findsOneWidget);
    });

    testWidgets('RetrospectiveCard falls back to unknown project label when project not found', (tester) async {
      final now = DateTime(2026, 8, 24);
      final retro = RetrospectiveModel(
        id: 'r200',
        projectId: 'deleted_project',
        date: now,
        wentWell: 'Wins',
        toImprove: 'Losses',
        learnings: 'Takeaways',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        createRetrospectiveTestWidget(
          child: Scaffold(body: RetrospectiveCard(retrospective: retro)),
          overrides: [
            allParaProjectsStreamProvider.overrideWithValue(const AsyncData([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('General / Unknown Project'), findsOneWidget);
    });

    testWidgets('RetrospectiveFormModal validates project and reflection fields', (tester) async {
      final now = DateTime.now();
      final projects = [
        ParaProjectModel(
          id: 'p1',
          title: 'Focusly Launch',
          areaId: 'area_product',
          createdAt: now,
        ),
      ];

      await tester.pumpWidget(
        createRetrospectiveTestWidget(
          child: const Scaffold(body: RetrospectiveFormModal()),
          overrides: [
            allParaProjectsStreamProvider.overrideWithValue(AsyncData(projects)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Retrospective'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      // Attempt save without selecting a project
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Please select a project'), findsOneWidget);

      // Open project dropdown and select project
      await tester.ensureVisible(find.text('-- Select Project --'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('-- Select Project --'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Focusly Launch').last);
      await tester.pumpAndSettle();

      // Attempt save with empty reflection fields
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('All review fields are required'), findsOneWidget);
    });

    testWidgets('RetrospectivePage renders empty state when no retrospectives exist', (tester) async {
      await tester.pumpWidget(
        createRetrospectiveTestWidget(
          child: const RetrospectivePage(),
          overrides: [
            retrospectivesStreamProvider.overrideWithValue(const AsyncData([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Project Retrospective'), findsOneWidget);
      expect(find.text('🔍 Log your first project retrospective'), findsOneWidget);
      expect(find.text('New Retrospective'), findsWidgets);
    });

    testWidgets('Navigation Drawer includes Project Retrospective in PARA section', (tester) async {
      await tester.pumpWidget(
        createRetrospectiveTestWidget(
          child: const HomeScreen(),
          overrides: [
            retrospectivesStreamProvider.overrideWithValue(const AsyncData([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Open drawer
      final menuButton = find.byTooltip('Open navigation menu');
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      // Scroll inside the drawer and verify "Project Retrospective" is present
      final drawerScrollable = find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Project Retrospective'),
        50,
        scrollable: drawerScrollable,
      );
      expect(find.text('Project Retrospective'), findsOneWidget);
    });
  });
}
