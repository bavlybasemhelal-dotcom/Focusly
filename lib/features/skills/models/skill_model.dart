import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Data model representing a Skill on the Skills Board.
///
/// Firestore path: `users/{userId}/skills/{skillId}` (isolated per-user).
///
/// Features:
/// - `level`: Current proficiency level (starts at 1).
/// - `xp`: Progress (0..99) towards the next level (100 XP per level).
/// - `history`: 7-element rolling snapshot of daily levels for the 7-day sparkline.
class SkillModel {
  final String id;
  final String name;
  final String
  category; // Matches TaskCategory ID (e.g. 'work', 'study', 'health', etc.)
  final int level;
  final int xp; // 0..99
  final int color; // Hex color integer (e.g. 0xFF2E6FF2)
  final List<int> history; // 7 integers representing level history
  final DateTime createdAt;
  final DateTime updatedAt;

  const SkillModel({
    required this.id,
    required this.name,
    required this.category,
    this.level = 1,
    this.xp = 0,
    this.color = 0xFF2E6FF2,
    this.history = const [1, 1, 1, 1, 1, 1, 1],
    required this.createdAt,
    required this.updatedAt,
  });

  /// Progress percentage towards the next level (0..100).
  double get xpProgress => (xp.clamp(0, 100) / 100.0);

  /// Converts this [SkillModel] into a Firestore map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'level': level,
      'xp': xp,
      'color': color,
      'history': history,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Deserializes a Firestore snapshot map into a [SkillModel].
  factory SkillModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        return DateTime.tryParse(val) ?? fallback ?? DateTime.now();
      }
      return fallback ?? DateTime.now();
    }

    final now = DateTime.now();
    final parsedCreatedAt = parseDate(map['createdAt'], now);
    final parsedUpdatedAt = parseDate(map['updatedAt'], parsedCreatedAt);

    final rawLevel = (map['level'] as num?)?.toInt() ?? 1;
    final level = rawLevel >= 1 ? rawLevel : 1;

    final rawXp = (map['xp'] as num?)?.toInt() ?? 0;
    final xp = rawXp.clamp(0, 99);

    List<int> historyList = [];
    if (map['history'] is List) {
      historyList = (map['history'] as List)
          .map((e) => (e as num?)?.toInt() ?? level)
          .toList();
    }
    if (historyList.length < 7) {
      historyList = List<int>.filled(7, level);
    } else if (historyList.length > 7) {
      historyList = historyList.sublist(historyList.length - 7);
    }

    return SkillModel(
      id: docId,
      name: (map['name'] as String?)?.trim() ?? '',
      category: (map['category'] as String?)?.trim() ?? 'work',
      level: level,
      xp: xp,
      color: (map['color'] as num?)?.toInt() ?? 0xFF2E6FF2,
      history: historyList,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  /// Creates a copy of this [SkillModel] with modified fields.
  SkillModel copyWith({
    String? id,
    String? name,
    String? category,
    int? level,
    int? xp,
    int? color,
    List<int>? history,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SkillModel(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      level: level ?? this.level,
      xp: xp ?? this.xp,
      color: color ?? this.color,
      history: history ?? this.history,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SkillModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          category == other.category &&
          level == other.level &&
          xp == other.xp &&
          color == other.color &&
          listEquals(history, other.history);

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      category.hashCode ^
      level.hashCode ^
      xp.hashCode ^
      color.hashCode ^
      history.fold(0, (prev, elem) => prev ^ elem.hashCode);
}
