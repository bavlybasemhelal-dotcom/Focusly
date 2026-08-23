import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Pure calculation function computing sleep duration in hours with overnight wrap support.
///
/// Example:
/// - Sleep 23:00, Wake 07:00 -> 8.0 hours
/// - Sleep 01:30, Wake 08:00 -> 6.5 hours
/// - Sleep 14:00, Wake 16:30 -> 2.5 hours
double computeSleepDurationFromTime(TimeOfDay sleep, TimeOfDay wake) {
  int sleepMinutes = sleep.hour * 60 + sleep.minute;
  int wakeMinutes = wake.hour * 60 + wake.minute;

  int diffMinutes = wakeMinutes - sleepMinutes;
  if (diffMinutes < 0) {
    diffMinutes += 24 * 60; // Overnight wrap
  }

  return (diffMinutes / 60.0 * 10).round() / 10.0;
}

/// Helper parsing "HH:mm" strings to TimeOfDay
TimeOfDay? parseTimeString(String? timeStr) {
  if (timeStr == null || !timeStr.contains(':')) return null;
  final parts = timeStr.split(':');
  if (parts.length != 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

/// Helper formatting TimeOfDay to "HH:mm"
String formatTimeOfDay(TimeOfDay time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Data model representing a Daily Energy, Mood, Water, and Sleep check-in.
///
/// Stored in Firestore under: `users/{userId}/checkins/{dateString}`
/// where `dateString` is format "YYYY-MM-DD".
class CheckinModel {
  final String date; // Doc ID, format "YYYY-MM-DD"
  final int energy; // 1 to 5
  final String mood; // Emoji e.g. 😞 😐 🙂 😊 🤩
  final String? note;
  final int water; // Number of glasses logged
  final double sleep; // Computed hours slept
  final String? sleepTime; // "HH:mm"
  final String? wakeTime; // "HH:mm"
  final bool sleepXpAwarded; // Guard flag preventing repeat XP farming
  final int waterXpGlassesAwarded; // Count of water glasses for which XP was awarded
  final DateTime createdAt;
  final DateTime updatedAt;

  const CheckinModel({
    required this.date,
    required this.energy,
    required this.mood,
    this.note,
    this.water = 0,
    this.sleep = 0.0,
    this.sleepTime,
    this.wakeTime,
    this.sleepXpAwarded = false,
    this.waterXpGlassesAwarded = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Translation key for energy level (1-5)
  String get energyLabelKey {
    switch (energy) {
      case 1:
        return 'energy_level_1'; // Low
      case 2:
        return 'energy_level_2'; // Fair
      case 3:
        return 'energy_level_3'; // Moderate
      case 4:
        return 'energy_level_4'; // High
      case 5:
        return 'energy_level_5'; // Excellent
      default:
        return 'energy_level_3';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'energy': energy,
      'mood': mood,
      'note': note,
      'water': water,
      'sleep': sleep,
      'sleepTime': sleepTime,
      'wakeTime': wakeTime,
      'sleepXpAwarded': sleepXpAwarded,
      'waterXpGlassesAwarded': waterXpGlassesAwarded,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory CheckinModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parsedCreatedAt;
    if (map['createdAt'] is Timestamp) {
      parsedCreatedAt = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      parsedCreatedAt = DateTime.tryParse(map['createdAt']) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    DateTime parsedUpdatedAt;
    if (map['updatedAt'] is Timestamp) {
      parsedUpdatedAt = (map['updatedAt'] as Timestamp).toDate();
    } else if (map['updatedAt'] is String) {
      parsedUpdatedAt = DateTime.tryParse(map['updatedAt']) ?? DateTime.now();
    } else {
      parsedUpdatedAt = DateTime.now();
    }

    return CheckinModel(
      date: docId,
      energy: (map['energy'] as num?)?.toInt() ?? 3,
      mood: map['mood'] ?? '🙂',
      note: map['note'],
      water: (map['water'] as num?)?.toInt() ?? 0,
      sleep: (map['sleep'] as num?)?.toDouble() ?? 0.0,
      sleepTime: map['sleepTime'],
      wakeTime: map['wakeTime'],
      sleepXpAwarded: map['sleepXpAwarded'] ?? false,
      waterXpGlassesAwarded: (map['waterXpGlassesAwarded'] as num?)?.toInt() ?? 0,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  CheckinModel copyWith({
    String? date,
    int? energy,
    String? mood,
    String? note,
    int? water,
    double? sleep,
    String? sleepTime,
    String? wakeTime,
    bool? sleepXpAwarded,
    int? waterXpGlassesAwarded,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearNote = false,
    bool clearSleepTime = false,
    bool clearWakeTime = false,
  }) {
    return CheckinModel(
      date: date ?? this.date,
      energy: energy ?? this.energy,
      mood: mood ?? this.mood,
      note: clearNote ? null : (note ?? this.note),
      water: water ?? this.water,
      sleep: sleep ?? this.sleep,
      sleepTime: clearSleepTime ? null : (sleepTime ?? this.sleepTime),
      wakeTime: clearWakeTime ? null : (wakeTime ?? this.wakeTime),
      sleepXpAwarded: sleepXpAwarded ?? this.sleepXpAwarded,
      waterXpGlassesAwarded:
          waterXpGlassesAwarded ?? this.waterXpGlassesAwarded,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CheckinModel &&
          runtimeType == other.runtimeType &&
          date == other.date &&
          energy == other.energy &&
          mood == other.mood &&
          water == other.water &&
          sleep == other.sleep;

  @override
  int get hashCode =>
      date.hashCode ^
      energy.hashCode ^
      mood.hashCode ^
      water.hashCode ^
      sleep.hashCode;
}
