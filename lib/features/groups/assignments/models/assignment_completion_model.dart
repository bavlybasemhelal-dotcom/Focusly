import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model representing an individual member's progress / completion
/// state on a group assignment.
///
/// Stored in Firestore under: `groups/{groupId}/assignments/{assignmentId}/completions/{uid}`
class AssignmentCompletionModel {
  final String decision;
  final String delayReason;
  final String uid;
  final String? memberName;
  final String status; // 'pending' | 'done'
  final int currentCount; // Relevant when completionMode='count'
  final DateTime? completedAt; // Timestamp when marked done / target reached

  const AssignmentCompletionModel({
    required this.uid,
    this.decision = 'offered',
    this.delayReason = '',
    this.memberName,
    this.status = 'pending',
    this.currentCount = 0,
    this.completedAt,
  });

  /// True if member has finished this assignment
  bool get isDone => status == 'done';

  /// True if assignment is still pending completion
  bool get isPending => status == 'pending';

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'decision': decision,
      'delayReason': delayReason,
      if (memberName != null) 'memberName': memberName,
      'status': status,
      'currentCount': currentCount,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
    };
  }

  factory AssignmentCompletionModel.fromMap(
    Map<String, dynamic> map,
    String docId,
  ) {
    DateTime? parsedCompletedAt;
    if (map['completedAt'] is Timestamp) {
      parsedCompletedAt = (map['completedAt'] as Timestamp).toDate();
    } else if (map['completedAt'] is String) {
      parsedCompletedAt = DateTime.tryParse(map['completedAt']);
    }

    return AssignmentCompletionModel(
      uid: docId.isNotEmpty ? docId : (map['uid'] ?? ''),
      decision: map['decision'] as String? ?? 'offered',
      delayReason: map['delayReason'] as String? ?? '',
      memberName: map['memberName'] as String?,
      status: map['status'] as String? ?? 'pending',
      currentCount: (map['currentCount'] as num?)?.toInt() ?? 0,
      completedAt: parsedCompletedAt,
    );
  }

  factory AssignmentCompletionModel.fromFirestore(DocumentSnapshot doc) {
    return AssignmentCompletionModel.fromMap(
      doc.data() as Map<String, dynamic>? ?? {},
      doc.id,
    );
  }

  AssignmentCompletionModel copyWith({
    String? uid,
    String? memberName,
    String? status,
    int? currentCount,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return AssignmentCompletionModel(
      uid: uid ?? this.uid,
      memberName: memberName ?? this.memberName,
      decision: decision,
      delayReason: delayReason,
      status: status ?? this.status,
      currentCount: currentCount ?? this.currentCount,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }
}
