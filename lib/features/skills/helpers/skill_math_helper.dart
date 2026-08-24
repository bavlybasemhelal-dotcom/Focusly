/// Result of an XP calculation including level gains and new XP.
class SkillXpResult {
  final int newLevel;
  final int newXp;
  final int levelGain;
  final bool didLevelUp;

  const SkillXpResult({
    required this.newLevel,
    required this.newXp,
    required this.levelGain,
    required this.didLevelUp,
  });
}

/// Pure helper for skill progression calculations, level-ups, and 7-day sparkline snapshots.
///
/// Contains NO side effects or external dependencies for 100% deterministic unit testability.
class SkillMathHelper {
  /// Computes skill level progression and rollover from adding XP.
  ///
  /// Every 100 XP triggers a Level Up.
  /// Example:
  /// - Current: Level 1, 80 XP. Added: 35 XP.
  /// - Total XP = 115 -> Level Gain = 1, New Level = 2, Remaining XP = 15.
  static SkillXpResult computeXpProgress({
    required int currentLevel,
    required int currentXp,
    required int addedXp,
  }) {
    final validCurrentLevel = currentLevel >= 1 ? currentLevel : 1;
    final validCurrentXp = currentXp >= 0 ? currentXp : 0;
    final validAddedXp = addedXp >= 0 ? addedXp : 0;

    final totalXp = validCurrentXp + validAddedXp;
    final levelGain = totalXp ~/ 100;
    final newLevel = validCurrentLevel + levelGain;
    final newXp = totalXp % 100;

    return SkillXpResult(
      newLevel: newLevel,
      newXp: newXp,
      levelGain: levelGain,
      didLevelUp: levelGain > 0,
    );
  }

  /// Normalizes and rolls over direct user inputs (e.g. from Add/Edit Modal or Quick Update).
  ///
  /// Example:
  /// - Input: Level 2, XP 250 -> 250 ~/ 100 = 2 extra levels -> New Level 4, XP 50.
  static SkillXpResult normalizeDirectInput({
    required int levelInput,
    required int xpInput,
    int? previousLevel,
  }) {
    final baseLevel = levelInput >= 1 ? levelInput : 1;
    final rawXp = xpInput >= 0 ? xpInput : 0;

    final extraLevels = rawXp ~/ 100;
    final finalLevel = baseLevel + extraLevels;
    final finalXp = rawXp % 100;

    final prev = previousLevel ?? baseLevel;
    final didLevelUp = finalLevel > prev;

    return SkillXpResult(
      newLevel: finalLevel,
      newXp: finalXp,
      levelGain: (finalLevel - prev).clamp(0, 999),
      didLevelUp: didLevelUp,
    );
  }

  /// Updates the 7-day rolling history snapshot array with today's level.
  ///
  /// The 7th element (index 6) represents today's snapshot.
  static List<int> updateHistoryToday(List<int> history, int newLevel) {
    List<int> updated;
    if (history.length != 7) {
      updated = List<int>.filled(7, newLevel);
    } else {
      updated = List<int>.from(history);
    }
    updated[6] = newLevel;
    return updated;
  }
}
