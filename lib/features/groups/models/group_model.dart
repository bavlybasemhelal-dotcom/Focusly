import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a collaborative Focusly Group.
class GroupModel {
  final String id;
  final String name;
  final String icon; // Emoji icon, e.g. "🚀"
  final String description;
  final String inviteCode; // Format "GRP-XXXXXX"
  final String createdBy;
  final DateTime createdAt;
  final int memberCount;
  final int maxMembers; // Default 20
  final String status; // 'active'
  final DateTime? weekStart; // For tracking weekly XP reset

  // TODO: Premium system gating can be reintroduced here later (e.g. higher member cap or unlimited groups for Pro users).
  static const int defaultMaxMembers = 20;
  static const int maxGroupsPerUser = 5;

  const GroupModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.inviteCode,
    required this.createdBy,
    required this.createdAt,
    this.memberCount = 1,
    this.maxMembers = defaultMaxMembers,
    this.status = 'active',
    this.weekStart,
  });

  GroupModel copyWith({
    String? id,
    String? name,
    String? icon,
    String? description,
    String? inviteCode,
    String? createdBy,
    DateTime? createdAt,
    int? memberCount,
    int? maxMembers,
    String? status,
    DateTime? weekStart,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      description: description ?? this.description,
      inviteCode: inviteCode ?? this.inviteCode,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      memberCount: memberCount ?? this.memberCount,
      maxMembers: maxMembers ?? this.maxMembers,
      status: status ?? this.status,
      weekStart: weekStart ?? this.weekStart,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'icon': icon,
      'description': description,
      'inviteCode': inviteCode,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'memberCount': memberCount,
      'maxMembers': maxMembers,
      'status': status,
      if (weekStart != null) 'weekStart': Timestamp.fromDate(weekStart!),
    };
  }

  factory GroupModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return GroupModel(
      id: docId,
      name: map['name'] ?? '',
      icon: map['icon'] ?? '👥',
      description: map['description'] ?? '',
      inviteCode: map['inviteCode'] ?? '',
      createdBy: map['createdBy'] ?? '',
      createdAt: parseDate(map['createdAt']),
      memberCount: (map['memberCount'] as num?)?.toInt() ?? 1,
      maxMembers: (map['maxMembers'] as num?)?.toInt() ?? defaultMaxMembers,
      status: map['status'] ?? 'active',
      weekStart: map['weekStart'] != null ? parseDate(map['weekStart']) : null,
    );
  }
}
