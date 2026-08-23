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
