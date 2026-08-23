import 'package:flutter/material.dart';

/// The 5 core Time Block types supported in Focusly.
///
/// Each type represents a distinct focus classification with an associated
/// theme color, emoji, icon, and translation localization key.
///
/// ARCHITECTURE NOTE: Time Blocker events ARE standard Schedule events in
/// `users/{uid}/events/{eventId}` where `blockType` is set to one of these IDs.
enum TimeBlockType {
  deep(
    id: 'deep',
    labelKey: 'block_type_deep',
    emoji: '🧠',
    colorValue: 0xFF6366F1, // Electric Indigo / Deep Purple
    icon: Icons.psychology_rounded,
  ),
  shallow(
    id: 'shallow',
    labelKey: 'block_type_shallow',
    emoji: '📥',
    colorValue: 0xFF2563EB, // Royal Blue
    icon: Icons.inbox_rounded,
  ),
  health(
    id: 'health',
    labelKey: 'block_type_health',
    emoji: '💪',
    colorValue: 0xFF10B981, // Emerald Green
    icon: Icons.fitness_center_rounded,
  ),
  leisure(
    id: 'leisure',
    labelKey: 'block_type_leisure',
    emoji: '🎮',
    colorValue: 0xFFF59E0B, // Amber Gold
    icon: Icons.sports_esports_rounded,
  ),
  admin(
    id: 'admin',
    labelKey: 'block_type_admin',
    emoji: '⚙️',
    colorValue: 0xFF64748B, // Slate Grey
    icon: Icons.settings_rounded,
  );

  final String id;
  final String labelKey;
  final String emoji;
  final int colorValue;
  final IconData icon;

  const TimeBlockType({
    required this.id,
    required this.labelKey,
    required this.emoji,
    required this.colorValue,
    required this.icon,
  });

  /// The Flutter [Color] associated with this time block type
  Color get color => Color(colorValue);

  /// Helper factory to parse a string ID safely
  static TimeBlockType? fromString(String? val) {
    if (val == null || val.trim().isEmpty) return null;
    final normalized = val.trim().toLowerCase();
    for (final type in TimeBlockType.values) {
      if (type.id == normalized) return type;
    }
    return null;
  }
}
