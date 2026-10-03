import 'package:flutter_test/flutter_test.dart';
import 'package:focusly/features/habits/models/habit_model.dart';
import 'package:focusly/features/pomodoro/models/pomodoro_log_model.dart';
import 'package:focusly/features/progress/constants/xp_constants.dart';
import 'package:focusly/features/progress/models/achievement_model.dart';
import 'package:focusly/features/progress/models/achievements_data.dart';
import 'package:focusly/features/progress/models/level_logic.dart';
import 'package:focusly/features/progress/models/xp_log_model.dart';
import 'package:focusly/features/tasks/models/task_model.dart';

void main() {
  group('Progress Level Logic & XP Curve Tests', () {
    test('Level 1 calculation at 0 XP', () {
      final info = LevelLogic.calculate(0);
      expect(info.level, 1);
      expect(info.titleKey, 'level_1_title');
      expect(info.emoji, '🌱');
      expect(info.currentLevelMinXp, 0);
      expect(info.nextLevelXp, 100);
      expect(info.currentLevelXp, 0);
      expect(info.xpToNextLevel, 100);
      expect(info.percentToNextLevel, 0.0);
    });

    test('Level 1 halfway calculation at 50 XP', () {
      final info = LevelLogic.calculate(50);
      expect(info.level, 1);
      expect(info.currentLevelXp, 50);
      expect(info.xpToNextLevel, 50);
      expect(info.percentToNextLevel, 0.5);
    });

    test('Level 2 at exact 100 XP threshold', () {
      final info = LevelLogic.calculate(100);
      expect(info.level, 2);
      expect(info.titleKey, 'level_2_title');
      expect(info.emoji, '📚');
      expect(info.currentLevelMinXp, 100);
      expect(info.nextLevelXp, 250);
      expect(info.currentLevelXp, 0);
      expect(info.xpToNextLevel, 150);
      expect(info.percentToNextLevel, 0.0);
    });

    test('Level 5 at 700 XP threshold', () {
      final info = LevelLogic.calculate(700);
      expect(info.level, 5);
      expect(info.titleKey, 'level_5_title');
      expect(info.emoji, '🌟');
    });

    test('Level 20 Max Level at 13,200 XP threshold', () {
      final info = LevelLogic.calculate(15000);
      expect(info.level, 20);
      expect(info.titleKey, 'level_20_title');
      expect(info.emoji, '🔱');
      expect(info.percentToNextLevel, 1.0);
      expect(info.xpToNextLevel, 0);
    });
  });

  group('Achievements Evaluation Engine Tests', () {
    test('task_first and task_5 unlocked based on task completion status', () {
      final taskFirst = AchievementsData.allAchievements
          .firstWhere((a) => a.id == 'task_first');
      final task5 =
          AchievementsData.allAchievements.firstWhere((a) => a.id == 'task_5');

      final emptyCtx = const AchievementContext();
      expect(taskFirst.isUnlocked(emptyCtx), isFalse);
      expect(task5.isUnlocked(emptyCtx), isFalse);

      // Context with 1 completed task
      final doneTask = TaskModel(
        id: 't1',
        title: 'Study math',
        categoryId: 'study',
        date: DateTime.now(),
        done: true,
        createdAt: DateTime.now(),
      );

      final oneDoneCtx = AchievementContext(tasks: [doneTask]);
      expect(taskFirst.isUnlocked(oneDoneCtx), isTrue);
      expect(task5.isUnlocked(oneDoneCtx), isFalse);

      // Context with 5 completed tasks
      final fiveDoneTasks = List.generate(
        5,
        (i) => TaskModel(
          id: 't_$i',
          title: 'Task $i',
          categoryId: 'study',
          date: DateTime.now(),
          done: true,
          createdAt: DateTime.now(),
        ),
      );
      final fiveDoneCtx = AchievementContext(tasks: fiveDoneTasks);
      expect(task5.isUnlocked(fiveDoneCtx), isTrue);
    });

    test('habit_streak_3 unlocked when habit streak reaches 3', () {
      final habitStreak3 = AchievementsData.allAchievements
          .firstWhere((a) => a.id == 'habit_streak_3');

      final habit = HabitModel(
        id: 'h1',
        title: 'Drink Water',
        days: [true, true, true, false, false, false, false],
        streak: 3,
        baseStreak: 0,
        createdAt: DateTime.now(),
      );

      final ctx = AchievementContext(habits: [habit]);
      expect(habitStreak3.isUnlocked(ctx), isTrue);
    });

    test('pomodoro_first unlocked on non-partial session log', () {
      final pomodoroFirst = AchievementsData.allAchievements
          .firstWhere((a) => a.id == 'pomodoro_first');

      final log = PomodoroLogModel(
        id: 'l1',
        date: DateTime.now(),
        taskTitle: 'Deep Work',
        durationMinutes: 25,
        durationSeconds: 1500,
        partial: false,
        createdAt: DateTime.now(),
      );

      final ctx = AchievementContext(pomodoroLogs: [log]);
      expect(pomodoroFirst.isUnlocked(ctx), isTrue);
    });

    test('special_night_owl and special_early_bird detect task creation hours', () {
      final nightOwl = AchievementsData.allAchievements
          .firstWhere((a) => a.id == 'special_night_owl');
      final earlyBird = AchievementsData.allAchievements
          .firstWhere((a) => a.id == 'special_early_bird');

      final midnightTask = TaskModel(
        id: 't_night',
        title: 'Late Night Coding',
        categoryId: 'work',
        date: DateTime(2026, 8, 23),
        createdAt: DateTime(2026, 8, 23, 2, 30), // 2:30 AM
      );

      final earlyTask = TaskModel(
        id: 't_early',
        title: 'Morning Yoga',
        categoryId: 'health',
        date: DateTime(2026, 8, 23),
        createdAt: DateTime(2026, 8, 23, 6, 15), // 6:15 AM
      );

      final nightCtx = AchievementContext(tasks: [midnightTask]);
      expect(nightOwl.isUnlocked(nightCtx), isTrue);
      expect(earlyBird.isUnlocked(nightCtx), isFalse);

      final earlyCtx = AchievementContext(tasks: [earlyTask]);
      expect(earlyBird.isUnlocked(earlyCtx), isTrue);
      expect(nightOwl.isUnlocked(earlyCtx), isFalse);
    });

    test('event_first and event_5 unlock correctly', () {
      final eventFirst = AchievementsData.allAchievements
          .firstWhere((a) => a.id == 'event_first');
      final event5 =
          AchievementsData.allAchievements.firstWhere((a) => a.id == 'event_5');

      expect(eventFirst.isUnlocked(const AchievementContext()), isFalse);
      expect(event5.isUnlocked(const AchievementContext()), isFalse);
    });

    test('xp_100 and level_5 unlock correctly', () {
      final xp100 =
          AchievementsData.allAchievements.firstWhere((a) => a.id == 'xp_100');
      final level5 =
          AchievementsData.allAchievements.firstWhere((a) => a.id == 'level_5');

      final ctx1 = const AchievementContext(totalXp: 120, level: 2);
      expect(xp100.isUnlocked(ctx1), isTrue);
      expect(level5.isUnlocked(ctx1), isFalse);

      final ctx2 = const AchievementContext(totalXp: 800, level: 5);
      expect(level5.isUnlocked(ctx2), isTrue);
    });

    test('All Task Category achievements evaluate without error', () {
      final taskAchievements = AchievementsData.allAchievements
          .where((a) => a.category == AchievementCategory.tasks)
          .toList();
      expect(taskAchievements.length, 8);

      final testTask = TaskModel(
        id: 't_test',
        title: 'Complete task',
        categoryId: 'work',
        date: DateTime.now(),
        done: true,
        subtasks: [
          const SubtaskModel(id: 's1', title: 'sub 1', done: true),
        ],
        createdAt: DateTime.now(),
      );

      final ctx = AchievementContext(tasks: [testTask]);
      for (final a in taskAchievements) {
        expect(() => a.isUnlocked(ctx), returnsNormally);
      }
    });
  });

  group('XpConstants & Accurate Reward Rates Tests', () {
    test('All XP constants match documented reward values exactly', () {
      expect(XpConstants.taskCompletion, 10);
      expect(XpConstants.habitDayCompletion, 5);
      expect(XpConstants.pomodoroFullSession, 30);
      expect(XpConstants.pomodoroPartialRatePerMin, 1.2);
      expect(XpConstants.readingProgress, 15);
      expect(XpConstants.readingBookFinished, 50);
      expect(XpConstants.dailyCheckin, 15);
      expect(XpConstants.waterPerGlass, 5);
      expect(XpConstants.sleepLogged, 15);
      expect(XpConstants.learningPathDay, 10);
      expect(XpConstants.flashcardReviewPerCard, 2);
      expect(XpConstants.eveningShutdown, 30);
      expect(XpConstants.weeklyReview, 40);

      // Skill XP Tiers
      expect(XpConstants.taskSkillHigh, 25);
      expect(XpConstants.taskSkillMedium, 15);
      expect(XpConstants.taskSkillLow, 10);
    });

    test('XpLogModel serializes and deserializes accurately', () {
      final now = DateTime(2026, 8, 27, 10, 0);
      final log = XpLogModel(
        id: 'log_123',
        amount: 15,
        source: 'Daily check-in completed',
        sourceType: 'checkin',
        createdAt: now,
      );

      final map = log.toMap();
      expect(map['amount'], 15);
      expect(map['source'], 'Daily check-in completed');
      expect(map['sourceType'], 'checkin');
      expect(log.sourceEmoji, '⚡');

      final taskLog = XpLogModel(
        id: 'log_task',
        amount: 10,
        source: 'Completed task: "Read chapter"',
        sourceType: 'task',
        createdAt: now,
      );
      expect(taskLog.sourceEmoji, '🎯');

      final habitLog = XpLogModel(
        id: 'log_habit',
        amount: 5,
        source: 'Completed habit: "Workout"',
        sourceType: 'habit',
        createdAt: now,
      );
      expect(habitLog.sourceEmoji, '🔥');
    });

    test('Level calculation exact progress breakdown format', () {
      final info = LevelLogic.calculate(180);
      // Level 2 (100 - 250 XP): currentLevelXp = 80, xpToNextLevel = 70
      expect(info.level, 2);
      expect(info.currentLevelXp, 80);
      expect(info.xpToNextLevel, 70);
      expect(info.totalXp, 180);
    });
  });
}
