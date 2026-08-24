import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/knowledge_base/helpers/knowledge_filter_helper.dart';
import 'package:focusly/features/knowledge_base/knowledge_base_page.dart';
import 'package:focusly/features/knowledge_base/models/knowledge_entry_model.dart';
import 'package:focusly/features/knowledge_base/providers/knowledge_base_provider.dart';
import 'package:focusly/features/knowledge_base/widgets/entry_form_modal.dart';
import 'package:focusly/features/knowledge_base/widgets/knowledge_entry_card.dart';
import 'package:focusly/features/rituals/providers/rituals_provider.dart';
import 'package:focusly/screens/home_screen.dart';

class MockDismissedNotifier extends MorningIntentionDismissedNotifier {
  @override
  bool build() => true;
}

Widget createKnowledgeBaseTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_knowledge'),
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
  group('Knowledge Base Filter Helper Pure Function Tests', () {
    final now = DateTime.now();
    final sampleEntries = [
      KnowledgeEntryModel(
        id: '1',
        title: 'First Principles Thinking',
        type: 'idea',
        content: 'Break down complex problems into fundamental truths.',
        source: 'Elon Musk Interview',
        tags: const ['mental-models', 'problem-solving'],
        createdAt: now,
        updatedAt: now,
      ),
      KnowledgeEntryModel(
        id: '2',
        title: 'Riverpod State Management',
        type: 'note',
        content: 'Use Notifier and AsyncNotifier for declarative Flutter architecture.',
        source: 'Flutter Docs',
        tags: const ['flutter', 'dart', 'architecture'],
        createdAt: now,
        updatedAt: now,
      ),
      KnowledgeEntryModel(
        id: '3',
        title: 'Simplicity Quote',
        type: 'quote',
        content: 'Simplicity is prerequisite for reliability.',
        source: 'Edsger W. Dijkstra',
        tags: const ['programming', 'design'],
        createdAt: now,
        updatedAt: now,
      ),
    ];

    test('filterKnowledgeEntries filters by search query across title, content, source, and tags', () {
      // Search in title
      final byTitle = KnowledgeFilterHelper.filterKnowledgeEntries(
        entries: sampleEntries,
        query: 'principles',
        selectedType: 'all',
      );
      expect(byTitle.length, equals(1));
      expect(byTitle.first.id, equals('1'));

      // Search in content
      final byContent = KnowledgeFilterHelper.filterKnowledgeEntries(
        entries: sampleEntries,
        query: 'declarative',
        selectedType: 'all',
      );
      expect(byContent.length, equals(1));
      expect(byContent.first.id, equals('2'));

      // Search in source
      final bySource = KnowledgeFilterHelper.filterKnowledgeEntries(
        entries: sampleEntries,
        query: 'Dijkstra',
        selectedType: 'all',
      );
      expect(bySource.length, equals(1));
      expect(bySource.first.id, equals('3'));

      // Search in tags
      final byTag = KnowledgeFilterHelper.filterKnowledgeEntries(
        entries: sampleEntries,
        query: 'mental-models',
        selectedType: 'all',
      );
      expect(byTag.length, equals(1));
      expect(byTag.first.id, equals('1'));
    });

    test('filterKnowledgeEntries filters strictly by entry type', () {
      final ideas = KnowledgeFilterHelper.filterKnowledgeEntries(
        entries: sampleEntries,
        query: '',
        selectedType: 'idea',
      );
      expect(ideas.length, equals(1));
      expect(ideas.first.type, equals('idea'));

      final notes = KnowledgeFilterHelper.filterKnowledgeEntries(
        entries: sampleEntries,
        query: '',
        selectedType: 'note',
      );
      expect(notes.length, equals(1));
      expect(notes.first.type, equals('note'));

      final quotes = KnowledgeFilterHelper.filterKnowledgeEntries(
        entries: sampleEntries,
        query: '',
        selectedType: 'quote',
      );
      expect(quotes.length, equals(1));
      expect(quotes.first.type, equals('quote'));
    });

    test('parseTags splits comma-separated string, trims, and cleans # symbols', () {
      const raw = ' flutter , #dart, state-management ,  #architecture, , ';
      final parsed = KnowledgeFilterHelper.parseTags(raw);

      expect(parsed, equals(['flutter', 'dart', 'state-management', 'architecture']));
    });
  });

  group('KnowledgeEntryModel Serialization Tests', () {
    test('KnowledgeEntryModel serializes and deserializes accurately', () {
      final now = DateTime(2026, 8, 24, 10, 30);
      final entry = KnowledgeEntryModel(
        id: 'k_123',
        title: 'Deep Work Takeaways',
        type: 'summary',
        content: 'Work in focused stretches without any distractions.',
        source: 'Cal Newport',
        tags: const ['productivity', 'focus'],
        createdAt: now,
        updatedAt: now,
      );

      final map = entry.toMap();
      expect(map['title'], equals('Deep Work Takeaways'));
      expect(map['type'], equals('summary'));
      expect(map['source'], equals('Cal Newport'));
      expect(map['tags'], equals(['productivity', 'focus']));

      final reconstructed = KnowledgeEntryModel.fromMap(map, 'k_123');
      expect(reconstructed.id, equals('k_123'));
      expect(reconstructed.title, equals('Deep Work Takeaways'));
      expect(reconstructed.type, equals('summary'));
      expect(reconstructed.tags.length, equals(2));
    });
  });

  group('Knowledge Base UI & Widget Tests', () {
    testWidgets('KnowledgeEntryCard renders type badge, title, content, source, and tag chips', (tester) async {
      final now = DateTime.now();
      final entry = KnowledgeEntryModel(
        id: 'k_1',
        title: 'Atomic Habits Rule 1',
        type: 'note',
        content: 'Make it obvious by setting implementation intentions.',
        source: 'Atomic Habits Ch. 4',
        tags: const ['habits', 'psychology'],
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        createKnowledgeBaseTestWidget(
          child: Scaffold(body: KnowledgeEntryCard(entry: entry)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Atomic Habits Rule 1'), findsOneWidget);
      expect(find.text('Note'), findsOneWidget);
      expect(find.text('Make it obvious by setting implementation intentions.'), findsOneWidget);
      expect(find.text('Source: Atomic Habits Ch. 4'), findsOneWidget);
      expect(find.text('#habits'), findsOneWidget);
      expect(find.text('#psychology'), findsOneWidget);
    });

    testWidgets('EntryFormModal validates required title and content fields', (tester) async {
      await tester.pumpWidget(
        createKnowledgeBaseTestWidget(
          child: const Scaffold(body: EntryFormModal()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Knowledge Entry'), findsOneWidget);

      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Title and content are required'), findsOneWidget);
    });

    testWidgets('KnowledgeBasePage renders empty state and switches to entries list', (tester) async {
      // 1. Empty state
      await tester.pumpWidget(
        createKnowledgeBaseTestWidget(
          child: const KnowledgeBasePage(),
          overrides: [
            knowledgeEntriesStreamProvider.overrideWithValue(const AsyncData([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Knowledge Base'), findsOneWidget);
      expect(find.text('🧠 Capture your first note or idea'), findsOneWidget);

      // 2. Populated state
      final now = DateTime.now();
      final entries = [
        KnowledgeEntryModel(
          id: 'k1',
          title: 'System Design Patterns',
          type: 'note',
          content: 'Event-driven architecture decouples producers from consumers.',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await tester.pumpWidget(
        createKnowledgeBaseTestWidget(
          child: const KnowledgeBasePage(),
          overrides: [
            knowledgeEntriesStreamProvider.overrideWithValue(AsyncData(entries)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('System Design Patterns'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget); // Search bar
    });

    testWidgets('Navigation Drawer contains Knowledge Base item in Learning section', (tester) async {
      await tester.pumpWidget(
        createKnowledgeBaseTestWidget(
          child: const HomeScreen(),
          overrides: [
            knowledgeEntriesStreamProvider.overrideWithValue(const AsyncData([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Open Navigation Drawer
      final menuButton = find.byTooltip('Open navigation menu');
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      // Scroll inside drawer to find "Knowledge Base"
      final drawerScrollable = find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Knowledge Base'),
        50,
        scrollable: drawerScrollable,
      );
      expect(find.text('Knowledge Base'), findsOneWidget);
    });
  });
}
