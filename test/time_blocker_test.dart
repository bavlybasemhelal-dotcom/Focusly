import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/rituals/providers/rituals_provider.dart';
import 'package:focusly/features/schedule/models/event_model.dart';
import 'package:focusly/features/schedule/providers/schedule_provider.dart';
import 'package:focusly/features/time_blocker/helpers/time_blocker_helper.dart';
import 'package:focusly/features/time_blocker/models/time_block_type.dart';
import 'package:focusly/features/time_blocker/time_blocker_page.dart';
import 'package:focusly/screens/home_screen.dart';

Widget createTimeBlockerTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_time_blocker'),
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
      home: Scaffold(body: child),
    ),
  );
}

class MockDismissedNotifier extends MorningIntentionDismissedNotifier {
  @override
  bool build() => true;
}

void main() {
  group('TimeBlockType Enum & EventModel Tests', () {
    test('TimeBlockType parses string IDs and returns correct enum values', () {
      expect(TimeBlockType.fromString('deep'), equals(TimeBlockType.deep));
      expect(TimeBlockType.fromString('SHALLOW'), equals(TimeBlockType.shallow));
      expect(TimeBlockType.fromString('health'), equals(TimeBlockType.health));
      expect(TimeBlockType.fromString('leisure'), equals(TimeBlockType.leisure));
      expect(TimeBlockType.fromString('admin'), equals(TimeBlockType.admin));
      expect(TimeBlockType.fromString('invalid'), isNull);
      expect(TimeBlockType.fromString(null), isNull);
    });

    test('EventModel duration computation and time block flags work correctly', () {
      final now = DateTime.now();
      final standardEvent = EventModel(
        id: 'e1',
        title: 'Team Sync',
        date: now,
        time: const TimeOfDay(hour: 9, minute: 0),
        typeId: 'work_meeting',
        createdAt: now,
      );

      expect(standardEvent.isTimeBlock, isFalse);
      expect(standardEvent.timeBlockType, isNull);
      expect(standardEvent.effectiveDurationMinutes, equals(60));
      expect(standardEvent.endTime, equals(const TimeOfDay(hour: 10, minute: 0)));

      final blockEvent = EventModel(
        id: 'b1',
        title: 'Deep Architecture Design',
        date: now,
        time: const TimeOfDay(hour: 14, minute: 30),
        typeId: 'work_focus',
        blockType: 'deep',
        durationMinutes: 90,
        createdAt: now,
      );

      expect(blockEvent.isTimeBlock, isTrue);
      expect(blockEvent.timeBlockType, equals(TimeBlockType.deep));
      expect(blockEvent.effectiveDurationMinutes, equals(90));
      expect(blockEvent.endTime, equals(const TimeOfDay(hour: 16, minute: 0)));

      // Serialization roundtrip
      final map = blockEvent.toMap();
      expect(map['blockType'], equals('deep'));
      expect(map['durationMinutes'], equals(90));

      final restored = EventModel.fromMap(map, 'b1');
      expect(restored.blockType, equals('deep'));
      expect(restored.durationMinutes, equals(90));
    });
  });

  group('TimeBlockerHelper Unit Tests', () {
    test('doesBlockSpanHour accurately calculates 1-hour interval overlaps', () {
      final now = DateTime.now();
      // Block from 09:00 to 10:00 (duration: 60)
      final block1 = EventModel(
        id: 'b1',
        title: 'Morning Deep Work',
        date: now,
        time: const TimeOfDay(hour: 9, minute: 0),
        typeId: 'work',
        blockType: 'deep',
        durationMinutes: 60,
        createdAt: now,
      );

      expect(TimeBlockerHelper.doesBlockSpanHour(block1, 8), isFalse);
      expect(TimeBlockerHelper.doesBlockSpanHour(block1, 9), isTrue);
      expect(TimeBlockerHelper.doesBlockSpanHour(block1, 10), isFalse);

      // Multi-hour block from 13:30 to 15:30 (duration: 120)
      final block2 = EventModel(
        id: 'b2',
        title: 'Afternoon Sprint',
        date: now,
        time: const TimeOfDay(hour: 13, minute: 30),
        typeId: 'work',
        blockType: 'deep',
        durationMinutes: 120,
        createdAt: now,
      );

      expect(TimeBlockerHelper.doesBlockSpanHour(block2, 12), isFalse);
      expect(TimeBlockerHelper.doesBlockSpanHour(block2, 13), isTrue); // 13:00 - 14:00 overlaps 13:30
      expect(TimeBlockerHelper.doesBlockSpanHour(block2, 14), isTrue); // 14:00 - 15:00 fully covered
      expect(TimeBlockerHelper.doesBlockSpanHour(block2, 15), isTrue); // 15:00 - 16:00 overlaps 15:00-15:30
      expect(TimeBlockerHelper.doesBlockSpanHour(block2, 16), isFalse);
    });

    test('formatDuration & formatTimeRange produce expected localized formats', () {
      expect(TimeBlockerHelper.formatDuration(30), equals('30m'));
      expect(TimeBlockerHelper.formatDuration(60), equals('1h'));
      expect(TimeBlockerHelper.formatDuration(90), equals('1h 30m'));
      expect(TimeBlockerHelper.formatDuration(120), equals('2h'));

      final range = TimeBlockerHelper.formatTimeRange(
        const TimeOfDay(hour: 9, minute: 0),
        const TimeOfDay(hour: 10, minute: 30),
      );
      expect(range, equals('09:00 – 10:30'));
    });
  });

  group('TimeBlockerPage UI & Timeline Grid Tests', () {
    testWidgets('TimeBlockerPage renders 24-hour slots, empty placeholders, and summary stats', (tester) async {
      final now = DateTime.now();
      final testDate = DateTime(now.year, now.month, now.day);

      final block1 = EventModel(
        id: 'tb_1',
        title: 'Core Engine Coding',
        date: testDate,
        time: const TimeOfDay(hour: 10, minute: 0),
        typeId: 'work',
        blockType: 'deep',
        durationMinutes: 60,
        createdAt: testDate,
      );

      await tester.pumpWidget(
        createTimeBlockerTestWidget(
          child: const TimeBlockerPage(),
          overrides: [
            eventsStreamProvider.overrideWithValue(AsyncData([block1])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Title & Summary Verification
      expect(find.text('Time Blocker'), findsOneWidget);
      expect(find.textContaining('1 blocks • 1h planned'), findsOneWidget);

      // Hourly slots verification
      expect(find.text('00:00'), findsOneWidget);
      expect(find.text('01:00'), findsOneWidget);

      // Empty slot tap placeholder exists
      expect(find.text('+ Empty slot (tap to book)'), findsAtLeastNWidgets(1));

      // FAB is present
      expect(find.text('Add Block'), findsOneWidget);
    });

    testWidgets('TimeBlockerPage displays block type tag, title, and handles multi-hour spans', (tester) async {
      final now = DateTime.now();
      final testDate = DateTime(now.year, now.month, now.day);

      // Multi-hour block spanning 09:00 to 11:00 (2 hours)
      final multiHourBlock = EventModel(
        id: 'tb_multi',
        title: 'Deep Focus Sprint',
        date: testDate,
        time: const TimeOfDay(hour: 9, minute: 0),
        typeId: 'work',
        blockType: 'deep',
        durationMinutes: 120,
        createdAt: testDate,
      );

      await tester.pumpWidget(
        createTimeBlockerTestWidget(
          child: const TimeBlockerPage(),
          overrides: [
            eventsStreamProvider.overrideWithValue(AsyncData([multiHourBlock])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Scroll to hour 9
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // Start hour card (09:00) renders block type badge, title, time range
      expect(find.text('Deep Focus Sprint'), findsAtLeastNWidgets(1));
      expect(find.text('Deep Work'), findsOneWidget);
      expect(find.text('09:00 – 11:00 • 2h'), findsOneWidget);

      // Continuation hour (10:00) renders continuation label
      expect(find.textContaining('Continuing: Deep Focus Sprint'), findsOneWidget);
    });

    testWidgets('Tapping empty slot opens AddEditEventSheet with pre-filled start time', (tester) async {
      await tester.pumpWidget(
        createTimeBlockerTestWidget(
          child: const TimeBlockerPage(),
          overrides: [
            eventsStreamProvider.overrideWithValue(const AsyncData([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Find first empty slot placeholder and tap it
      final emptySlot = find.text('+ Empty slot (tap to book)').first;
      await tester.tap(emptySlot);
      await tester.pumpAndSettle();

      // Add / Edit sheet opens
      expect(find.text('New Event'), findsOneWidget);
      expect(find.text('Time Block Type'), findsOneWidget);
      expect(find.text('Deep Work'), findsOneWidget);
    });

    testWidgets('Date navigation next and previous day buttons update timeline date', (tester) async {
      await tester.pumpWidget(
        createTimeBlockerTestWidget(
          child: const TimeBlockerPage(),
          overrides: [
            eventsStreamProvider.overrideWithValue(const AsyncData([])),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Tap Next Day
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();

      // "Today" jump chip appears when navigating away from today
      expect(find.text('Today'), findsOneWidget);

      // Tap "Today" jump chip
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();

      // "Today" jump chip is removed when on today
      expect(find.text('Today'), findsNothing);
    });
  });

  group('Navigation Drawer Time Blocker Integration', () {
    testWidgets('Navigation Drawer includes Time Blocker menu item', (tester) async {
      await tester.pumpWidget(
        createTimeBlockerTestWidget(
          child: const HomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Open drawer
      await tester.tap(find.byTooltip('Open navigation menu'));
      await tester.pumpAndSettle();

      expect(find.text('Time Blocker'), findsOneWidget);
    });
  });
}
