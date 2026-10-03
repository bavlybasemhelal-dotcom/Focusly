import 'achievement_model.dart';

/// Master catalog of all Achievements in Focusly.
///
/// Each achievement is evaluated purely against user metrics.
/// TODO: "changed theme" and "exported data" achievements can be re-added once those features support event hooks.
class AchievementsData {
  static final List<AchievementModel> allAchievements = [
    // -------------------------------------------------------------------------
    // TASKS ACHIEVEMENTS
    // -------------------------------------------------------------------------
    AchievementModel(
      id: 'task_first',
      category: AchievementCategory.tasks,
      titleKey: 'achieve_task_first_title',
      descKey: 'achieve_task_first_desc',
      emoji: '✅',
      checkCondition: (ctx) => ctx.tasks.any((t) => t.done),
    ),
    AchievementModel(
      id: 'task_5',
      category: AchievementCategory.tasks,
      titleKey: 'achieve_task_5_title',
      descKey: 'achieve_task_5_desc',
      emoji: '🎯',
      checkCondition: (ctx) => ctx.tasks.where((t) => t.done).length >= 5,
    ),
    AchievementModel(
      id: 'task_10',
      category: AchievementCategory.tasks,
      titleKey: 'achieve_task_10_title',
      descKey: 'achieve_task_10_desc',
      emoji: '🔟',
      checkCondition: (ctx) => ctx.tasks.where((t) => t.done).length >= 10,
    ),
    AchievementModel(
      id: 'task_25',
      category: AchievementCategory.tasks,
      titleKey: 'achieve_task_25_title',
      descKey: 'achieve_task_25_desc',
      emoji: '🏅',
      checkCondition: (ctx) => ctx.tasks.where((t) => t.done).length >= 25,
    ),
    AchievementModel(
      id: 'task_50',
      category: AchievementCategory.tasks,
      titleKey: 'achieve_task_50_title',
      descKey: 'achieve_task_50_desc',
      emoji: '🏆',
      checkCondition: (ctx) => ctx.tasks.where((t) => t.done).length >= 50,
    ),
    AchievementModel(
      id: 'task_100',
      category: AchievementCategory.tasks,
      titleKey: 'achieve_task_100_title',
      descKey: 'achieve_task_100_desc',
      emoji: '👑',
      checkCondition: (ctx) => ctx.tasks.where((t) => t.done).length >= 100,
    ),
    AchievementModel(
      id: 'task_create_20',
      category: AchievementCategory.tasks,
      titleKey: 'achieve_task_create_20_title',
      descKey: 'achieve_task_create_20_desc',
      emoji: '📝',
      checkCondition: (ctx) => ctx.tasks.length >= 20,
    ),
    AchievementModel(
      id: 'task_subtask_add',
      category: AchievementCategory.tasks,
      titleKey: 'achieve_task_subtask_title',
      descKey: 'achieve_task_subtask_desc',
      emoji: '🧩',
      checkCondition: (ctx) => ctx.tasks.any((t) => t.subtasks.isNotEmpty),
    ),

    // -------------------------------------------------------------------------
    // HABITS ACHIEVEMENTS
    // -------------------------------------------------------------------------
    AchievementModel(
      id: 'habit_create_first',
      category: AchievementCategory.habits,
      titleKey: 'achieve_habit_first_title',
      descKey: 'achieve_habit_first_desc',
      emoji: '🌱',
      checkCondition: (ctx) => ctx.habits.isNotEmpty,
    ),
    AchievementModel(
      id: 'habit_day_1',
      category: AchievementCategory.habits,
      titleKey: 'achieve_habit_day_1_title',
      descKey: 'achieve_habit_day_1_desc',
      emoji: '⭐',
      checkCondition: (ctx) =>
          ctx.habits.any((h) => h.days.any((d) => d) || h.streak > 0),
    ),
    AchievementModel(
      id: 'habit_streak_3',
      category: AchievementCategory.habits,
      titleKey: 'achieve_habit_streak_3_title',
      descKey: 'achieve_habit_streak_3_desc',
      emoji: '🔥',
      checkCondition: (ctx) => ctx.habits.any((h) => h.streak >= 3),
    ),
    AchievementModel(
      id: 'habit_streak_7',
      category: AchievementCategory.habits,
      titleKey: 'achieve_habit_streak_7_title',
      descKey: 'achieve_habit_streak_7_desc',
      emoji: '⚡',
      checkCondition: (ctx) => ctx.habits.any((h) => h.streak >= 7),
    ),
    AchievementModel(
      id: 'habit_streak_14',
      category: AchievementCategory.habits,
      titleKey: 'achieve_habit_streak_14_title',
      descKey: 'achieve_habit_streak_14_desc',
      emoji: '💎',
      checkCondition: (ctx) => ctx.habits.any((h) => h.streak >= 14),
    ),
    AchievementModel(
      id: 'habit_streak_30',
      category: AchievementCategory.habits,
      titleKey: 'achieve_habit_streak_30_title',
      descKey: 'achieve_habit_streak_30_desc',
      emoji: '🪐',
      checkCondition: (ctx) => ctx.habits.any((h) => h.streak >= 30),
    ),
    AchievementModel(
      id: 'habit_create_5',
      category: AchievementCategory.habits,
      titleKey: 'achieve_habit_create_5_title',
      descKey: 'achieve_habit_create_5_desc',
      emoji: '🌳',
      checkCondition: (ctx) => ctx.habits.length >= 5,
    ),

    // -------------------------------------------------------------------------
    // POMODORO ACHIEVEMENTS
    // -------------------------------------------------------------------------
    AchievementModel(
      id: 'pomodoro_first',
      category: AchievementCategory.pomodoro,
      titleKey: 'achieve_pomodoro_first_title',
      descKey: 'achieve_pomodoro_first_desc',
      emoji: '🍅',
      checkCondition: (ctx) => ctx.pomodoroLogs.any((l) => !l.partial),
    ),
    AchievementModel(
      id: 'pomodoro_5',
      category: AchievementCategory.pomodoro,
      titleKey: 'achieve_pomodoro_5_title',
      descKey: 'achieve_pomodoro_5_desc',
      emoji: '⏱️',
      checkCondition: (ctx) =>
          ctx.pomodoroLogs.where((l) => !l.partial).length >= 5,
    ),
    AchievementModel(
      id: 'pomodoro_10',
      category: AchievementCategory.pomodoro,
      titleKey: 'achieve_pomodoro_10_title',
      descKey: 'achieve_pomodoro_10_desc',
      emoji: '🚀',
      checkCondition: (ctx) =>
          ctx.pomodoroLogs.where((l) => !l.partial).length >= 10,
    ),
    AchievementModel(
      id: 'pomodoro_25',
      category: AchievementCategory.pomodoro,
      titleKey: 'achieve_pomodoro_25_title',
      descKey: 'achieve_pomodoro_25_desc',
      emoji: '🛡️',
      checkCondition: (ctx) =>
          ctx.pomodoroLogs.where((l) => !l.partial).length >= 25,
    ),
    AchievementModel(
      id: 'pomodoro_50',
      category: AchievementCategory.pomodoro,
      titleKey: 'achieve_pomodoro_50_title',
      descKey: 'achieve_pomodoro_50_desc',
      emoji: '🌋',
      checkCondition: (ctx) =>
          ctx.pomodoroLogs.where((l) => !l.partial).length >= 50,
    ),
    AchievementModel(
      id: 'pomodoro_60m',
      category: AchievementCategory.pomodoro,
      titleKey: 'achieve_pomodoro_60m_title',
      descKey: 'achieve_pomodoro_60m_desc',
      emoji: '⏳',
      checkCondition: (ctx) {
        final totalMins = ctx.pomodoroLogs.fold<int>(
          0,
          (sum, item) => sum + item.durationMinutes,
        );
        return totalMins >= 60;
      },
    ),
    AchievementModel(
      id: 'pomodoro_300m',
      category: AchievementCategory.pomodoro,
      titleKey: 'achieve_pomodoro_300m_title',
      descKey: 'achieve_pomodoro_300m_desc',
      emoji: '🧘',
      checkCondition: (ctx) {
        final totalMins = ctx.pomodoroLogs.fold<int>(
          0,
          (sum, item) => sum + item.durationMinutes,
        );
        return totalMins >= 300;
      },
    ),

    // -------------------------------------------------------------------------
    // EVENTS ACHIEVEMENTS
    // -------------------------------------------------------------------------
    AchievementModel(
      id: 'event_first',
      category: AchievementCategory.events,
      titleKey: 'achieve_event_first_title',
      descKey: 'achieve_event_first_desc',
      emoji: '📅',
      checkCondition: (ctx) => ctx.events.isNotEmpty,
    ),
    AchievementModel(
      id: 'event_5',
      category: AchievementCategory.events,
      titleKey: 'achieve_event_5_title',
      descKey: 'achieve_event_5_desc',
      emoji: '🗓️',
      checkCondition: (ctx) => ctx.events.length >= 5,
    ),
    AchievementModel(
      id: 'event_20',
      category: AchievementCategory.events,
      titleKey: 'achieve_event_20_title',
      descKey: 'achieve_event_20_desc',
      emoji: '🗺️',
      checkCondition: (ctx) => ctx.events.length >= 20,
    ),

    // -------------------------------------------------------------------------
    // XP & LEVELS ACHIEVEMENTS
    // -------------------------------------------------------------------------
    AchievementModel(
      id: 'xp_100',
      category: AchievementCategory.levels,
      titleKey: 'achieve_xp_100_title',
      descKey: 'achieve_xp_100_desc',
      emoji: '🥉',
      checkCondition: (ctx) => ctx.totalXp >= 100,
    ),
    AchievementModel(
      id: 'xp_500',
      category: AchievementCategory.levels,
      titleKey: 'achieve_xp_500_title',
      descKey: 'achieve_xp_500_desc',
      emoji: '🥈',
      checkCondition: (ctx) => ctx.totalXp >= 500,
    ),
    AchievementModel(
      id: 'xp_1000',
      category: AchievementCategory.levels,
      titleKey: 'achieve_xp_1000_title',
      descKey: 'achieve_xp_1000_desc',
      emoji: '🥇',
      checkCondition: (ctx) => ctx.totalXp >= 1000,
    ),
    AchievementModel(
      id: 'level_5',
      category: AchievementCategory.levels,
      titleKey: 'achieve_level_5_title',
      descKey: 'achieve_level_5_desc',
      emoji: '🌟',
      checkCondition: (ctx) => ctx.level >= 5,
    ),
    AchievementModel(
      id: 'level_10',
      category: AchievementCategory.levels,
      titleKey: 'achieve_level_10_title',
      descKey: 'achieve_level_10_desc',
      emoji: '🎓',
      checkCondition: (ctx) => ctx.level >= 10,
    ),
    AchievementModel(
      id: 'level_20',
      category: AchievementCategory.levels,
      titleKey: 'achieve_level_20_title',
      descKey: 'achieve_level_20_desc',
      emoji: '🔱',
      checkCondition: (ctx) => ctx.level >= 20,
    ),

    // -------------------------------------------------------------------------
    // ORGANIZATION ACHIEVEMENTS
    // -------------------------------------------------------------------------
    AchievementModel(
      id: 'org_3_categories',
      category: AchievementCategory.organization,
      titleKey: 'achieve_org_3_cat_title',
      descKey: 'achieve_org_3_cat_desc',
      emoji: '📂',
      checkCondition: (ctx) {
        final uniqueCats = ctx.tasks.map((t) => t.categoryId).toSet();
        return uniqueCats.length >= 3;
      },
    ),
    AchievementModel(
      id: 'org_5_categories',
      category: AchievementCategory.organization,
      titleKey: 'achieve_org_5_cat_title',
      descKey: 'achieve_org_5_cat_desc',
      emoji: '🗂️',
      checkCondition: (ctx) {
        final uniqueCats = ctx.tasks.map((t) => t.categoryId).toSet();
        return uniqueCats.length >= 5;
      },
    ),
    AchievementModel(
      id: 'org_custom_cat',
      category: AchievementCategory.organization,
      titleKey: 'achieve_org_custom_cat_title',
      descKey: 'achieve_org_custom_cat_desc',
      emoji: '🎨',
      checkCondition: (ctx) => ctx.categories.any((c) => !c.isDefault),
    ),

    // -------------------------------------------------------------------------
    // SPECIAL ACHIEVEMENTS
    // -------------------------------------------------------------------------
    AchievementModel(
      id: 'special_night_owl',
      category: AchievementCategory.special,
      titleKey: 'achieve_night_owl_title',
      descKey: 'achieve_night_owl_desc',
      emoji: '🦉',
      checkCondition: (ctx) =>
          ctx.tasks.any((t) => t.createdAt.hour >= 0 && t.createdAt.hour < 5),
    ),
    AchievementModel(
      id: 'special_early_bird',
      category: AchievementCategory.special,
      titleKey: 'achieve_early_bird_title',
      descKey: 'achieve_early_bird_desc',
      emoji: '🌅',
      checkCondition: (ctx) =>
          ctx.tasks.any((t) => t.createdAt.hour >= 5 && t.createdAt.hour < 7),
    ),
    AchievementModel(
      id: 'special_perfect_week',
      category: AchievementCategory.special,
      titleKey: 'achieve_perfect_week_title',
      descKey: 'achieve_perfect_week_desc',
      emoji: '🌈',
      checkCondition: (ctx) {
        if (ctx.tasks.length < 7) return false;
        final completedDates = ctx.tasks
            .where((t) => t.done)
            .map((t) => DateTime(t.date.year, t.date.month, t.date.day))
            .toSet();
        return completedDates.length >= 7;
      },
    ),
  ];
}
