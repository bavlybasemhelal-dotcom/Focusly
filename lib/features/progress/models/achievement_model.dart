import '../../habits/models/habit_model.dart';
import '../../pomodoro/models/pomodoro_log_model.dart';
import '../../schedule/models/event_model.dart';
import '../../tasks/models/category_model.dart';
import '../../tasks/models/task_model.dart';

/// Categories of achievements in Focusly
enum AchievementCategory {
  tasks(titleKey: 'achieve_cat_tasks', emoji: '🎯'),
  habits(titleKey: 'achieve_cat_habits', emoji: '🔥'),
  pomodoro(titleKey: 'achieve_cat_pomodoro', emoji: '🍅'),
  events(titleKey: 'achieve_cat_events', emoji: '📅'),
  levels(titleKey: 'achieve_cat_levels', emoji: '🌟'),
  organization(titleKey: 'achieve_cat_organization', emoji: '📂'),
  special(titleKey: 'achieve_cat_special', emoji: '✨');

  final String titleKey;
  final String emoji;

  const AchievementCategory({
    required this.titleKey,
    required this.emoji,
  });
}

/// Context snapshot passed to pure achievement evaluation functions
class AchievementContext {
  final List<TaskModel> tasks;
  final List<HabitModel> habits;
  final List<PomodoroLogModel> pomodoroLogs;
  final List<EventModel> events;
  final List<TaskCategory> categories;
  final int totalXp;
  final int level;

  const AchievementContext({
    this.tasks = const [],
    this.habits = const [],
    this.pomodoroLogs = const [],
    this.events = const [],
    this.categories = const [],
    this.totalXp = 0,
    this.level = 1,
  });
}

/// Represents an unlockable Achievement badge in Focusly.
class AchievementModel {
  final String id;
  final AchievementCategory category;
  final String titleKey;
  final String descKey;
  final String emoji;
  final bool Function(AchievementContext ctx) checkCondition;

  const AchievementModel({
    required this.id,
    required this.category,
    required this.titleKey,
    required this.descKey,
    required this.emoji,
    required this.checkCondition,
  });

  /// Evaluates whether this achievement is earned based on user context
  bool isUnlocked(AchievementContext ctx) => checkCondition(ctx);
}
