import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/legacy_journal/legacy_journal_page.dart';
import 'package:focusly/features/legacy_journal/models/legacy_entry_model.dart';
import 'package:focusly/features/legacy_journal/providers/legacy_journal_provider.dart';
import 'package:focusly/features/legacy_journal/widgets/legacy_entry_form_modal.dart';
import 'package:focusly/features/rituals/providers/rituals_provider.dart';
import 'package:focusly/screens/home_screen.dart';

class MockDismissedNotifier extends MorningIntentionDismissedNotifier {
  @override
  bool build() => true;
}

Widget createLegacyJournalTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_legacy_journal'),
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
  final letterEntry = LegacyEntryModel(
    id: 'l1',
    title: 'Letter to My 35-Year-Old Self',
    date: DateTime(2026, 8, 25),
    type: 'letter',
    content: 'Remember why you started. Keep your calm and stay focused on what truly matters.',
    createdAt: DateTime(2026, 8, 25),
    updatedAt: DateTime(2026, 8, 25),
  );

  final valueEntry = LegacyEntryModel(
    id: 'v1',
    title: 'Relentless Curiosity & Empathy',
    date: DateTime(2026, 8, 20),
    type: 'value',
    content: 'Never assume you know everything. Listen deeply before offering solutions.',
    createdAt: DateTime(2026, 8, 20),
    updatedAt: DateTime(2026, 8, 20),
  );

  final willEntry = LegacyEntryModel(
    id: 'w1',
    title: 'Wisdom on Integrity & Family',
    date: DateTime(2026, 8, 15),
    type: 'will',
    content: 'Always choose long-term integrity over short-term gain. Family is the anchor.',
    createdAt: DateTime(2026, 8, 15),
    updatedAt: DateTime(2026, 8, 15),
  );

  group('LegacyEntryModel Unit Tests', () {
    test('Model serialization, type helpers and date formatting', () {
      final map = letterEntry.toMap();
      expect(map['title'], equals('Letter to My 35-Year-Old Self'));
      expect(map['type'], equals('letter'));
      expect(map['content'], contains('Remember why you started'));

      final deserialized = LegacyEntryModel.fromMap(map, 'l1');
      expect(deserialized.id, equals('l1'));
      expect(deserialized.title, equals('Letter to My 35-Year-Old Self'));
      expect(deserialized.isLetter, isTrue);
      expect(deserialized.isValue, isFalse);
      expect(deserialized.isWill, isFalse);
      expect(deserialized.formattedDate, equals('Aug 25, 2026'));

      expect(valueEntry.isValue, isTrue);
      expect(willEntry.isWill, isTrue);
    });

    test('copyWith updates specified fields correctly', () {
      final updated = letterEntry.copyWith(
        title: 'Updated Letter Title',
        type: 'value',
      );
      expect(updated.title, equals('Updated Letter Title'));
      expect(updated.type, equals('value'));
      expect(updated.content, equals(letterEntry.content)); // Unchanged
    });
  });

  group('LegacyJournalPage UI & Widget Tests', () {
    testWidgets('Renders empty state when 0 legacy entries exist', (tester) async {
      await tester.pumpWidget(
        createLegacyJournalTestWidget(
          child: const LegacyJournalPage(),
          overrides: [
            legacyJournalStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Legacy Journal'), findsOneWidget);
      expect(find.text('Record your legacy elements'), findsOneWidget);
      expect(find.text('New Entry'), findsWidgets);
    });

    testWidgets('Renders all 3 sections when entries exist for all types', (tester) async {
      await tester.pumpWidget(
        createLegacyJournalTestWidget(
          child: const LegacyJournalPage(),
          overrides: [
            legacyJournalStreamProvider.overrideWith(
              (ref) => Stream.value([letterEntry, valueEntry, willEntry]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Legacy Journal'), findsOneWidget);
      expect(find.text('✉️ Letters to Future Self'), findsOneWidget);
      expect(find.text('Letter to My 35-Year-Old Self'), findsOneWidget);

      expect(find.text('💎 Core Values & Beliefs'), findsOneWidget);
      expect(find.text('Relentless Curiosity & Empathy'), findsOneWidget);

      // Scroll down to reveal third section
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('📜 Will & Philosophy Guidelines'), findsOneWidget);
      expect(find.text('Wisdom on Integrity & Family'), findsOneWidget);
    });

    testWidgets('Skips rendering sections that have zero entries', (tester) async {
      await tester.pumpWidget(
        createLegacyJournalTestWidget(
          child: const LegacyJournalPage(),
          overrides: [
            legacyJournalStreamProvider.overrideWith(
              (ref) => Stream.value([letterEntry]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('✉️ Letters to Future Self'), findsOneWidget);
      expect(find.text('💎 Core Values & Beliefs'), findsNothing);
      expect(find.text('📜 Will & Philosophy Guidelines'), findsNothing);
    });

    testWidgets('Navigation Drawer includes Legacy Journal in Analytics section', (tester) async {
      await tester.pumpWidget(
        createLegacyJournalTestWidget(
          child: const HomeScreen(),
          overrides: [
            legacyJournalStreamProvider.overrideWith((ref) => Stream.value([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      final menuButton = find.byTooltip('Open navigation menu');
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      expect(find.text('ANALYTICS'), findsOneWidget);
      expect(find.text('Legacy Journal'), findsOneWidget);
    });

    testWidgets('Arabic localization renders all Legacy Journal texts', (tester) async {
      await tester.pumpWidget(
        createLegacyJournalTestWidget(
          locale: const Locale('ar'),
          child: const LegacyJournalPage(),
          overrides: [
            legacyJournalStreamProvider.overrideWith(
              (ref) => Stream.value([letterEntry, valueEntry]),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('دفتر الميراث والقيم'), findsOneWidget);
      expect(find.text('✉️ رسائل للنسخة المستقبلية'), findsOneWidget);
      expect(find.text('💎 القيم والمبادئ الجوهرية'), findsOneWidget);
    });
  });

  group('LegacyEntryFormModal Tests', () {
    testWidgets('Validates required title and content fields', (tester) async {
      await tester.pumpWidget(
        createLegacyJournalTestWidget(
          child: const Scaffold(
            body: LegacyEntryFormModal(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Legacy Entry'), findsOneWidget);

      // Scroll to save button and tap
      await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -400));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save Entry'));
      await tester.pumpAndSettle();

      expect(find.text('Title and content are required'), findsWidgets);
    });

    testWidgets('Renders pre-filled fields in edit mode and shows delete button', (tester) async {
      await tester.pumpWidget(
        createLegacyJournalTestWidget(
          child: Scaffold(
            body: LegacyEntryFormModal(
              entryToEdit: letterEntry,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Legacy Entry'), findsOneWidget);
      expect(find.text('Letter to My 35-Year-Old Self'), findsOneWidget);

      final deleteButton = find.byType(TextButton);
      await tester.ensureVisible(deleteButton);
      await tester.pumpAndSettle();

      expect(find.text('Save Entry'), findsOneWidget);
      expect(find.text('Delete Entry'), findsOneWidget);
    });
  });
}
