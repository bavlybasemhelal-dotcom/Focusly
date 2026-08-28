import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/reading_tracker/books_shelves_page.dart';
import 'package:focusly/features/reading_tracker/helpers/reading_streak_logic.dart';
import 'package:focusly/features/reading_tracker/models/book_model.dart';
import 'package:focusly/features/reading_tracker/models/reading_log_model.dart';
import 'package:focusly/features/reading_tracker/providers/reading_provider.dart';
import 'package:focusly/features/reading_tracker/widgets/book_card.dart';
import 'package:focusly/features/reading_tracker/widgets/book_form_modal.dart';
import 'package:focusly/features/reading_tracker/widgets/quick_update_dialog.dart';
import 'package:focusly/features/reading_tracker/widgets/reading_stats_header.dart';
import 'package:focusly/features/rituals/providers/rituals_provider.dart';
import 'package:focusly/screens/home_screen.dart';

class MockDismissedNotifier extends MorningIntentionDismissedNotifier {
  @override
  bool build() => true;
}

Widget createReadingTrackerTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_reading'),
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
  group('Reading Streak Logic Pure Function Tests', () {
    test('calculateReadingStreak returns 0 for empty logs list', () {
      expect(ReadingStreakLogic.calculateReadingStreak([]), equals(0));
    });

    test('calculateReadingStreak counts consecutive days starting from today', () {
      final now = DateTime(2026, 8, 24, 15, 0); // Monday
      final logs = [
        DateTime(2026, 8, 24, 10, 0), // Today
        DateTime(2026, 8, 23, 20, 0), // Yesterday
        DateTime(2026, 8, 22, 18, 0), // 2 days ago
      ];

      final streak = ReadingStreakLogic.calculateReadingStreak(logs, now);
      expect(streak, equals(3));
    });

    test('calculateReadingStreak applies leniency when today is unlogged but yesterday is logged', () {
      final now = DateTime(2026, 8, 24, 9, 0); // Monday (not yet logged today)
      final logs = [
        DateTime(2026, 8, 23, 21, 0), // Yesterday
        DateTime(2026, 8, 22, 19, 0), // 2 days ago
        DateTime(2026, 8, 21, 14, 0), // 3 days ago
      ];

      final streak = ReadingStreakLogic.calculateReadingStreak(logs, now);
      expect(streak, equals(3));
    });

    test('calculateReadingStreak resets to 0 when gap is larger than 1 day', () {
      final now = DateTime(2026, 8, 24, 12, 0); // Monday
      final logs = [
        DateTime(2026, 8, 22, 10, 0), // Saturday (2 days ago, missed Sunday)
        DateTime(2026, 8, 21, 10, 0),
      ];

      final streak = ReadingStreakLogic.calculateReadingStreak(logs, now);
      expect(streak, equals(0));
    });

    test('calculateReadingStreak handles duplicate entries on the same day cleanly', () {
      final now = DateTime(2026, 8, 24, 12, 0);
      final logs = [
        DateTime(2026, 8, 24, 8, 0),
        DateTime(2026, 8, 24, 14, 0),
        DateTime(2026, 8, 24, 21, 0),
        DateTime(2026, 8, 23, 10, 0),
      ];

      final streak = ReadingStreakLogic.calculateReadingStreak(logs, now);
      expect(streak, equals(2));
    });
  });

  group('Book Model & Serialization Tests', () {
    test('BookModel serializes toMap and deserializes fromMap correctly', () {
      final now = DateTime(2026, 8, 24, 10, 0);
      final book = BookModel(
        id: 'book_1',
        title: 'Deep Work',
        author: 'Cal Newport',
        totalPages: 300,
        currentPage: 150,
        status: 'reading',
        coverColor: 0xFF2E6FF2,
        notes: 'Rules for focused success in a distracted world.',
        createdAt: now,
        updatedAt: now,
      );

      final map = book.toMap();
      expect(map['id'], equals('book_1'));
      expect(map['title'], equals('Deep Work'));
      expect(map['author'], equals('Cal Newport'));
      expect(map['totalPages'], equals(300));
      expect(map['currentPage'], equals(150));
      expect(map['status'], equals('reading'));
      expect(map['coverColor'], equals(0xFF2E6FF2));

      final reconstructed = BookModel.fromMap(map, 'book_1');
      expect(reconstructed.id, equals('book_1'));
      expect(reconstructed.title, equals(book.title));
      expect(reconstructed.author, equals(book.author));
      expect(reconstructed.totalPages, equals(300));
      expect(reconstructed.currentPage, equals(150));
      expect(reconstructed.progressPercent, equals(50));
      expect(reconstructed.isFinished, isFalse);
    });

    test('BookModel copyWith and progress percentage calculation work correctly', () {
      final now = DateTime(2026, 8, 24);
      final b1 = BookModel(
        id: 'b1',
        title: 'Atomic Habits',
        author: 'James Clear',
        totalPages: 250,
        currentPage: 200,
        createdAt: now,
        updatedAt: now,
      );

      expect(b1.progressPercent, equals(80)); // 200 / 250 = 80%

      final b2 = b1.copyWith(
        currentPage: 250,
        status: 'done',
        finishDate: now,
        rating: 5,
      );

      expect(b2.progressPercent, equals(100));
      expect(b2.isFinished, isTrue);
      expect(b2.rating, equals(5));
      expect(b1 == b2, isFalse);
    });
  });

  group('Reading Tracker Providers Tests', () {
    test('readingShelfProviders separate books into Reading, Wishlist, and Finished', () {
      final now = DateTime.now();
      final books = [
        BookModel(
          id: '1',
          title: 'Reading Book 1',
          author: 'Author A',
          status: 'reading',
          createdAt: now,
          updatedAt: now,
        ),
        BookModel(
          id: '2',
          title: 'Paused Book 2',
          author: 'Author B',
          status: 'paused',
          createdAt: now,
          updatedAt: now,
        ),
        BookModel(
          id: '3',
          title: 'Wishlist Book 3',
          author: 'Author C',
          status: 'wishlist',
          createdAt: now,
          updatedAt: now,
        ),
        BookModel(
          id: '4',
          title: 'Finished Book 4',
          author: 'Author D',
          status: 'done',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          booksStreamProvider.overrideWithValue(AsyncData(books)),
          readingLogsStreamProvider.overrideWithValue(const AsyncData([])),
        ],
      );
      addTearDown(container.dispose);

      final readingShelf = container.read(readingShelfBooksProvider);
      expect(readingShelf.length, equals(2)); // reading + paused

      final wishlistShelf = container.read(wishlistShelfBooksProvider);
      expect(wishlistShelf.length, equals(1));
      expect(wishlistShelf.first.title, equals('Wishlist Book 3'));

      final finishedShelf = container.read(finishedShelfBooksProvider);
      expect(finishedShelf.length, equals(1));
      expect(finishedShelf.first.title, equals('Finished Book 4'));
    });

    test('readingStatsProvider computes aggregate statistics correctly', () {
      final now = DateTime.now();
      final books = [
        BookModel(
          id: '1',
          title: 'Book 1',
          author: 'A',
          totalPages: 200,
          currentPage: 100,
          status: 'reading',
          createdAt: now,
          updatedAt: now,
        ),
        BookModel(
          id: '2',
          title: 'Book 2',
          author: 'B',
          totalPages: 300,
          currentPage: 300,
          status: 'done',
          createdAt: now,
          updatedAt: now,
        ),
        BookModel(
          id: '3',
          title: 'Book 3',
          author: 'C',
          totalPages: 150,
          currentPage: 0,
          status: 'wishlist', // Wishlist excluded from pages read totals
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final container = ProviderContainer(
        overrides: [
          booksStreamProvider.overrideWithValue(AsyncData(books)),
          readingLogsStreamProvider.overrideWithValue(const AsyncData([])),
        ],
      );
      addTearDown(container.dispose);

      final stats = container.read(readingStatsProvider);
      expect(stats.booksFinished, equals(1));
      expect(stats.currentlyReading, equals(1));
      expect(stats.totalPagesRead, equals(400)); // 100 + 300
      expect(stats.totalPossiblePages, equals(500)); // 200 + 300
      expect(stats.overallProgressPercent, equals(80)); // 400 / 500 = 80%
    });
  });

  group('Reading Tracker UI & Widget Tests', () {
    testWidgets('BookCard renders title, author, progress bar, and badge', (tester) async {
      final now = DateTime.now();
      final book = BookModel(
        id: '1',
        title: 'Essentialism',
        author: 'Greg McKeown',
        totalPages: 260,
        currentPage: 130,
        status: 'reading',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        createReadingTrackerTestWidget(
          child: Scaffold(body: BookCard(book: book)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Essentialism'), findsNWidgets(2)); // On cover and card title
      expect(find.text('Greg McKeown'), findsNWidgets(2)); // On cover and card author
      expect(find.text('📖 Reading'), findsOneWidget);
      expect(find.text('130 / 260 pages (50%)'), findsOneWidget);
    });

    testWidgets('QuickUpdateDialog validates page bounds against total and current pages', (tester) async {
      final now = DateTime.now();
      final book = BookModel(
        id: '2',
        title: 'Clean Code',
        author: 'Robert C. Martin',
        totalPages: 400,
        currentPage: 100,
        status: 'reading',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        createReadingTrackerTestWidget(
          child: Scaffold(body: QuickUpdateDialog(book: book)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quick Page Update'), findsOneWidget);

      // Enter a page lower than current page (e.g. 50 < 100)
      final field = find.byType(TextField);
      await tester.enterText(field, '50');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Page must be between 100 and 400'), findsOneWidget);
    });

    testWidgets('BookFormModal validates title and author required fields', (tester) async {
      await tester.pumpWidget(
        createReadingTrackerTestWidget(
          child: const Scaffold(body: BookFormModal()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add New Book'), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      // Attempt save without title & author
      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Title and author are required'), findsOneWidget);
    });

    testWidgets('BookFormModal automatically updates Current Page to Total Pages when Status is set to Finished', (tester) async {
      await tester.pumpWidget(
        createReadingTrackerTestWidget(
          child: const Scaffold(body: BookFormModal()),
        ),
      );
      await tester.pumpAndSettle();

      // Find Total Pages and Current Page text fields
      final textFields = find.byType(TextField);
      // TextField 0: Title, 1: Author, 2: Total Pages (default '200'), 3: Current Page (default '0')
      expect(tester.widget<TextField>(textFields.at(2)).controller?.text, '200');
      expect(tester.widget<TextField>(textFields.at(3)).controller?.text, '0');

      // Change Status to Finished ('done') via Dropdown
      final dropdown = find.byType(DropdownButton<String>);
      await tester.tap(dropdown);
      await tester.pumpAndSettle();

      // Tap "Finished" in the dropdown menu
      await tester.tap(find.text('✅ Finished').last);
      await tester.pumpAndSettle();

      // Verify Current Page immediately snapped to match Total Pages (200)
      expect(tester.widget<TextField>(textFields.at(3)).controller?.text, '200');

      // Change Status back to "Reading"
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('📖 Reading').last);
      await tester.pumpAndSettle();

      // Verify Current Page remains at 200 (not reset or forced down)
      expect(tester.widget<TextField>(textFields.at(3)).controller?.text, '200');

      // Set Total Pages to 320 and Status to Finished again
      await tester.enterText(textFields.at(2), '320');
      await tester.pumpAndSettle();

      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('✅ Finished').last);
      await tester.pumpAndSettle();

      // Verify Current Page snapped to 320
      expect(tester.widget<TextField>(textFields.at(3)).controller?.text, '320');

      // Test reverse sync: Reset status to Reading and current page to 100, then type 320 into current page
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text('📖 Reading').last);
      await tester.pumpAndSettle();

      await tester.enterText(textFields.at(3), '100');
      await tester.pumpAndSettle();
      expect(find.text('📖 Reading'), findsWidgets);

      await tester.enterText(textFields.at(3), '320');
      await tester.pumpAndSettle();

      // Verify Status automatically flipped to 'done' (Finished)
      expect(find.text('✅ Finished'), findsWidgets);
    });

    testWidgets('ReadingStatsHeader renders 4 stat cards', (tester) async {
      await tester.pumpWidget(
        createReadingTrackerTestWidget(
          child: const Scaffold(body: ReadingStatsHeader()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reading Streak'), findsOneWidget);
      expect(find.text('Reading'), findsOneWidget);
      expect(find.text('Finished'), findsOneWidget);
      expect(find.text('Pages Read'), findsOneWidget);
    });

    testWidgets('BooksShelvesPage renders all 3 shelves and empty state messages', (tester) async {
      await tester.pumpWidget(
        createReadingTrackerTestWidget(
          child: const BooksShelvesPage(),
          overrides: [
            booksStreamProvider.overrideWithValue(const AsyncData([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reading Tracker'), findsOneWidget);
      expect(find.text('Reading'), findsWidgets);
      expect(find.text('Wishlist'), findsOneWidget);
      expect(find.text('Finished'), findsWidgets);
      expect(find.text('No books in progress. Tap \'+ Add Book\' to start!'), findsOneWidget);
      expect(find.text('Your wishlist is empty'), findsOneWidget);
      expect(find.text('You haven\'t finished a book yet. Keep reading!'), findsOneWidget);
    });

    testWidgets('Navigation Drawer contains Reading Tracker in Learning section', (tester) async {
      await tester.pumpWidget(
        createReadingTrackerTestWidget(
          child: const HomeScreen(),
          overrides: [
            booksStreamProvider.overrideWithValue(const AsyncData([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Open Navigation Drawer
      final menuButton = find.byTooltip('Open navigation menu');
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      // Scroll inside the drawer and verify "Reading Tracker"
      final drawerScrollable = find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Reading Tracker'),
        50,
        scrollable: drawerScrollable,
      );
      expect(find.text('Reading Tracker'), findsOneWidget);
    });
  });
}
