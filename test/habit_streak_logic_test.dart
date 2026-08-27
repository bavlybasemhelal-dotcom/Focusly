import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/features/habits/helpers/streak_logic.dart';
import 'package:focusly/features/habits/models/habit_model.dart';

void main() {
  group('Habits Streak Logic & Weekly Rollover Tests', () {
    test('getWeekDayIndex accurately maps dates to 0..6 based on week start day', () {
      // 2026-08-01 is a Saturday
      final sat = DateTime(2026, 8, 1);
      final sun = DateTime(2026, 8, 2);
      final mon = DateTime(2026, 8, 3);
      final fri = DateTime(2026, 8, 7);

      expect(StreakLogic.getWeekDayIndex(sat, weekStartDay: DateTime.saturday), 0);
      expect(StreakLogic.getWeekDayIndex(sun, weekStartDay: DateTime.saturday), 1);
      expect(StreakLogic.getWeekDayIndex(mon, weekStartDay: DateTime.saturday), 2);
      expect(StreakLogic.getWeekDayIndex(fri, weekStartDay: DateTime.saturday), 6);

      // Sunday week start
      expect(StreakLogic.getWeekDayIndex(sun, weekStartDay: DateTime.sunday), 0);
      expect(StreakLogic.getWeekDayIndex(mon, weekStartDay: DateTime.sunday), 1);
      expect(StreakLogic.getWeekDayIndex(sat, weekStartDay: DateTime.sunday), 6);
    });

    test('toggleHabitDay increments streak when day is marked complete', () {
      final habit = HabitModel.create(
        id: 'h1',
        title: 'Morning Meditation',
      );

      expect(habit.streak, 0);

      final toggled1 = StreakLogic.toggleHabitDay(habit, 0);
      expect(toggled1.isDayCompleted(0), isTrue);
      expect(toggled1.streak, 1);

      final toggled2 = StreakLogic.toggleHabitDay(toggled1, 1);
      expect(toggled2.isDayCompleted(1), isTrue);
      expect(toggled2.streak, 2);

      // Untoggling day 1 reduces streak
      final untoggled = StreakLogic.toggleHabitDay(toggled2, 1);
      expect(untoggled.isDayCompleted(1), isFalse);
      expect(untoggled.streak, 1);
    });

    test('evaluateWeeklyReset rolls over full 7-day streak into baseStreak', () {
      final baseDate = DateTime(2026, 8, 1); // Sat of Week 1
      final habit = HabitModel(
        id: 'h2',
        title: 'Workout',
        days: List<bool>.filled(7, true), // All 7 days completed
        streak: 7,
        baseStreak: 0,
        lastResetDate: baseDate,
        createdAt: baseDate,
      );

      final nextWeekDate = DateTime(2026, 8, 8); // Sat of Week 2
      final rolled = StreakLogic.evaluateWeeklyReset(
        habit,
        nextWeekDate,
        weekStartDay: DateTime.saturday,
      );

      // Perfect week rolled over
      expect(rolled.baseStreak, 7);
      expect(rolled.streak, 7);
      expect(rolled.days.every((d) => !d), isTrue); // Reset to 7 false
    });

    test('evaluateWeeklyReset breaks streak to 0 if a single day was missed', () {
      final baseDate = DateTime(2026, 8, 1); // Sat of Week 1
      final habit = HabitModel(
        id: 'h3',
        title: 'Read Book',
        days: [true, true, true, false, true, true, true], // Missed day 3
        streak: 6,
        baseStreak: 0,
        lastResetDate: baseDate,
        createdAt: baseDate,
      );

      final nextWeekDate = DateTime(2026, 8, 8); // Sat of Week 2
      final rolled = StreakLogic.evaluateWeeklyReset(
        habit,
        nextWeekDate,
        weekStartDay: DateTime.saturday,
      );

      // Broken streak reset
      expect(rolled.baseStreak, 0);
      expect(rolled.streak, 0);
      expect(rolled.days.every((d) => !d), isTrue);
    });

    test('toggleHabitDay triggers early-completion week reset when 7th day is checked', () {
      final baseDate = DateTime(2026, 8, 2); // Sunday
      var habit = HabitModel(
        id: 'h_early',
        title: 'Daily Coding',
        days: [true, true, true, true, true, true, false], // 6 days checked
        streak: 6,
        baseStreak: 0,
        autoReset: true,
        lastResetDate: baseDate,
        createdAt: baseDate,
      );

      // User checks off the 7th day (index 6)
      final result = StreakLogic.toggleHabitDayWithResult(
        habit,
        6,
        now: DateTime(2026, 8, 4), // Tuesday
      );

      // Verify early-completion week reset
      expect(result.wasEarlyWeekReset, isTrue);
      expect(result.habit.baseStreak, 7);
      expect(result.habit.streak, 7);
      expect(result.habit.days, equals(List<bool>.filled(7, false))); // Fresh empty row
      expect(result.habit.lastResetDate, equals(DateTime(2026, 8, 4)));

      // User continues in the fresh week by checking day index 0
      final nextDayResult = StreakLogic.toggleHabitDayWithResult(
        result.habit,
        0,
        now: DateTime(2026, 8, 5),
      );

      expect(nextDayResult.wasEarlyWeekReset, isFalse);
      expect(nextDayResult.habit.baseStreak, 7);
      expect(nextDayResult.habit.streak, 8); // 7 base + 1 completed in current row
      expect(nextDayResult.habit.days[0], isTrue);
      expect(nextDayResult.habit.days[1], isFalse);
    });

    test('toggleHabitDay does NOT reset days array when autoReset is disabled', () {
      final baseDate = DateTime(2026, 8, 2);
      final habit = HabitModel(
        id: 'h_manual',
        title: 'Meditation',
        days: [true, true, true, true, true, true, false], // 6 days checked
        streak: 6,
        baseStreak: 0,
        autoReset: false, // Auto-reset turned OFF
        lastResetDate: baseDate,
        createdAt: baseDate,
      );

      // User checks 7th day
      final result = StreakLogic.toggleHabitDayWithResult(
        habit,
        6,
        now: DateTime(2026, 8, 4),
      );

      // Auto-reset disabled: streak updates but days array remains untouched
      expect(result.wasEarlyWeekReset, isFalse);
      expect(result.habit.streak, 7);
      expect(result.habit.baseStreak, 0);
      expect(result.habit.days.every((d) => d), isTrue); // All 7 true
    });

    test('natural weekly reset does not double-reset a week that already reset early', () {
      final weekStart = DateTime(2026, 8, 1); // Sat (start of Week 1)
      final earlyResetDate = DateTime(2026, 8, 4); // Tuesday of Week 1

      // Habit that was already reset early on Tuesday
      final habit = HabitModel(
        id: 'h_no_double_reset',
        title: 'Drink Water',
        days: [true, true, false, false, false, false, false], // 2 days checked in fresh row
        streak: 9, // 7 base + 2
        baseStreak: 7,
        autoReset: true,
        lastResetDate: earlyResetDate,
        createdAt: weekStart,
        resetDay: DateTime.saturday,
      );

      // Check on Thursday of the same week (Aug 6)
      final sameWeekCheck = StreakLogic.evaluateWeeklyReset(
        habit,
        DateTime(2026, 8, 6),
        weekStartDay: DateTime.saturday,
      );

      // Same week -> no reset
      expect(sameWeekCheck.baseStreak, 7);
      expect(sameWeekCheck.streak, 9);
      expect(sameWeekCheck.days[0], isTrue);
      expect(sameWeekCheck.days[1], isTrue);
    });

    test('checkMilestoneCelebration detects milestone thresholds', () {
      expect(StreakLogic.checkMilestoneCelebration(2, 3), 3);
      expect(StreakLogic.checkMilestoneCelebration(6, 7), 7);
      expect(StreakLogic.checkMilestoneCelebration(13, 14), 14);
      expect(StreakLogic.checkMilestoneCelebration(29, 30), 30);
      expect(StreakLogic.checkMilestoneCelebration(1, 2), isNull);
      expect(StreakLogic.checkMilestoneCelebration(7, 7), isNull);
      expect(StreakLogic.checkMilestoneCelebration(8, 7), isNull);
    });
  });
}
