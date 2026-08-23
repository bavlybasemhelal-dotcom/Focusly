import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a Group Challenge.
class ChallengeModel {
  final String id;
  final String title;
  final String type; // 'tasks' | 'habits' | 'xp'
  final int goal;
  final int durationDays; // 3, 7, 14, 30
  final DateTime startDate;
  final DateTime endDate;
  final String status; // 'active' | 'finished'
  final String createdBy;
  final String createdByName;
  final String? winnerUid;
  final String? winnerName;
  final int? winnerScore;
  final int participantCount;

  const ChallengeModel({
    required this.id,
    required this.title,
    required this.type,
    required this.goal,
    required this.durationDays,
    required this.startDate,
    required this.endDate,
    this.status = 'active',
    required this.createdBy,
    required this.createdByName,
    this.winnerUid,
    this.winnerName,
    this.winnerScore,
    this.participantCount = 1,
  });

  bool get isActive => status == 'active';
  bool get isFinished => status == 'finished';

  int get daysRemaining {
    final now = DateTime.now();
    if (now.isAfter(endDate)) return 0;
    return endDate.difference(now).inDays + 1;
  }

  String get typeEmoji {
    switch (type) {
      case 'tasks':
        return '🎯';
      case 'habits':
        return '🔥';
      case 'xp':
        return '⚡';
      default:
        return '🏆';
    }
  }

  String get typeTitleKey {
    switch (type) {
      case 'tasks':
        return 'challenge_type_tasks';
      case 'habits':
        return 'challenge_type_habits';
      case 'xp':
        return 'challenge_type_xp';
      default:
        return 'challenge_type_tasks';
    }
  }

  ChallengeModel copyWith({
    String? id,
    String? title,
    String? type,
    int? goal,
    int? durationDays,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? createdBy,
    String? createdByName,
    String? winnerUid,
    String? winnerName,
    int? winnerScore,
    int? participantCount,
  }) {
    return ChallengeModel(
      id: id ?? this.id,
      title: title ?? this.title,
      type: type ?? this.type,
      goal: goal ?? this.goal,
      durationDays: durationDays ?? this.durationDays,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      winnerUid: winnerUid ?? this.winnerUid,
      winnerName: winnerName ?? this.winnerName,
      winnerScore: winnerScore ?? this.winnerScore,
      participantCount: participantCount ?? this.participantCount,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'type': type,
      'goal': goal,
      'durationDays': durationDays,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'status': status,
      'createdBy': createdBy,
      'createdByName': createdByName,
      if (winnerUid != null) 'winnerUid': winnerUid,
      if (winnerName != null) 'winnerName': winnerName,
      if (winnerScore != null) 'winnerScore': winnerScore,
      'participantCount': participantCount,
    };
  }

  factory ChallengeModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return ChallengeModel(
      id: docId,
      title: map['title'] ?? '',
      type: map['type'] ?? 'tasks',
      goal: (map['goal'] as num?)?.toInt() ?? 10,
      durationDays: (map['durationDays'] as num?)?.toInt() ?? 7,
      startDate: parseDate(map['startDate']),
      endDate: parseDate(map['endDate']),
      status: map['status'] ?? 'active',
      createdBy: map['createdBy'] ?? '',
      createdByName: map['createdByName'] ?? 'Member',
      winnerUid: map['winnerUid'],
      winnerName: map['winnerName'],
      winnerScore: (map['winnerScore'] as num?)?.toInt(),
      participantCount: (map['participantCount'] as num?)?.toInt() ?? 1,
    );
  }
}
