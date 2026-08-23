import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing a member or pending applicant in a Group.
class GroupMemberModel {
  final String uid;
  final String name;
  final String role; // 'admin' | 'member'
  final String status; // 'pending' | 'approved'
  final DateTime requestedAt;
  final DateTime? joinedAt;
  final int weeklyXP;

  const GroupMemberModel({
    required this.uid,
    required this.name,
    this.role = 'member',
    this.status = 'approved',
    required this.requestedAt,
    this.joinedAt,
    this.weeklyXP = 0,
  });

  bool get isAdmin => role == 'admin';
  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';

  GroupMemberModel copyWith({
    String? uid,
    String? name,
    String? role,
    String? status,
    DateTime? requestedAt,
    DateTime? joinedAt,
    int? weeklyXP,
  }) {
    return GroupMemberModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      role: role ?? this.role,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      joinedAt: joinedAt ?? this.joinedAt,
      weeklyXP: weeklyXP ?? this.weeklyXP,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'role': role,
      'status': status,
      'requestedAt': Timestamp.fromDate(requestedAt),
      if (joinedAt != null) 'joinedAt': Timestamp.fromDate(joinedAt!),
      'weeklyXP': weeklyXP,
    };
  }

  factory GroupMemberModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return GroupMemberModel(
      uid: docId.isNotEmpty ? docId : (map['uid'] ?? ''),
      name: map['name'] ?? 'User',
      role: map['role'] ?? 'member',
      status: map['status'] ?? 'approved',
      requestedAt: parseDate(map['requestedAt']),
      joinedAt: map['joinedAt'] != null ? parseDate(map['joinedAt']) : null,
      weeklyXP: (map['weeklyXP'] as num?)?.toInt() ?? 0,
    );
  }
}
