/// Information container representing the user's computed Level and XP progress.
class UserLevelInfo {
  final int level; // 1 to 20
  final String titleKey; // Translation key for the level title
  final String emoji;
  final int totalXp;
  final int currentLevelMinXp;
  final int nextLevelXp;
  final int currentLevelXp; // XP accumulated in current level
  final int xpToNextLevel; // XP needed to advance to next level
  final double percentToNextLevel; // 0.0 to 1.0

  const UserLevelInfo({
    required this.level,
    required this.titleKey,
    required this.emoji,
    required this.totalXp,
    required this.currentLevelMinXp,
    required this.nextLevelXp,
    required this.currentLevelXp,
    required this.xpToNextLevel,
    required this.percentToNextLevel,
  });
}

/// Pure calculations for the 20-level XP progression curve in Focusly.
///
/// Features escalating thresholds and titles:
/// Level 1 (0 XP) "Beginner" 🌱 up to Level 20 (13,200 XP) "Beyond the Cosmos" 🔱.
class LevelLogic {
  // Threshold table: (level, minXp, titleKey, emoji)
  // TODO: Level-up rewards (themes, badges) can be reintroduced later once more content exists to unlock.
  static const List<({int level, int minXp, String titleKey, String emoji})>
      levels = [
    (level: 1, minXp: 0, titleKey: 'level_1_title', emoji: '🌱'),
    (level: 2, minXp: 100, titleKey: 'level_2_title', emoji: '📚'),
    (level: 3, minXp: 250, titleKey: 'level_3_title', emoji: '💪'),
    (level: 4, minXp: 450, titleKey: 'level_4_title', emoji: '⚡'),
    (level: 5, minXp: 700, titleKey: 'level_5_title', emoji: '🌟'),
    (level: 6, minXp: 1000, titleKey: 'level_6_title', emoji: '🎯'),
    (level: 7, minXp: 1350, titleKey: 'level_7_title', emoji: '🏅'),
    (level: 8, minXp: 1750, titleKey: 'level_8_title', emoji: '🔥'),
    (level: 9, minXp: 2200, titleKey: 'level_9_title', emoji: '🦅'),
    (level: 10, minXp: 2700, titleKey: 'level_10_title', emoji: '🎓'),
    (level: 11, minXp: 3300, titleKey: 'level_11_title', emoji: '👨‍💻'),
    (level: 12, minXp: 4000, titleKey: 'level_12_title', emoji: '🦉'),
    (level: 13, minXp: 4800, titleKey: 'level_13_title', emoji: '💡'),
    (level: 14, minXp: 5700, titleKey: 'level_14_title', emoji: '🗡️'),
    (level: 15, minXp: 6700, titleKey: 'level_15_title', emoji: '🤴'),
    (level: 16, minXp: 7800, titleKey: 'level_16_title', emoji: '👑'),
    (level: 17, minXp: 9000, titleKey: 'level_17_title', emoji: '🏰'),
    (level: 18, minXp: 10300, titleKey: 'level_18_title', emoji: '♾️'),
    (level: 19, minXp: 11700, titleKey: 'level_19_title', emoji: '🌌'),
    (level: 20, minXp: 13200, titleKey: 'level_20_title', emoji: '🔱'),
  ];

  /// Pure function that computes the user's level and progression metrics from total XP.
  static UserLevelInfo calculate(int totalXp) {
    final clampedXp = totalXp < 0 ? 0 : totalXp;

    int activeLevelIndex = 0;
    for (int i = 0; i < levels.length; i++) {
      if (clampedXp >= levels[i].minXp) {
        activeLevelIndex = i;
      } else {
        break;
      }
    }

    final currentLevelDef = levels[activeLevelIndex];
    final isMaxLevel = activeLevelIndex == levels.length - 1;

    final minXp = currentLevelDef.minXp;
    final nextXp = isMaxLevel
        ? currentLevelDef.minXp
        : levels[activeLevelIndex + 1].minXp;

    final currentLevelXp = clampedXp - minXp;
    final span = isMaxLevel ? 1 : (nextXp - minXp);
    final xpToNextLevel = isMaxLevel ? 0 : (nextXp - clampedXp);
    final percent = isMaxLevel ? 1.0 : (currentLevelXp / span).clamp(0.0, 1.0);

    return UserLevelInfo(
      level: currentLevelDef.level,
      titleKey: currentLevelDef.titleKey,
      emoji: currentLevelDef.emoji,
      totalXp: clampedXp,
      currentLevelMinXp: minXp,
      nextLevelXp: nextXp,
      currentLevelXp: currentLevelXp,
      xpToNextLevel: xpToNextLevel,
      percentToNextLevel: percent,
    );
  }
}
