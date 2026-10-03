import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a user participant inside a Challenge.
class ChallengeParticipantModel {
  final String uid;
  final String name;
  final DateTime joinedAt;
  final int score; // Current progress achieved during challenge
  final int baseline; // Stat value at time of joining

  const ChallengeParticipantModel({
    required this.uid,
    required this.name,
    required this.joinedAt,
    this.score = 0,
    this.baseline = 0,
  });

  ChallengeParticipantModel copyWith({
    String? uid,
    String? name,
    DateTime? joinedAt,
    int? score,
    int? baseline,
  }) {
    return ChallengeParticipantModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      joinedAt: joinedAt ?? this.joinedAt,
      score: score ?? this.score,
      baseline: baseline ?? this.baseline,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'joinedAt': Timestamp.fromDate(joinedAt),
      'score': score,
      'baseline': baseline,
    };
  }

  factory ChallengeParticipantModel.fromMap(
    Map<String, dynamic> map,
    String docId,
  ) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return ChallengeParticipantModel(
      uid: docId.isNotEmpty ? docId : (map['uid'] ?? ''),
      name: map['name'] ?? 'User',
      joinedAt: parseDate(map['joinedAt']),
      score: (map['score'] as num?)?.toInt() ?? 0,
      baseline: (map['baseline'] as num?)?.toInt() ?? 0,
    );
  }
}
