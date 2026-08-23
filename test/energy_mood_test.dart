import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/core/auth/auth_provider.dart';
import 'package:focusly/core/localization/app_localizations.dart';
import 'package:focusly/core/theme/app_theme.dart';
import 'package:focusly/features/energy_mood/energy_mood_history_page.dart';
import 'package:focusly/features/energy_mood/models/checkin_model.dart';
import 'package:focusly/features/energy_mood/providers/energy_mood_provider.dart';
import 'package:focusly/features/energy_mood/widgets/checkin_sheet.dart';
import 'package:focusly/features/energy_mood/widgets/home_energy_mood_widget.dart';
import 'package:focusly/features/energy_mood/widgets/water_sleep_widgets.dart';

Widget createEnergyMoodTestWidget({
  required Widget child,
  List<dynamic> overrides = const [],
  Locale locale = const Locale('en'),
}) {
  return ProviderScope(
    overrides: [
      authStateStreamProvider.overrideWith((ref) => Stream.value(null)),
      currentUserIdProvider.overrideWithValue('test_user_energy'),
      ...overrides.cast(),
    ],
    child: MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('Energy & Mood Pure Calculation & Model Tests', () {
    test('computeSleepDurationFromTime correctly calculates standard and overnight sleep durations', () {
      // 1. Overnight sleep: 23:00 to 07:00 = 8.0 hours
      final overnight = computeSleepDurationFromTime(
        const TimeOfDay(hour: 23, minute: 0),
        const TimeOfDay(hour: 7, minute: 0),
      );
      expect(overnight, equals(8.0));

      // 2. Early morning bedtime: 01:30 to 09:00 = 7.5 hours
      final earlyMorning = computeSleepDurationFromTime(
        const TimeOfDay(hour: 1, minute: 30),
        const TimeOfDay(hour: 9, minute: 0),
      );
      expect(earlyMorning, equals(7.5));

      // 3. Afternoon nap: 14:00 to 16:30 = 2.5 hours
      final nap = computeSleepDurationFromTime(
        const TimeOfDay(hour: 14, minute: 0),
        const TimeOfDay(hour: 16, minute: 30),
      );
      expect(nap, equals(2.5));

      // 4. Exact 24h wrap or same time = 0.0 hours
      final zero = computeSleepDurationFromTime(
        const TimeOfDay(hour: 8, minute: 0),
        const TimeOfDay(hour: 8, minute: 0),
      );
      expect(zero, equals(0.0));
    });

    test('CheckinModel serializes and deserializes correctly', () {
      final now = DateTime(2026, 8, 23, 10, 0);
      final checkin = CheckinModel(
        date: '2026-08-23',
        energy: 4,
        mood: '🤩',
        note: 'Feeling super productive today!',
        water: 6,
        sleep: 7.5,
        sleepTime: '23:30',
        wakeTime: '07:00',
        sleepXpAwarded: true,
        waterXpGlassesAwarded: 6,
        createdAt: now,
        updatedAt: now,
      );

      final map = checkin.toMap();
      expect(map['date'], equals('2026-08-23'));
      expect(map['energy'], equals(4));
      expect(map['mood'], equals('🤩'));
      expect(map['water'], equals(6));
      expect(map['sleep'], equals(7.5));
      expect(map['sleepTime'], equals('23:30'));
      expect(map['wakeTime'], equals('07:00'));

      final reconstructed = CheckinModel.fromMap(map, '2026-08-23');
      expect(reconstructed.date, equals('2026-08-23'));
      expect(reconstructed.energy, equals(4));
      expect(reconstructed.mood, equals('🤩'));
      expect(reconstructed.energyLabelKey, equals('energy_level_4'));
      expect(reconstructed.note, equals('Feeling super productive today!'));
      expect(reconstructed.sleepXpAwarded, isTrue);

      final updated = reconstructed.copyWith(energy: 5, mood: '😊');
      expect(updated.energy, equals(5));
      expect(updated.mood, equals('😊'));
      expect(updated.energyLabelKey, equals('energy_level_5'));
    });
  });

  group('Energy & Mood Provider Tests', () {
    test('DailyWaterTargetNotifier updates water target correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(dailyWaterTargetProvider), equals(8));

      await container.read(dailyWaterTargetProvider.notifier).setTarget(10);
      expect(container.read(dailyWaterTargetProvider), equals(10));

      await container.read(dailyWaterTargetProvider.notifier).setTarget(0); // Clamped to min 1
      expect(container.read(dailyWaterTargetProvider), equals(1));

      await container.read(dailyWaterTargetProvider.notifier).setTarget(50); // Clamped to max 30
      expect(container.read(dailyWaterTargetProvider), equals(30));
    });

    test('DailyCheckinReminderNotifier toggles reminder preference', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(dailyCheckinReminderProvider), isTrue);

      await container.read(dailyCheckinReminderProvider.notifier).setEnabled(false);
      expect(container.read(dailyCheckinReminderProvider), isFalse);

      await container.read(dailyCheckinReminderProvider.notifier).setEnabled(true);
      expect(container.read(dailyCheckinReminderProvider), isTrue);
    });
  });

  group('Energy & Mood UI & Widget Tests', () {
    testWidgets('WaterTrackerWidget displays glasses, counter and responds to taps', (tester) async {
      final checkin = CheckinModel(
        date: '2026-08-23',
        energy: 4,
        mood: '😊',
        water: 5,
        sleep: 8.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        createEnergyMoodTestWidget(
          child: WaterTrackerWidget(
            dateStr: '2026-08-23',
            checkin: checkin,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Water Intake'), findsOneWidget);
      expect(find.text('5 / 8 glasses'), findsOneWidget);
    });

    testWidgets('SleepTrackerWidget renders bedtime and wake-up times', (tester) async {
      final checkin = CheckinModel(
        date: '2026-08-23',
        energy: 4,
        mood: '😊',
        water: 5,
        sleep: 8.0,
        sleepTime: '23:00',
        wakeTime: '07:00',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        createEnergyMoodTestWidget(
          child: SleepTrackerWidget(
            dateStr: '2026-08-23',
            checkin: checkin,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sleep Tracker'), findsOneWidget);
      expect(find.text('8.0 hrs'), findsOneWidget);
      expect(find.text('23:00'), findsOneWidget);
      expect(find.text('07:00'), findsOneWidget);
    });

    testWidgets('HomeEnergyMoodWidget renders prompt banner when today is not checked in', (tester) async {
      await tester.pumpWidget(
        createEnergyMoodTestWidget(
          child: const HomeEnergyMoodWidget(),
          overrides: [
            todayCheckinStreamProvider.overrideWith((ref) => Stream.value(null)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('How are you feeling today?'), findsOneWidget);
      expect(find.text('Tap to log your daily energy & mood'), findsOneWidget);
      expect(find.text('Check In'), findsOneWidget);
    });

    testWidgets('HomeEnergyMoodWidget renders compact summary card when checked in', (tester) async {
      final todayCheckin = CheckinModel(
        date: '2026-08-23',
        energy: 5,
        mood: '🤩',
        note: 'Super excited for today!',
        water: 6,
        sleep: 8.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        createEnergyMoodTestWidget(
          child: const HomeEnergyMoodWidget(),
          overrides: [
            todayCheckinStreamProvider.overrideWith((ref) => Stream.value(todayCheckin)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('🤩'), findsOneWidget);
      expect(find.text('Energy: Excellent'), findsOneWidget);
      expect(find.text('Super excited for today!'), findsOneWidget);
      expect(find.text('6/8 glasses'), findsOneWidget);
      expect(find.text('8.0 hrs'), findsOneWidget);
    });

    testWidgets('CheckinSheet renders energy options, mood options, and note field', (tester) async {
      await tester.pumpWidget(
        createEnergyMoodTestWidget(
          child: const CheckinSheet(),
          overrides: [
            checkinForDateStreamProvider('2026-08-23').overrideWith((ref) => Stream.value(null)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Daily Check-in'), findsOneWidget);
      expect(find.text('Energy Level'), findsOneWidget);
      expect(find.text('Mood'), findsOneWidget);
      expect(find.text('Save Check-in'), findsOneWidget);
      expect(find.text('🤩'), findsOneWidget);
    });

    testWidgets('EnergyMoodHistoryPage renders trend card, history list and entries', (tester) async {
      final list = [
        CheckinModel(
          date: '2026-08-23',
          energy: 4,
          mood: '😊',
          note: 'Great productive day',
          water: 8,
          sleep: 7.5,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        createEnergyMoodTestWidget(
          child: const EnergyMoodHistoryPage(),
          overrides: [
            checkinsHistoryStreamProvider.overrideWith((ref) => Stream.value(list)),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Energy & Mood History'), findsOneWidget);
      expect(find.text('Energy Trends'), findsOneWidget);
      expect(find.text('Past Check-ins'), findsOneWidget);
      expect(find.textContaining('Great productive day'), findsOneWidget);
      expect(find.text('8 glasses'), findsOneWidget);
    });
  });
}
