import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/course_tracker/course_tracker_page.dart';
import 'package:focusly/features/course_tracker/helpers/course_status_helper.dart';
import 'package:focusly/features/course_tracker/models/course_model.dart';
import 'package:focusly/features/course_tracker/providers/course_tracker_provider.dart';
import 'package:focusly/features/course_tracker/widgets/course_card.dart';
import 'package:focusly/features/course_tracker/widgets/course_form_modal.dart';
import 'package:focusly/features/course_tracker/widgets/course_stats_header.dart';
import 'package:focusly/features/rituals/providers/rituals_provider.dart';
import 'package:focusly/screens/home_screen.dart';

class MockDismissedNotifier extends MorningIntentionDismissedNotifier {
  @override
  bool build() => true;
}

Widget createCourseTrackerTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_courses'),
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
  group('Course Status Helper Pure Function Tests', () {
    test(
      'normalizeCourseProgress clamps lesson counts and automatically manages status',
      () {
        // 1. Incomplete course retains active status
        final r1 = CourseStatusHelper.normalizeCourseProgress(
          totalLessons: 20,
          completedLessons: 12,
          manualStatus: 'active',
        );
        expect(r1.totalLessons, equals(20));
        expect(r1.completedLessons, equals(12));
        expect(r1.status, equals('active'));
        expect(r1.isNewlyCompleted, isFalse);

        // 2. 100% completion automatically switches status to 'completed'
        final r2 = CourseStatusHelper.normalizeCourseProgress(
          totalLessons: 20,
          completedLessons: 20,
          manualStatus: 'active',
          previousStatus: 'active',
        );
        expect(r2.status, equals('completed'));
        expect(r2.isNewlyCompleted, isTrue);

        // 3. Reducing lessons on a completed course reverts status back to 'active'
        final r3 = CourseStatusHelper.normalizeCourseProgress(
          totalLessons: 20,
          completedLessons: 19,
          manualStatus: 'completed',
          previousStatus: 'completed',
        );
        expect(r3.status, equals('active'));
        expect(r3.isNewlyCompleted, isFalse);

        // 4. Clamping overflow values
        final r4 = CourseStatusHelper.normalizeCourseProgress(
          totalLessons: -5, // minimum 1
          completedLessons: 99, // clamped to 1
          manualStatus: 'active',
        );
        expect(r4.totalLessons, equals(1));
        expect(r4.completedLessons, equals(1));
        expect(r4.status, equals('completed'));
      },
    );

    test(
      'adjustCompletedLessons adjusts stepper values and applies auto-status',
      () {
        final now = DateTime.now();
        final course = CourseModel(
          id: 'c1',
          title: 'Flutter Masterclass',
          totalLessons: 10,
          completedLessons: 9,
          status: 'active',
          createdAt: now,
          updatedAt: now,
        );

        // Increment: 9 -> 10 (auto completes)
        final inc = CourseStatusHelper.adjustCompletedLessons(course, 1);
        expect(inc.completedLessons, equals(10));
        expect(inc.status, equals('completed'));

        // Decrement on completed: 10 -> 9 (auto reverts to active)
        final dec = CourseStatusHelper.adjustCompletedLessons(inc, -1);
        expect(dec.completedLessons, equals(9));
        expect(dec.status, equals('active'));

        // Clamping at zero bound: 0 -> 0
        final zeroCourse = course.copyWith(completedLessons: 0);
        final clampedDec = CourseStatusHelper.adjustCompletedLessons(
          zeroCourse,
          -1,
        );
        expect(clampedDec.completedLessons, equals(0));
      },
    );
  });

  group('CourseModel Serialization & Stats Provider Tests', () {
    test('CourseModel serializes toMap and deserializes fromMap correctly', () {
      final now = DateTime(2026, 8, 24, 11, 0);
      final course = CourseModel(
        id: 'course_10',
        title: 'Fullstack Rust with Axum',
        platform: 'Udemy',
        totalLessons: 45,
        completedLessons: 30,
        status: 'active',
        certificate: true,
        note: 'Covers async tokio and sqlx.',
        createdAt: now,
        updatedAt: now,
      );

      final map = course.toMap();
      expect(map['title'], equals('Fullstack Rust with Axum'));
      expect(map['platform'], equals('Udemy'));
      expect(map['totalLessons'], equals(45));
      expect(map['completedLessons'], equals(30));
      expect(map['certificate'], isTrue);
      expect(map['note'], equals('Covers async tokio and sqlx.'));

      final reconstructed = CourseModel.fromMap(map, 'course_10');
      expect(reconstructed.id, equals('course_10'));
      expect(reconstructed.title, equals('Fullstack Rust with Axum'));
      expect(reconstructed.progressPercent, equals(67)); // 30 / 45 = 67%
      expect(reconstructed.isCompleted, isFalse);
    });
  });

  group('Course Tracker UI & Widget Tests', () {
    testWidgets(
      'CourseStatsHeader renders active, completed, and lessons watched totals',
      (tester) async {
        final now = DateTime.now();
        final courses = [
          CourseModel(
            id: '1',
            title: 'Course 1',
            totalLessons: 10,
            completedLessons: 10,
            status: 'completed',
            createdAt: now,
            updatedAt: now,
          ),
          CourseModel(
            id: '2',
            title: 'Course 2',
            totalLessons: 20,
            completedLessons: 5,
            status: 'active',
            createdAt: now,
            updatedAt: now,
          ),
          CourseModel(
            id: '3',
            title: 'Course 3',
            totalLessons: 15,
            completedLessons: 3,
            status: 'active',
            createdAt: now,
            updatedAt: now,
          ),
        ];

        await tester.pumpWidget(
          createCourseTrackerTestWidget(
            child: const Scaffold(body: CourseStatsHeader()),
            overrides: [
              coursesStreamProvider.overrideWithValue(AsyncData(courses)),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Active'), findsOneWidget);
        expect(find.text('2'), findsOneWidget); // 2 active
        expect(find.text('Completed'), findsOneWidget);
        expect(find.text('1'), findsOneWidget); // 1 completed
        expect(find.text('Lessons Done'), findsOneWidget);
        expect(find.text('18'), findsOneWidget); // 10 + 5 + 3 = 18
      },
    );

    testWidgets(
      'CourseCard renders status badge, platform, progress bar, and stepper buttons',
      (tester) async {
        final now = DateTime.now();
        final course = CourseModel(
          id: 'c1',
          title: 'Modern Clean Architecture',
          platform: 'Coursera',
          totalLessons: 15,
          completedLessons: 6,
          status: 'active',
          certificate: true,
          note: 'Solid separation of concerns.',
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(
          createCourseTrackerTestWidget(
            child: Scaffold(body: CourseCard(course: course)),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Modern Clean Architecture'), findsOneWidget);
        expect(find.text('Coursera'), findsOneWidget);
        expect(find.text('Active'), findsOneWidget);
        expect(find.text('Certificate earned'), findsOneWidget);
        expect(find.text('6 / 15 lessons (40%)'), findsOneWidget);
        expect(find.byIcon(Icons.add_rounded), findsOneWidget);
        expect(find.byIcon(Icons.remove_rounded), findsOneWidget);
      },
    );

    testWidgets(
      'CourseFormModal validates required title and total lessons fields',
      (tester) async {
        await tester.pumpWidget(
          createCourseTrackerTestWidget(
            child: const Scaffold(body: CourseFormModal()),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('New Course'), findsOneWidget);

        await tester.ensureVisible(find.text('Save'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(
          find.text('Title is required & Total Lessons must be greater than 0'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'CourseTrackerPage renders empty state and switches to populated list',
      (tester) async {
        // 1. Empty state
        await tester.pumpWidget(
          createCourseTrackerTestWidget(
            child: const CourseTrackerPage(),
            overrides: [
              coursesStreamProvider.overrideWithValue(const AsyncData([])),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Course Tracker'), findsOneWidget);
        expect(find.text('🎓 Add your first course'), findsOneWidget);

        // 2. Populated list
        final now = DateTime.now();
        final courses = [
          CourseModel(
            id: 'c1',
            title: 'Docker & Kubernetes Deep Dive',
            platform: 'Udemy',
            totalLessons: 30,
            completedLessons: 12,
            createdAt: now,
            updatedAt: now,
          ),
        ];

        await tester.pumpWidget(
          createCourseTrackerTestWidget(
            child: const CourseTrackerPage(),
            overrides: [
              coursesStreamProvider.overrideWithValue(AsyncData(courses)),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Docker & Kubernetes Deep Dive'), findsOneWidget);
        expect(find.text('12 / 30 lessons (40%)'), findsOneWidget);
      },
    );

    testWidgets(
      'Navigation Drawer contains Course Tracker item in Learning section',
      (tester) async {
        await tester.pumpWidget(
          createCourseTrackerTestWidget(
            child: const HomeScreen(),
            overrides: [
              coursesStreamProvider.overrideWithValue(const AsyncData([])),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Open Navigation Drawer
        final menuButton = find.byTooltip('Open navigation menu');
        expect(menuButton, findsOneWidget);
        await tester.tap(menuButton);
        await tester.pumpAndSettle();

        // Scroll inside drawer to find "Course Tracker"
        final drawerScrollable = find.descendant(
          of: find.byType(Drawer),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.text('Course Tracker'),
          50,
          scrollable: drawerScrollable,
        );
        expect(find.text('Course Tracker'), findsOneWidget);
      },
    );
  });
}
