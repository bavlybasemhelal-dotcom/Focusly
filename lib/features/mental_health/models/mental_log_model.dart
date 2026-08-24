import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a Daily Mental Wellbeing Log.
///
/// Firestore path: `users/{userId}/mentalLog/{dateKey}` (isolated per-user).
///
/// NOTE ON ANXIETY DIMENSION:
/// `anxiety` is stored raw (1 to 10, where 10 is high anxiety).
/// However, for the 5-axis Radar Chart and personalized tip scoring,
/// it is converted into `calmScore = 11 - anxiety` so that a higher value
/// on all 5 radar vertices consistently represents a more favorable/healthy state.
class MentalLogModel {
  final String id;
  final String weekOf; // Represents the entry's own calendar date (e.g. '2026-08-25')
  final int anxiety; // 1 to 10 (1 = calm/low anxiety, 10 = high anxiety)
  final int happiness; // 1 to 10
  final int socialEnergy; // 1 to 10
  final int selfSatisfaction; // 1 to 10
  final int balance; // 1 to 10 (Life Balance)
  final DateTime createdAt;
  final DateTime updatedAt;

  const MentalLogModel({
    required this.id,
    required this.weekOf,
    this.anxiety = 5,
    this.happiness = 5,
    this.socialEnergy = 5,
    this.selfSatisfaction = 5,
    this.balance = 5,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Inverted Calm score for radar chart and tip ranking (1 to 10, where 10 = perfectly calm).
  int get calmScore => (11 - anxiety).clamp(1, 10);

  /// Parsed DateTime from `weekOf` string.
  DateTime get date => DateTime.tryParse(weekOf) ?? createdAt;

  /// Converts this model to a Firestore-compatible map.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'weekOf': weekOf,
      'anxiety': anxiety,
      'happiness': happiness,
      'socialEnergy': socialEnergy,
      'selfSatisfaction': selfSatisfaction,
      'balance': balance,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Deserializes a Firestore snapshot map.
  factory MentalLogModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? fallback ?? DateTime.now();
      return fallback ?? DateTime.now();
    }

    final now = DateTime.now();
    final parsedCreatedAt = parseDate(map['createdAt'], now);
    final parsedUpdatedAt = parseDate(map['updatedAt'], parsedCreatedAt);

    final rawWeekOf = (map['weekOf'] as String?)?.trim() ?? docId;
    final anxiety = ((map['anxiety'] as num?)?.toInt() ?? 5).clamp(1, 10);
    final happiness = ((map['happiness'] as num?)?.toInt() ?? 5).clamp(1, 10);
    final socialEnergy = ((map['socialEnergy'] as num?)?.toInt() ?? 5).clamp(1, 10);
    final selfSatisfaction = ((map['selfSatisfaction'] as num?)?.toInt() ?? 5).clamp(1, 10);
    final balance = ((map['balance'] as num?)?.toInt() ?? 5).clamp(1, 10);

    return MentalLogModel(
      id: docId,
      weekOf: rawWeekOf,
      anxiety: anxiety,
      happiness: happiness,
      socialEnergy: socialEnergy,
      selfSatisfaction: selfSatisfaction,
      balance: balance,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  /// Creates a copy with optional updated fields.
  MentalLogModel copyWith({
    String? id,
    String? weekOf,
    int? anxiety,
    int? happiness,
    int? socialEnergy,
    int? selfSatisfaction,
    int? balance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MentalLogModel(
      id: id ?? this.id,
      weekOf: weekOf ?? this.weekOf,
      anxiety: anxiety ?? this.anxiety,
      happiness: happiness ?? this.happiness,
      socialEnergy: socialEnergy ?? this.socialEnergy,
      selfSatisfaction: selfSatisfaction ?? this.selfSatisfaction,
      balance: balance ?? this.balance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MentalLogModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          weekOf == other.weekOf &&
          anxiety == other.anxiety &&
          happiness == other.happiness &&
          socialEnergy == other.socialEnergy &&
          selfSatisfaction == other.selfSatisfaction &&
          balance == other.balance;

  @override
  int get hashCode =>
      id.hashCode ^
      weekOf.hashCode ^
      anxiety.hashCode ^
      happiness.hashCode ^
      socialEnergy.hashCode ^
      selfSatisfaction.hashCode ^
      balance.hashCode;
}
