import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/rituals/providers/rituals_provider.dart';
import 'package:focusly/features/spaced_repetition/controllers/review_session_controller.dart';
import 'package:focusly/features/spaced_repetition/flashcards_list_page.dart';
import 'package:focusly/features/spaced_repetition/helpers/sm2_algorithm.dart';
import 'package:focusly/features/spaced_repetition/models/flashcard_model.dart';
import 'package:focusly/features/spaced_repetition/providers/flashcards_provider.dart';
import 'package:focusly/features/spaced_repetition/review_session_page.dart';
import 'package:focusly/features/spaced_repetition/session_summary_page.dart';
import 'package:focusly/features/spaced_repetition/widgets/flashcard_form_modal.dart';
import 'package:focusly/screens/home_screen.dart';

class MockDismissedNotifier extends MorningIntentionDismissedNotifier {
  @override
  bool build() => true;
}

Widget createFlashcardsTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_flashcards'),
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
  group('SM-2 Spaced Repetition Pure Algorithm Tests', () {
    final baseDate = DateTime(2026, 8, 24);

    test('calculate with Quality 1 (Forgot) resets interval to 1 and repetitions to 0', () {
      final res = Sm2Algorithm.calculate(
        currentInterval: 14,
        currentRepetitions: 4,
        currentEaseFactor: 2.5,
        quality: 1, // Forgot
        currentDate: baseDate,
      );

      expect(res.interval, equals(1));
      expect(res.repetitions, equals(0));
      expect(res.points, equals(0));
      expect(res.dueDate, equals('2026-08-25'));
    });

    test('calculate for first review (repetitions == 0) sets interval to 1', () {
      final res = Sm2Algorithm.calculate(
        currentInterval: 0,
        currentRepetitions: 0,
        currentEaseFactor: 2.5,
        quality: 3, // Good
        currentDate: baseDate,
      );

      expect(res.interval, equals(1));
      expect(res.repetitions, equals(1));
      expect(res.points, equals(5));
      expect(res.dueDate, equals('2026-08-25'));
    });

    test('calculate for second review (repetitions == 1) sets interval to 3', () {
      final res = Sm2Algorithm.calculate(
        currentInterval: 1,
        currentRepetitions: 1,
        currentEaseFactor: 2.5,
        quality: 4, // Easy
        currentDate: baseDate,
      );

      expect(res.interval, equals(3));
      expect(res.repetitions, equals(2));
      expect(res.points, equals(10));
      expect(res.dueDate, equals('2026-08-27'));
    });

    test('calculate for subsequent reviews (repetitions >= 2) scales interval by easeFactor', () {
      final res = Sm2Algorithm.calculate(
        currentInterval: 6,
        currentRepetitions: 2,
        currentEaseFactor: 2.5,
        quality: 3, // Good (5 pts)
        currentDate: baseDate,
      );

      // 6 * 2.5 = 15
      expect(res.interval, equals(15));
      expect(res.repetitions, equals(3));
      expect(res.points, equals(5));
      expect(res.dueDate, equals('2026-09-08'));
    });

    test('easeFactor is clamped to a minimum of 1.3', () {
      final res = Sm2Algorithm.calculate(
        currentInterval: 3,
        currentRepetitions: 2,
        currentEaseFactor: 1.3,
        quality: 2, // Hard lowers ease
        currentDate: baseDate,
      );

      expect(res.easeFactor, greaterThanOrEqualTo(1.3));
    });

    test('fisherYatesShuffle shuffles elements without losing items', () {
      final list = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
      final shuffled = Sm2Algorithm.fisherYatesShuffle(list);

      expect(shuffled.length, equals(list.length));
      expect(shuffled.toSet(), equals(list.toSet()));
    });
  });

  group('FlashcardModel Serialization & Due Date Tests', () {
    test('FlashcardModel serializes and deserializes accurately', () {
      final now = DateTime(2026, 8, 24, 10, 0);
      final card = FlashcardModel(
        id: 'card_1',
        front: 'What is idempotency?',
        back: 'An operation that produces the same result no matter how many times it is executed.',
        interval: 6,
        repetitions: 2,
        easeFactor: 2.6,
        dueDate: '2026-08-30',
        createdAt: now,
        updatedAt: now,
      );

      final map = card.toMap();
      expect(map['front'], equals('What is idempotency?'));
      expect(map['interval'], equals(6));
      expect(map['repetitions'], equals(2));
      expect(map['easeFactor'], equals(2.6));
      expect(map['dueDate'], equals('2026-08-30'));

      final reconstructed = FlashcardModel.fromMap(map, 'card_1');
      expect(reconstructed.id, equals('card_1'));
      expect(reconstructed.front, equals('What is idempotency?'));
      expect(reconstructed.back, contains('same result'));
      expect(reconstructed.isDueOn(now), isFalse);
    });
  });

  group('Spaced Repetition UI & Widget Tests', () {
    testWidgets('FlashcardsListPage renders review action buttons and flashcard rows', (tester) async {
      final now = DateTime.now();
      final todayStr =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

      final cards = [
        FlashcardModel(
          id: '1',
          front: 'CAP Theorem',
          back: 'Consistency, Availability, Partition Tolerance.',
          interval: 1,
          repetitions: 1,
          easeFactor: 2.5,
          dueDate: todayStr,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await tester.pumpWidget(
        createFlashcardsTestWidget(
          child: const FlashcardsListPage(),
          overrides: [
            flashcardsStreamProvider.overrideWithValue(AsyncData(cards)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Flashcards (SM-2)'), findsOneWidget);
      expect(find.text('Review Due Cards (1)'), findsOneWidget);
      expect(find.text('Review All Cards'), findsOneWidget);
      expect(find.text('CAP Theorem'), findsOneWidget);
      expect(find.text('Due today'), findsOneWidget);
    });

    testWidgets('FlashcardFormModal validates required front and back fields', (tester) async {
      await tester.pumpWidget(
        createFlashcardsTestWidget(
          child: const Scaffold(body: FlashcardFormModal()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Flashcard'), findsOneWidget);

      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Both front and back are required'), findsOneWidget);
    });

    testWidgets('ReviewSessionPage renders question, reveals answer, and shows 4 rating buttons', (tester) async {
      final now = DateTime.now();
      final card = FlashcardModel(
        id: 'c1',
        front: 'What is the Big-O of Binary Search?',
        back: 'O(log n)',
        interval: 1,
        repetitions: 1,
        easeFactor: 2.5,
        dueDate: '2026-08-24',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        createFlashcardsTestWidget(
          child: const ReviewSessionPage(),
        ),
      );

      // Start session with card
      final element = tester.element(find.byType(ReviewSessionPage));
      final container = ProviderScope.containerOf(element);
      container.read(reviewSessionControllerProvider.notifier).startSession([card]);

      await tester.pumpAndSettle();

      expect(find.text('Card 1 of 1'), findsOneWidget);
      expect(find.text('What is the Big-O of Binary Search?'), findsOneWidget);
      expect(find.text('Show Answer'), findsOneWidget);

      // Tap Show Answer
      await tester.tap(find.text('Show Answer'));
      await tester.pumpAndSettle();

      expect(find.text('O(log n)'), findsOneWidget);
      expect(find.text('Forgot'), findsOneWidget);
      expect(find.text('Hard'), findsOneWidget);
      expect(find.text('Good'), findsOneWidget);
      expect(find.text('Easy'), findsOneWidget);
    });

    testWidgets('SessionSummaryPage renders review totals and breakdown', (tester) async {
      await tester.pumpWidget(
        createFlashcardsTestWidget(
          child: const SessionSummaryPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Session Complete! 🎉'), findsWidgets);
      expect(find.text('Cards Reviewed'), findsOneWidget);
      expect(find.text('Points Earned'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('Navigation Drawer contains Flashcards item in Learning section', (tester) async {
      await tester.pumpWidget(
        createFlashcardsTestWidget(
          child: const HomeScreen(),
          overrides: [
            flashcardsStreamProvider.overrideWithValue(const AsyncData([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Open Navigation Drawer
      final menuButton = find.byTooltip('Open navigation menu');
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      // Scroll inside drawer to find "Flashcards (SM-2)"
      final drawerScrollable = find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Flashcards (SM-2)'),
        50,
        scrollable: drawerScrollable,
      );
      expect(find.text('Flashcards (SM-2)'), findsOneWidget);
    });
  });
}
