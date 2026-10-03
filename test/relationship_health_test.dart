import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/contacts/models/contact_model.dart';
import 'package:focusly/features/contacts/providers/contacts_provider.dart';
import 'package:focusly/features/relationship_health/helpers/relationship_health_helpers.dart';
import 'package:focusly/features/relationship_health/models/relationship_log_model.dart';
import 'package:focusly/features/relationship_health/providers/relationship_health_provider.dart';
import 'package:focusly/features/relationship_health/relationship_health_page.dart';
import 'package:focusly/features/relationship_health/widgets/interaction_card.dart';
import 'package:focusly/features/relationship_health/widgets/interaction_form_modal.dart';
import 'package:focusly/features/relationship_health/widgets/keep_in_touch_card.dart';
import 'package:focusly/features/rituals/providers/rituals_provider.dart';
import 'package:focusly/screens/home_screen.dart';

class MockDismissedNotifier extends MorningIntentionDismissedNotifier {
  @override
  bool build() => true;
}

Widget createRelationshipHealthTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_relationships'),
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
  group('Relationship Health Pure Helper & Recency Tests', () {
    final now = DateTime(2026, 8, 24);
    final contact = ContactModel(
      id: 'c1',
      name: 'Sarah Connor',
      emoji: '👩',
      role: 'Mentor',
      lastContact: DateTime(2026, 7, 1),
      createdAt: now,
      updatedAt: now,
    );

    test('computeRecency returns never when no interaction logs exist', () {
      final res = RelationshipHealthHelpers.computeRecency(contact, [], now);
      expect(res.category, equals(RecencyCategory.never));
      expect(res.days, isNull);
      expect(res.badgeColor, equals(const Color(0xFFEF4444)));
    });

    test('computeRecency returns recent (Green) when days <= 14', () {
      final log = RelationshipLogModel(
        id: 'l1',
        contactId: 'c1',
        date: DateTime(2026, 8, 20), // 4 days ago
        rating: 5,
        createdAt: now,
        updatedAt: now,
      );

      final res = RelationshipHealthHelpers.computeRecency(contact, [log], now);
      expect(res.category, equals(RecencyCategory.recent));
      expect(res.days, equals(4));
      expect(res.badgeColor, equals(const Color(0xFF10B981)));
    });

    test('computeRecency returns moderate (Amber) when 15 <= days <= 30', () {
      final log = RelationshipLogModel(
        id: 'l2',
        contactId: 'c1',
        date: DateTime(2026, 8, 4), // 20 days ago
        rating: 4,
        createdAt: now,
        updatedAt: now,
      );

      final res = RelationshipHealthHelpers.computeRecency(contact, [log], now);
      expect(res.category, equals(RecencyCategory.moderate));
      expect(res.days, equals(20));
      expect(res.badgeColor, equals(const Color(0xFFF59E0B)));
    });

    test('computeRecency returns overdue (Red) when days > 30', () {
      final log = RelationshipLogModel(
        id: 'l3',
        contactId: 'c1',
        date: DateTime(2026, 7, 10), // 45 days ago
        rating: 5,
        createdAt: now,
        updatedAt: now,
      );

      final res = RelationshipHealthHelpers.computeRecency(contact, [log], now);
      expect(res.category, equals(RecencyCategory.overdue));
      expect(res.days, equals(45));
      expect(res.badgeColor, equals(const Color(0xFFEF4444)));
    });
  });

  group('RelationshipLogModel Serialization Tests', () {
    test(
      'RelationshipLogModel serializes toMap and deserializes fromMap correctly',
      () {
        final now = DateTime(2026, 8, 24, 11, 0);
        final log = RelationshipLogModel(
          id: 'log_99',
          contactId: 'c_alex',
          date: DateTime(2026, 8, 22),
          rating: 5,
          notes: 'Great coffee catchup discussing AI architecture.',
          createdAt: now,
          updatedAt: now,
        );

        final map = log.toMap();
        expect(map['contactId'], equals('c_alex'));
        expect(map['rating'], equals(5));
        expect(
          map['notes'],
          equals('Great coffee catchup discussing AI architecture.'),
        );

        final reconstructed = RelationshipLogModel.fromMap(map, 'log_99');
        expect(reconstructed.id, equals('log_99'));
        expect(reconstructed.contactId, equals('c_alex'));
        expect(reconstructed.rating, equals(5));
        expect(reconstructed.notes, contains('AI architecture'));
      },
    );
  });

  group('Relationship Health UI & Widget Tests', () {
    testWidgets(
      'InteractionCard renders contact name, date, stars, and notes',
      (tester) async {
        final now = DateTime.now();
        final contact = ContactModel(
          id: 'c1',
          name: 'Elena Rostova',
          emoji: '👩‍💼',
          lastContact: now,
          createdAt: now,
          updatedAt: now,
        );

        final log = RelationshipLogModel(
          id: 'l1',
          contactId: 'c1',
          date: now,
          rating: 4,
          notes: 'Discussed project deadlines & quarterly roadmap.',
          createdAt: now,
          updatedAt: now,
        );

        await tester.pumpWidget(
          createRelationshipHealthTestWidget(
            child: Scaffold(body: InteractionCard(log: log)),
            overrides: [
              contactsStreamProvider.overrideWithValue(AsyncData([contact])),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Elena Rostova'), findsOneWidget);
        expect(
          find.text('Discussed project deadlines & quarterly roadmap.'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.star_rounded), findsNWidgets(4));
      },
    );

    testWidgets('KeepInTouchCard renders contact info and recency badge', (
      tester,
    ) async {
      final now = DateTime.now();
      final contact = ContactModel(
        id: 'c1',
        name: 'Marcus Brody',
        emoji: '👨‍🏫',
        role: 'Dean',
        lastContact: now,
        createdAt: now,
        updatedAt: now,
      );

      final log = RelationshipLogModel(
        id: 'l1',
        contactId: 'c1',
        date: now,
        rating: 5,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        createRelationshipHealthTestWidget(
          child: Scaffold(body: KeepInTouchCard(contact: contact)),
          overrides: [
            relationshipLogsStreamProvider.overrideWithValue(AsyncData([log])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Marcus Brody'), findsOneWidget);
      expect(find.text('Dean'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('InteractionFormModal validates required contact selection', (
      tester,
    ) async {
      await tester.pumpWidget(
        createRelationshipHealthTestWidget(
          child: const Scaffold(body: InteractionFormModal()),
          overrides: [
            contactsStreamProvider.overrideWithValue(const AsyncData([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('New Interaction'), findsOneWidget);

      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Please select a contact'), findsOneWidget);
    });

    testWidgets(
      'RelationshipHealthPage renders both sections and empty states',
      (tester) async {
        await tester.pumpWidget(
          createRelationshipHealthTestWidget(
            child: const RelationshipHealthPage(),
            overrides: [
              relationshipLogsStreamProvider.overrideWithValue(
                const AsyncData([]),
              ),
              contactsStreamProvider.overrideWithValue(const AsyncData([])),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Relationship Health'), findsOneWidget);
        expect(find.text('Recent Interactions'), findsOneWidget);
        expect(find.text('Keep In Touch'), findsOneWidget);
        expect(
          find.text('❤️ Log your first relationship interaction'),
          findsOneWidget,
        );
        expect(find.text('No contacts registered yet'), findsOneWidget);
      },
    );

    testWidgets(
      'Navigation Drawer contains Relationship Health item in Relationships section',
      (tester) async {
        await tester.pumpWidget(
          createRelationshipHealthTestWidget(
            child: const HomeScreen(),
            overrides: [
              relationshipLogsStreamProvider.overrideWithValue(
                const AsyncData([]),
              ),
              contactsStreamProvider.overrideWithValue(const AsyncData([])),
            ],
          ),
        );
        await tester.pumpAndSettle();

        // Open Navigation Drawer
        final menuButton = find.byTooltip('Open navigation menu');
        expect(menuButton, findsOneWidget);
        await tester.tap(menuButton);
        await tester.pumpAndSettle();

        // Scroll inside drawer to find "Relationship Health"
        final drawerScrollable = find.descendant(
          of: find.byType(Drawer),
          matching: find.byType(Scrollable),
        );
        await tester.scrollUntilVisible(
          find.text('Relationship Health'),
          50,
          scrollable: drawerScrollable,
        );
        expect(find.text('Relationship Health'), findsOneWidget);
      },
    );
  });
}
