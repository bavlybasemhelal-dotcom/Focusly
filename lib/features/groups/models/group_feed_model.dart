import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing an activity feed item inside a Group.
class GroupFeedModel {
  final String id;
  final String uid;
  final String name;
  final String type; // 'task_milestone', 'streak_milestone', 'level_up', 'challenge_created', 'challenge_won', 'custom_message'
  final String message;
  final String icon; // Emoji, e.g. "🎯", "🔥", "🏆", "🌟"
  final Map<String, int> reactions; // {'like': 0, 'fire': 0, 'clap': 0}
  final Map<String, String> reactedBy; // {uid: 'like' | 'fire' | 'clap'}
  final DateTime createdAt;

  const GroupFeedModel({
    required this.id,
    required this.uid,
    required this.name,
    required this.type,
    required this.message,
    required this.icon,
    this.reactions = const {'like': 0, 'fire': 0, 'clap': 0},
    this.reactedBy = const {},
    required this.createdAt,
  });

  int get likeCount => reactions['like'] ?? 0;
  int get fireCount => reactions['fire'] ?? 0;
  int get clapCount => reactions['clap'] ?? 0;

  String? getUserReaction(String currentUid) => reactedBy[currentUid];

  GroupFeedModel copyWith({
    String? id,
    String? uid,
    String? name,
    String? type,
    String? message,
    String? icon,
    Map<String, int>? reactions,
    Map<String, String>? reactedBy,
    DateTime? createdAt,
  }) {
    return GroupFeedModel(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      name: name ?? this.name,
      type: type ?? this.type,
      message: message ?? this.message,
      icon: icon ?? this.icon,
      reactions: reactions ?? this.reactions,
      reactedBy: reactedBy ?? this.reactedBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'type': type,
      'message': message,
      'icon': icon,
      'reactions': reactions,
      'reactedBy': reactedBy,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory GroupFeedModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    final rawReactions = map['reactions'];
    final reactionsMap = <String, int>{'like': 0, 'fire': 0, 'clap': 0};
    if (rawReactions is Map) {
      rawReactions.forEach((key, value) {
        if (value is num) {
          reactionsMap[key.toString()] = value.toInt();
        }
      });
    }

    final rawReactedBy = map['reactedBy'];
    final reactedByMap = <String, String>{};
    if (rawReactedBy is Map) {
      rawReactedBy.forEach((key, value) {
        if (value != null) {
          reactedByMap[key.toString()] = value.toString();
        }
      });
    }

    return GroupFeedModel(
      id: docId,
      uid: map['uid'] ?? '',
      name: map['name'] ?? 'Member',
      type: map['type'] ?? 'custom_message',
      message: map['message'] ?? '',
      icon: map['icon'] ?? '💬',
      reactions: reactionsMap,
      reactedBy: reactedByMap,
      createdAt: parseDate(map['createdAt']),
    );
  }
}
