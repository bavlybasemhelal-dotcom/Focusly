import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/rituals/providers/rituals_provider.dart';
import 'package:focusly/features/social_battery/helpers/social_battery_helpers.dart';
import 'package:focusly/features/social_battery/models/social_battery_entry_model.dart';
import 'package:focusly/features/social_battery/providers/social_battery_provider.dart';
import 'package:focusly/features/social_battery/social_battery_page.dart';
import 'package:focusly/features/social_battery/widgets/social_battery_entry_card.dart';
import 'package:focusly/features/social_battery/widgets/social_battery_form_modal.dart';
import 'package:focusly/features/social_battery/widgets/social_battery_summary_card.dart';
import 'package:focusly/screens/home_screen.dart';

class MockDismissedNotifier extends MorningIntentionDismissedNotifier {
  @override
  bool build() => true;
}

Widget createSocialBatteryTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_social_battery'),
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
  group('Social Battery Pure Helper & Calculation Tests', () {
    final now = DateTime(2026, 8, 24);

    test('calculateSummary accurately tallies net energy balance and counts', () {
      final entries = [
        SocialBatteryEntryModel(
          id: '1',
          name: 'Coffee with Alex',
          type: 'energizer',
          impact: 4,
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
        SocialBatteryEntryModel(
          id: '2',
          name: 'Team Brainstorm',
          type: 'energizer',
          impact: 5,
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
        SocialBatteryEntryModel(
          id: '3',
          name: 'Conflict Resolution Call',
          type: 'drainer',
          impact: 4,
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final summary = SocialBatteryHelpers.calculateSummary(entries);
      // Energizers: 4 + 5 = 9. Drainers: 4. Net = 9 - 4 = +5.
      expect(summary.netEnergyBalance, equals(5));
      expect(summary.formattedBalance, equals('+5'));
      expect(summary.energizersCount, equals(2));
      expect(summary.drainersCount, equals(1));
      expect(summary.totalEnergizerImpact, equals(9));
      expect(summary.totalDrainerImpact, equals(4));
    });

    test('calculateSummary handles negative net balance when drainers outweigh energizers', () {
      final entries = [
        SocialBatteryEntryModel(
          id: '1',
          name: 'Quick Standup',
          type: 'energizer',
          impact: 2,
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
        SocialBatteryEntryModel(
          id: '2',
          name: 'Tax Audit Meeting',
          type: 'drainer',
          impact: 5,
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final summary = SocialBatteryHelpers.calculateSummary(entries);
      // Net = 2 - 5 = -3.
      expect(summary.netEnergyBalance, equals(-3));
      expect(summary.formattedBalance, equals('-3'));
    });

    test('calculateSummary handles empty entries cleanly', () {
      final summary = SocialBatteryHelpers.calculateSummary([]);
      expect(summary.netEnergyBalance, equals(0));
      expect(summary.formattedBalance, equals('0'));
      expect(summary.energizersCount, equals(0));
      expect(summary.drainersCount, equals(0));
    });
  });

  group('SocialBatteryEntryModel Serialization Tests', () {
    test('SocialBatteryEntryModel serializes toMap and deserializes fromMap correctly', () {
      final now = DateTime(2026, 8, 24, 12, 0);
      final entry = SocialBatteryEntryModel(
        id: 'sb_1',
        name: 'Game Night with Friends',
        type: 'energizer',
        impact: 5,
        date: DateTime(2026, 8, 23),
        notes: 'Felt very energized and inspired afterwards.',
        createdAt: now,
        updatedAt: now,
      );

      final map = entry.toMap();
      expect(map['name'], equals('Game Night with Friends'));
      expect(map['type'], equals('energizer'));
      expect(map['impact'], equals(5));
      expect(map['notes'], contains('inspired afterwards'));

      final reconstructed = SocialBatteryEntryModel.fromMap(map, 'sb_1');
      expect(reconstructed.id, equals('sb_1'));
      expect(reconstructed.name, equals('Game Night with Friends'));
      expect(reconstructed.isEnergizer, isTrue);
      expect(reconstructed.isDrainer, isFalse);
      expect(reconstructed.signedImpact, equals(5));
    });
  });

  group('Social Battery UI & Widget Tests', () {
    testWidgets('SocialBatteryEntryCard renders name, type emoji, impact pill, and notes', (tester) async {
      final now = DateTime.now();
      final entry = SocialBatteryEntryModel(
        id: 'sb_10',
        name: 'Sprint Retro',
        type: 'drainer',
        impact: 3,
        date: now,
        notes: 'Too much debate over minor details.',
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        createSocialBatteryTestWidget(
          child: Scaffold(body: SocialBatteryEntryCard(entry: entry)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sprint Retro'), findsOneWidget);
      expect(find.text('🪫'), findsOneWidget);
      expect(find.text('drainer (-3)'), findsOneWidget);
      expect(find.text('Too much debate over minor details.'), findsOneWidget);
    });

    testWidgets('SocialBatterySummaryCard renders net balance and energizer/drainer counts', (tester) async {
      final now = DateTime.now();
      final entries = [
        SocialBatteryEntryModel(
          id: '1',
          name: 'Lunch with Daniel',
          type: 'energizer',
          impact: 4,
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
        SocialBatteryEntryModel(
          id: '2',
          name: 'Lengthy Commute',
          type: 'drainer',
          impact: 2,
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await tester.pumpWidget(
        createSocialBatteryTestWidget(
          child: const Scaffold(body: SocialBatterySummaryCard()),
          overrides: [
            socialBatteryStreamProvider.overrideWithValue(AsyncData(entries)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('+2'), findsOneWidget); // 4 - 2 = +2
      expect(find.text('Net Energy Balance'), findsOneWidget);
      expect(find.text('Energizers Count'), findsOneWidget);
      expect(find.text('1'), findsNWidgets(2)); // 1 energizer, 1 drainer
      expect(find.text('Drainers Count'), findsOneWidget);
    });

    testWidgets('SocialBatteryFormModal validates required name field and toggles type', (tester) async {
      await tester.pumpWidget(
        createSocialBatteryTestWidget(
          child: const Scaffold(body: SocialBatteryFormModal()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Log Social Energy'), findsOneWidget);
      expect(find.text('Energizer'), findsOneWidget);
      expect(find.text('Drainer'), findsOneWidget);

      await tester.ensureVisible(find.text('Save'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Name or event title is required'), findsOneWidget);
    });

    testWidgets('SocialBatteryPage renders log section, summary card, and empty states', (tester) async {
      await tester.pumpWidget(
        createSocialBatteryTestWidget(
          child: const SocialBatteryPage(),
          overrides: [
            socialBatteryStreamProvider.overrideWithValue(const AsyncData([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Social Battery'), findsOneWidget);
      expect(find.text('Social Battery Log'), findsOneWidget);
      expect(find.text('Energy Summary'), findsOneWidget);
      expect(find.text('🔋 Log your first social interaction'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(3)); // Net balance 0, Energizers 0, Drainers 0
    });

    testWidgets('Navigation Drawer contains Social Battery item in Relationships section', (tester) async {
      await tester.pumpWidget(
        createSocialBatteryTestWidget(
          child: const HomeScreen(),
          overrides: [
            socialBatteryStreamProvider.overrideWithValue(const AsyncData([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Open Navigation Drawer
      final menuButton = find.byTooltip('Open navigation menu');
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pumpAndSettle();

      // Scroll inside drawer to find "Social Battery"
      final drawerScrollable = find.descendant(
        of: find.byType(Drawer),
        matching: find.byType(Scrollable),
      );
      await tester.scrollUntilVisible(
        find.text('Social Battery'),
        50,
        scrollable: drawerScrollable,
      );
      expect(find.text('Social Battery'), findsOneWidget);
    });
  });
}
