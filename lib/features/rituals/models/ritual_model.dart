import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing the completed shutdown ritual at the end of the day.
class ShutdownData {
  final bool completed;
  final String gratitudeText;
  final List<String> tomorrowTasks;
  final String?
  lesson; // TODO: Future "Lessons Learned" log/history view will build on this.
  final DateTime? completedAt;

  const ShutdownData({
    this.completed = true,
    this.gratitudeText = '',
    this.tomorrowTasks = const [],
    this.lesson,
    this.completedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'completed': completed,
      'gratitudeText': gratitudeText,
      'tomorrowTasks': tomorrowTasks,
      'lesson': lesson,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
    };
  }

  factory ShutdownData.fromMap(Map<String, dynamic> map) {
    DateTime? parsedCompletedAt;
    if (map['completedAt'] is Timestamp) {
      parsedCompletedAt = (map['completedAt'] as Timestamp).toDate();
    } else if (map['completedAt'] is String) {
      parsedCompletedAt = DateTime.tryParse(map['completedAt']);
    }

    final rawTasks = map['tomorrowTasks'];
    List<String> parsedTasks = [];
    if (rawTasks is List) {
      parsedTasks = rawTasks.map((e) => e.toString()).toList();
    }

    return ShutdownData(
      completed: map['completed'] ?? true,
      gratitudeText: map['gratitudeText'] ?? '',
      tomorrowTasks: parsedTasks,
      lesson: map['lesson'] as String?,
      completedAt: parsedCompletedAt,
    );
  }

  ShutdownData copyWith({
    bool? completed,
    String? gratitudeText,
    List<String>? tomorrowTasks,
    String? lesson,
    DateTime? completedAt,
  }) {
    return ShutdownData(
      completed: completed ?? this.completed,
      gratitudeText: gratitudeText ?? this.gratitudeText,
      tomorrowTasks: tomorrowTasks ?? this.tomorrowTasks,
      lesson: lesson ?? this.lesson,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

/// Data model representing a Daily Ritual document.
///
/// Stored in Firestore under: `users/{userId}/rituals/{dateStr}`
class RitualModel {
  final String date; // Doc ID, format: YYYY-MM-DD
  final String? intention; // Morning intention focus text
  final ShutdownData? shutdown; // End of day review data
  final DateTime createdAt;
  final DateTime updatedAt;

  const RitualModel({
    required this.date,
    this.intention,
    this.shutdown,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasIntention => intention != null && intention!.trim().isNotEmpty;
  bool get isShutdownCompleted => shutdown?.completed == true;

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'intention': intention,
      'shutdown': shutdown?.toMap(),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory RitualModel.fromMap(Map<String, dynamic> map, String docId) {
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

    ShutdownData? parsedShutdown;
    if (map['shutdown'] is Map<String, dynamic>) {
      parsedShutdown = ShutdownData.fromMap(
        map['shutdown'] as Map<String, dynamic>,
      );
    }

    return RitualModel(
      date: docId,
      intention: map['intention'] as String?,
      shutdown: parsedShutdown,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  RitualModel copyWith({
    String? date,
    String? intention,
    bool clearIntention = false,
    ShutdownData? shutdown,
    bool clearShutdown = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RitualModel(
      date: date ?? this.date,
      intention: clearIntention ? null : (intention ?? this.intention),
      shutdown: clearShutdown ? null : (shutdown ?? this.shutdown),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
