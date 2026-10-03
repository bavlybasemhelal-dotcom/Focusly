import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a workout session.
///
/// Firestore path: `users/{userId}/workouts/{workoutId}` (isolated per-user).
class WorkoutModel {
  final String id;
  final String type; // 'gym' | 'running' | 'swim' | 'yoga' | 'other'
  final int durationMin; // Duration in minutes (> 0)
  final int calories; // Estimated calories burned (default 0)
  final DateTime date; // Date of workout
  final String? note; // Optional short notes
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkoutModel({
    required this.id,
    required this.type,
    required this.durationMin,
    this.calories = 0,
    required this.date,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'durationMin': durationMin,
      'calories': calories,
      'date': Timestamp.fromDate(date),
      'note': note,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory WorkoutModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        return DateTime.tryParse(val) ?? fallback ?? DateTime.now();
      }
      return fallback ?? DateTime.now();
    }

    final now = DateTime.now();
    final parsedDate = parseDate(map['date'], now);
    final parsedCreatedAt = parseDate(map['createdAt'], now);
    final parsedUpdatedAt = parseDate(map['updatedAt'], parsedCreatedAt);

    final rawType = (map['type'] as String?)?.toLowerCase().trim() ?? 'gym';
    final type = ['gym', 'running', 'swim', 'yoga', 'other'].contains(rawType)
        ? rawType
        : 'gym';

    final durationMin = (map['durationMin'] as num?)?.toInt() ?? 30;
    final calories = (map['calories'] as num?)?.toInt() ?? 0;

    return WorkoutModel(
      id: docId,
      type: type,
      durationMin: durationMin > 0 ? durationMin : 1,
      calories: calories >= 0 ? calories : 0,
      date: parsedDate,
      note: (map['note'] as String?)?.trim(),
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  WorkoutModel copyWith({
    String? id,
    String? type,
    int? durationMin,
    int? calories,
    DateTime? date,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearNote = false,
  }) {
    return WorkoutModel(
      id: id ?? this.id,
      type: type ?? this.type,
      durationMin: durationMin ?? this.durationMin,
      calories: calories ?? this.calories,
      date: date ?? this.date,
      note: clearNote ? null : (note ?? this.note),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkoutModel &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          durationMin == other.durationMin &&
          calories == other.calories &&
          date == other.date &&
          note == other.note;

  @override
  int get hashCode =>
      id.hashCode ^
      type.hashCode ^
      durationMin.hashCode ^
      calories.hashCode ^
      date.hashCode ^
      (note?.hashCode ?? 0);
}
