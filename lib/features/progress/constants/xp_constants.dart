/// Centralized single source of truth for all XP values awarded across Focusly.
///
/// NOTE FOR DEVELOPERS:
/// Every XP award call site AND every explanatory UI breakdown references these constants.
/// Modifying a value here updates both the actual award logic and the displayed guide text
/// automatically, preventing documentation and logic drift.
class XpConstants {
  const XpConstants._();

  /// +10 XP for completing a standard task
  static const int taskCompletion = 10;

  /// +5 XP for checking off a daily habit
  static const int habitDayCompletion = 5;

  /// +30 XP for a full 25-minute Pomodoro focus session
  static const int pomodoroFullSession = 30;

  /// ~1.2 XP per minute for partial Pomodoro sessions
  static const double pomodoroPartialRatePerMin = 1.2;

  /// +15 XP for logging reading page progress on a book
  static const int readingProgress = 15;

  /// +50 XP for finishing a book
  static const int readingBookFinished = 50;

  /// +15 XP for completing a daily energy & mood check-in
  static const int dailyCheckin = 15;

  /// +5 XP per glass of water logged (up to 2x daily target)
  static const int waterPerGlass = 5;

  /// +15 XP once per day for recording sleep & wake times
  static const int sleepLogged = 15;

  /// +10 XP for completing a Learning Path curriculum day
  static const int learningPathDay = 10;

  /// +2 XP per card reviewed in a Spaced Repetition flashcard session
  static const int flashcardReviewPerCard = 2;

  /// +30 XP for completing the Evening Shutdown ritual
  static const int eveningShutdown = 30;

  /// +40 XP for completing the Weekly Review wizard
  static const int weeklyReview = 40;

  // ---------------------------------------------------------------------------
  // Skill XP Tiers (awarded directly to individual skills via SkillsService)
  // ---------------------------------------------------------------------------
  /// +25 Skill XP for completing a High priority task
  static const int taskSkillHigh = 25;

  /// +15 Skill XP for completing a Medium priority task
  static const int taskSkillMedium = 15;

  /// +10 Skill XP for completing a Low priority task
  static const int taskSkillLow = 10;
}
