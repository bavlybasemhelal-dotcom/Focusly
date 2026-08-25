import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Represents the 6 category scores (each 0.0 to 100.0) making up the Weekly Life Score.
class ScoreBreakdown {
  final double tasks; // Weight: 30%
  final double habits; // Weight: 25%
  final double energy; // Weight: 15%
  final double learning; // Weight: 10%
  final double checkins; // Weight: 10%
  final double goals; // Weight: 10%

  const ScoreBreakdown({
    this.tasks = 0.0,
    this.habits = 0.0,
    this.energy = 0.0,
    this.learning = 0.0,
    this.checkins = 0.0,
    this.goals = 0.0,
  });

  double get tasksContribution => ((tasks * 0.30) * 10).round() / 10.0;
  double get habitsContribution => ((habits * 0.25) * 10).round() / 10.0;
  double get energyContribution => ((energy * 0.15) * 10).round() / 10.0;
  double get learningContribution => ((learning * 0.10) * 10).round() / 10.0;
  double get checkinsContribution => ((checkins * 0.10) * 10).round() / 10.0;
  double get goalsContribution => ((goals * 0.10) * 10).round() / 10.0;

  Map<String, dynamic> toMap() {
    return {
      'tasks': tasks,
      'habits': habits,
      'energy': energy,
      'learning': learning,
      'checkins': checkins,
      'goals': goals,
    };
  }

  factory ScoreBreakdown.fromMap(Map<String, dynamic> map) {
    return ScoreBreakdown(
      tasks: (map['tasks'] as num?)?.toDouble() ?? 0.0,
      habits: (map['habits'] as num?)?.toDouble() ?? 0.0,
      energy: (map['energy'] as num?)?.toDouble() ?? 0.0,
      learning: (map['learning'] as num?)?.toDouble() ?? 0.0,
      checkins: (map['checkins'] as num?)?.toDouble() ?? 0.0,
      goals: (map['goals'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Persistent weekly life score record stored in Firestore under
/// `users/{uid}/lifeScoreLog/{weekOf}`.
class LifeScoreModel {
  final String id; // Doc ID matching weekOf
  final String weekOf; // e.g. "2026-08-23"
  final int total; // 0 to 100
  final ScoreBreakdown breakdown;
  final DateTime computedAt;

  const LifeScoreModel({
    required this.id,
    required this.weekOf,
    required this.total,
    required this.breakdown,
    required this.computedAt,
  });

  /// Qualitative localized translation key based on score range
  String get qualitativeKey {
    if (total >= 80) return 'life_score_excellent';
    if (total >= 60) return 'life_score_good';
    if (total >= 40) return 'life_score_average';
    return 'life_score_needs_improvement';
  }

  /// Accent color matching score tier
  Color get tierColor {
    if (total >= 80) return const Color(0xFF10B981); // Emerald
    if (total >= 60) return const Color(0xFF3B82F6); // Indigo / Blue
    if (total >= 40) return const Color(0xFFF59E0B); // Amber
    return const Color(0xFFEF4444); // Red
  }

  Map<String, dynamic> toMap() {
    return {
      'weekOf': weekOf,
      'total': total,
      'breakdown': breakdown.toMap(),
      'computedAt': Timestamp.fromDate(computedAt),
    };
  }

  factory LifeScoreModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedComputedAt;
    if (map['computedAt'] is Timestamp) {
      parsedComputedAt = (map['computedAt'] as Timestamp).toDate();
    } else if (map['computedAt'] is String) {
      parsedComputedAt = DateTime.tryParse(map['computedAt']) ?? DateTime.now();
    } else {
      parsedComputedAt = DateTime.now();
    }

    final breakdownMap = map['breakdown'] is Map<String, dynamic>
        ? map['breakdown'] as Map<String, dynamic>
        : <String, dynamic>{};

    return LifeScoreModel(
      id: docId,
      weekOf: map['weekOf'] ?? docId,
      total: (map['total'] as num?)?.toInt() ?? 0,
      breakdown: ScoreBreakdown.fromMap(breakdownMap),
      computedAt: parsedComputedAt,
    );
  }
}
