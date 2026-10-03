import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single life-goal or dream in Focusly's Bucket List.
///
/// Features pending dreams to achieve and achieved dreams with a reflective memory note.
class BucketItemModel {
  final String id;
  final String title;
  final DateTime? targetDate;
  final String status; // 'pending' | 'completed'
  final String? memory; // Reflective note logged upon achievement
  final DateTime createdAt;
  final DateTime updatedAt;

  const BucketItemModel({
    required this.id,
    required this.title,
    this.targetDate,
    this.status = 'pending',
    this.memory,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isCompleted => status == 'completed';
  bool get isPending => status == 'pending';

  /// Formats the target date (e.g. "Aug 25, 2026")
  String? get formattedTargetDate {
    if (targetDate == null) return null;
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[targetDate!.month - 1]} ${targetDate!.day}, ${targetDate!.year}';
  }

  /// Converts model to Firestore-compatible Map
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'targetDate': targetDate != null ? Timestamp.fromDate(targetDate!) : null,
      'status': status,
      'memory': memory,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  /// Factory constructor from Firestore document snapshot
  factory BucketItemModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return BucketItemModel.fromMap(data, doc.id);
  }

  /// Factory constructor from Map and docId
  factory BucketItemModel.fromMap(Map<String, dynamic> map, String docId) {
    DateTime? parsedTargetDate;
    if (map['targetDate'] is Timestamp) {
      parsedTargetDate = (map['targetDate'] as Timestamp).toDate();
    } else if (map['targetDate'] is String) {
      parsedTargetDate = DateTime.tryParse(map['targetDate'] as String);
    }

    DateTime parsedCreatedAt = DateTime.now();
    if (map['createdAt'] is Timestamp) {
      parsedCreatedAt = (map['createdAt'] as Timestamp).toDate();
    } else if (map['createdAt'] is String) {
      parsedCreatedAt =
          DateTime.tryParse(map['createdAt'] as String) ?? DateTime.now();
    }

    DateTime parsedUpdatedAt = DateTime.now();
    if (map['updatedAt'] is Timestamp) {
      parsedUpdatedAt = (map['updatedAt'] as Timestamp).toDate();
    } else if (map['updatedAt'] is String) {
      parsedUpdatedAt =
          DateTime.tryParse(map['updatedAt'] as String) ?? DateTime.now();
    }

    return BucketItemModel(
      id: docId,
      title: map['title'] as String? ?? '',
      targetDate: parsedTargetDate,
      status: map['status'] as String? ?? 'pending',
      memory: map['memory'] as String?,
      createdAt: parsedCreatedAt,
      updatedAt: parsedUpdatedAt,
    );
  }

  /// Creates a copy of this model with optional updated values
  BucketItemModel copyWith({
    String? id,
    String? title,
    DateTime? targetDate,
    String? status,
    String? memory,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BucketItemModel(
      id: id ?? this.id,
      title: title ?? this.title,
      targetDate: targetDate ?? this.targetDate,
      status: status ?? this.status,
      memory: memory ?? this.memory,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
